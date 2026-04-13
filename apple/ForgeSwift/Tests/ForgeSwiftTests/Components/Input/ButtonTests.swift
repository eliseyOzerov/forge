#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class ButtonTests: XCTestCase {

    // MARK: - Helpers

    /// Create a ButtonModel wired to a Button view via the framework lifecycle.
    private func makeModel(
        states: UIState = .idle,
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
        let model = ButtonModel()
        model.handleDidInit(button)
        return model
    }

    // MARK: - ButtonModel: currentState

    func testCurrentStateDefaultIsIdle() {
        let model = makeModel()
        XCTAssertTrue(model.currentState.contains(.idle))
        XCTAssertFalse(model.currentState.contains(.pressed))
    }

    func testCurrentStateAfterPress() {
        let model = makeModel()
        model.handlePress()
        XCTAssertTrue(model.currentState.contains(.pressed))
        XCTAssertFalse(model.currentState.contains(.idle))
    }

    func testCurrentStateAfterRelease() {
        let model = makeModel()
        model.handlePress()
        model.handleRelease(inside: false)
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
        model.handlePress()
        let state = model.currentState
        XCTAssertTrue(state.contains(.pressed))
        XCTAssertTrue(state.contains(.focused))
    }

    // MARK: - ButtonModel: interaction blocking

    func testPressWhenDisabled() {
        let model = makeModel(states: .disabled)
        model.handlePress()
        XCTAssertFalse(model.isPressed)
    }

    func testPressWhenLoading() {
        let model = makeModel(states: .loading)
        model.handlePress()
        XCTAssertFalse(model.isPressed)
    }

    // MARK: - ButtonModel: onTap

    func testReleaseInsideFiresOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handlePress()
        model.handleRelease(inside: true)
        XCTAssertTrue(tapped)
    }

    func testReleaseOutsideDoesNotFireOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handlePress()
        model.handleRelease(inside: false)
        XCTAssertFalse(tapped)
    }

    func testReleaseWithoutPressDoesNotFireOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        model.handleRelease(inside: true)
        XCTAssertFalse(tapped)
    }

    // MARK: - Debounce

    func testNoDebounceAllTapsFire() {
        var count = 0
        let model = makeModel { count += 1 }
        for _ in 0..<5 {
            model.handlePress()
            model.handleRelease(inside: true)
        }
        XCTAssertEqual(count, 5)
    }

    func testDebounceSupressesRapidTaps() {
        var count = 0
        let model = makeModel(debounce: 1.0) { count += 1 }
        // First tap fires
        model.handlePress()
        model.handleRelease(inside: true)
        // Second tap within 1s window is suppressed
        model.handlePress()
        model.handleRelease(inside: true)
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
        XCTAssertEqual(style.animation?.duration, 0.15)
    }

    func testHapticStyleNone() {
        let style = ButtonStyle(haptic: .none)
        XCTAssertEqual(style.haptic, .none)
    }

    func testButtonAnimationNone() {
        XCTAssertEqual(ButtonAnimation.none.duration, 0)
    }

    func testButtonAnimationDefault() {
        let anim = ButtonAnimation.default
        XCTAssertEqual(anim.duration, 0.15)
        XCTAssertEqual(anim.curve, .easeInOut)
    }

    // MARK: - TappableBoxView

    func testTappableBoxViewIsBoxView() {
        let view = TappableBoxView()
        XCTAssertTrue(view is BoxView)
    }

    func testAccessibilityTraitsIncludeButton() {
        let model = makeModel()
        let view = TappableBoxView()
        view.buttonModel = model
        view.updateAccessibility()
        XCTAssertTrue(view.accessibilityTraits.contains(.button))
    }

    func testAccessibilityDisabledTrait() {
        let model = makeModel(states: .disabled)
        let view = TappableBoxView()
        view.buttonModel = model
        view.updateAccessibility()
        XCTAssertTrue(view.accessibilityTraits.contains(.notEnabled))
    }

    func testAccessibilityActivateFiresOnTap() {
        var tapped = false
        let model = makeModel { tapped = true }
        let view = TappableBoxView()
        view.buttonModel = model
        let result = view.accessibilityActivate()
        XCTAssertTrue(result)
        XCTAssertTrue(tapped)
    }

    // MARK: - Style reactivity

    func testStyleResolvesForDifferentStates() {
        let style = StateProperty<ButtonStyle> { state in
            if state.contains(.pressed) {
                return ButtonStyle(BoxStyle(.fixed(100, 50)))
            }
            return ButtonStyle(BoxStyle(.fixed(200, 50)))
        }
        let idle = style(.idle)
        let pressed = style(.pressed)
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
        XCTAssertEqual(style(.idle).haptic, .medium)
        XCTAssertEqual(style(.disabled).haptic, .none)
    }
}

#endif
