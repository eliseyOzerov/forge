#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class ButtonTests: XCTestCase {

    // MARK: - Helpers

    /// Create a ButtonModel wired to a Button view via the framework lifecycle.
    private func makeModel(
        states: State = .idle,
        debounce: Double? = nil,
        onTap: @escaping @MainActor () -> Void = {}
    ) -> ButtonModel {
        let button = Button(
            states: states,
            debounce: debounce,
            onTap: onTap
        ) {
            Text("Test")
        }
        let context = BuiltNode()
        let model = ButtonModel(context: context)
        model.didInit(view: button)
        return model
    }

    // MARK: - ButtonModel: currentState

    func testCurrentStateDefaultIsIdle() {
        let model = makeModel()
        XCTAssertTrue(model.currentState.contains(.idle))
        XCTAssertFalse(model.currentState.contains(.pressed))
    }

    func testCurrentStateAfterDown() {
        let model = makeModel()
        model.handleDown()
        XCTAssertTrue(model.currentState.contains(.pressed))
        XCTAssertFalse(model.currentState.contains(.idle))
    }

    func testCurrentStateAfterCancel() {
        let model = makeModel()
        model.handleDown()
        model.handleCancel()
        XCTAssertTrue(model.currentState.contains(.idle))
        XCTAssertFalse(model.currentState.contains(.pressed))
    }

    func testExternalDisabledFlowsThrough() {
        let model = makeModel(states: .disabled)
        XCTAssertTrue(model.currentState.contains(.disabled))
        XCTAssertFalse(model.currentState.contains(.idle))
    }

    func testExternalLoadingFlowsThrough() {
        let model = makeModel(states: .loading)
        XCTAssertTrue(model.currentState.contains(.loading))
    }

    func testCombinedExternalAndInternal() {
        let model = makeModel(states: .focused)
        model.handleDown()
        let state = model.currentState
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
    }

    // MARK: - ButtonModel: interaction blocking

    func testDownWhenDisabled() {
        let model = makeModel(states: .disabled)
        model.handleDown()
        XCTAssertFalse(model.isPressed)
    }

    func testDownWhenLoading() {
        let model = makeModel(states: .loading)
        model.handleDown()
        XCTAssertFalse(model.isPressed)
    }

    // MARK: - ButtonModel: onTap

    func testTapFiresOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handleDown()
        model.handleTap()
        XCTAssertTrue(tapped)
    }

    func testCancelDoesNotFireOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handleDown()
        model.handleCancel()
        XCTAssertFalse(tapped)
    }

    func testTapWithoutDownDoesNotCrash() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handleTap()
        // handleTap fires onTap regardless of press state (it's the
        // gesture recognizer's responsibility to gate this).
        // Just verify no crash.
        _ = tapped
    }

    // MARK: - Debounce

    func testNoDebounceAllTapsFire() {
        var count = 0
        let model = makeModel { count += 1 }
        for _ in 0..<5 {
            model.handleDown()
            model.handleTap()
        }
        XCTAssertEqual(count, 5)
    }

    func testDebounceSuppressesRapidTaps() {
        var count = 0
        let model = makeModel(debounce: 1.0) { count += 1 }
        // First tap fires
        model.handleDown()
        model.handleTap()
        // Second tap within 1s window is suppressed
        model.handleDown()
        model.handleTap()
        XCTAssertEqual(count, 1)
    }

    // MARK: - Button struct

    func testTextShortcutSetsLabel() {
        let button = Button("Submit", onTap: {})
        XCTAssertEqual(button.label, "Submit")
    }

    func testDefaultStates() {
        let button = Button("Tap", onTap: {})
        XCTAssertEqual(button.states, .idle)
    }

    func testDefaultDebounce() {
        let button = Button("Tap", onTap: {})
        XCTAssertNil(button.debounce)
    }

    // MARK: - ButtonStyle

    func testButtonStyleDefaults() {
        let style = ButtonStyle()
        XCTAssertEqual(style.haptic, .light)
        XCTAssertNotNil(style.animation)
        XCTAssertEqual(style.animation?.duration, 0.2)
    }

    func testHapticStyleNone() {
        let style = ButtonStyle(haptic: .none)
        XCTAssertEqual(style.haptic, .none)
    }

    func testAnimationNone() {
        XCTAssertEqual(Animation.none.duration, 0)
    }

    func testAnimationDefault() {
        let anim = Animation.default
        XCTAssertEqual(anim.duration, 0.2)
    }

    // MARK: - Style reactivity

    func testStyleResolvesForDifferentStates() {
        let style = StateProperty<ButtonStyle> { state in
            if state.contains(.pressed) {
                return ButtonStyle(box: BoxStyle(frame: .fixed(100, 50)))
            }
            return ButtonStyle(box: BoxStyle(frame: .fixed(200, 50)))
        }
        let idle = style(State.idle)
        let pressed = style(State.pressed)
        if case .fix(let idleW) = idle.box.frame.width,
           case .fix(let pressedW) = pressed.box.frame.width {
            XCTAssertEqual(idleW, 200)
            XCTAssertEqual(pressedW, 100)
        } else {
            XCTFail("Expected fixed widths")
        }
    }

    func testStyleResolvesForDisabled() {
        let style = StateProperty<ButtonStyle> { state in
            ButtonStyle(haptic: state.contains(.disabled) ? .none : .medium)
        }
        XCTAssertEqual(style(State.idle).haptic, .medium)
        XCTAssertEqual(style(State.disabled).haptic, .none)
    }
}

#endif
