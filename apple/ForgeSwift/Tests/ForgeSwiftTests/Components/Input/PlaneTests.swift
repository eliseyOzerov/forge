#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class PlaneTests: XCTestCase {

    // MARK: - Helpers

    private func makeModel(
        offset: Vec2 = .zero,
        active: DragTransform? = nil,
        target: DragTransform? = nil,
        anchor: Bool = true,
        relative: Bool = false,
        states: State = .idle
    ) -> PlaneModel {
        let binding = Binding(offset)
        let draggable = Plane(
            offset: binding,
            active: active,
            target: target,
            anchor: anchor,
            relative: relative,
            states: states
        ) { EmptyView() }
        let context = BuiltNode()
        let model = PlaneModel(context: context)
        model.didInit(view: draggable)
        model.containerSize = Size(200, 200)
        return model
    }

    // MARK: - State

    func testDefaultNotPressed() {
        let model = makeModel()
        XCTAssertFalse(model.isPressed)
        XCTAssertTrue(model.currentState.contains(.idle))
    }

    func testDragStartSetsPressed() {
        let model = makeModel()
        model.handleDragStart(at: Vec2(50, 50))
        XCTAssertTrue(model.isPressed)
        XCTAssertTrue(model.currentState.contains(.pressed))
    }

    func testDragEndClearsPressed() {
        let model = makeModel()
        model.handleDragStart(at: Vec2(50, 50))
        model.handleDragEnd()
        XCTAssertFalse(model.isPressed)
    }

    func testDragCancelClearsPressed() {
        let model = makeModel()
        model.handleDragStart(at: Vec2(50, 50))
        model.handleDragCancel()
        XCTAssertFalse(model.isPressed)
    }

    func testDisabledBlocksDrag() {
        let model = makeModel(states: .disabled)
        model.handleDragStart(at: Vec2(50, 50))
        XCTAssertFalse(model.isPressed)
    }

    // MARK: - Offset Update

    func testDragUpdateChangesOffset() {
        let model = makeModel(offset: .zero, anchor: false)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragUpdate(at: Vec2(30, 40))
        XCTAssertEqual(model.view.offset.value.x, 30, accuracy: 0.1)
        XCTAssertEqual(model.view.offset.value.y, 40, accuracy: 0.1)
    }

    func testAnchorPreservesGap() {
        let model = makeModel(offset: Vec2(10, 10), anchor: true)
        // Drag starts at (50, 50) but offset is at (10, 10)
        // Anchor = (50, 50) - (10, 10) = (40, 40)
        model.handleDragStart(at: Vec2(50, 50))
        // Move to (60, 60) → raw = (60-40, 60-40) = (20, 20)
        model.handleDragUpdate(at: Vec2(60, 60))
        XCTAssertEqual(model.view.offset.value.x, 20, accuracy: 0.1)
        XCTAssertEqual(model.view.offset.value.y, 20, accuracy: 0.1)
    }

    func testNoAnchorJumps() {
        let model = makeModel(offset: Vec2(10, 10), anchor: false)
        model.handleDragStart(at: Vec2(50, 50))
        model.handleDragUpdate(at: Vec2(60, 60))
        // Without anchor, raw = position directly (minus zero anchor)
        XCTAssertEqual(model.view.offset.value.x, 60, accuracy: 0.1)
        XCTAssertEqual(model.view.offset.value.y, 60, accuracy: 0.1)
    }

    // MARK: - Active Transform

    func testActiveTransformApplied() {
        let model = makeModel(active: .horizontal, anchor: false)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragUpdate(at: Vec2(50, 30))
        XCTAssertEqual(model.view.offset.value.x, 50, accuracy: 0.1)
        XCTAssertEqual(model.view.offset.value.y, 0, accuracy: 0.1) // y zeroed
    }

    // MARK: - Target Transform

    func testTargetTriggersOnEnd() async {
        let snapPoints = [Vec2(0, 0), Vec2(100, 0)]
        let model = makeModel(target: .snap(to: snapPoints), anchor: false)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragUpdate(at: Vec2(80, 0))
        model.handleDragEnd()
        // Yield so the async Task inside handleDragEnd can start
        await Task.yield()
        // Should snap to nearest point (100, 0) via animation
        XCTAssertTrue(model.driver.isRunning)
    }

    // MARK: - Relative Mode

    func testRelativeConversion() {
        let model = makeModel(anchor: false, relative: true)
        model.containerSize = Size(200, 100)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragUpdate(at: Vec2(100, 50))
        // 100/200 = 0.5, 50/100 = 0.5
        XCTAssertEqual(model.view.offset.value.x, 0.5, accuracy: 0.01)
        XCTAssertEqual(model.view.offset.value.y, 0.5, accuracy: 0.01)
    }

    // MARK: - Callbacks

    func testOnStartFired() {
        var started = false
        let binding = Binding(Vec2.zero)
        let draggable = Plane(
            offset: binding,
            onStart: { _ in started = true }
        ) { EmptyView() }
        let context = BuiltNode()
        let model = PlaneModel(context: context)
        model.didInit(view: draggable)
        model.handleDragStart(at: Vec2(10, 10))
        XCTAssertTrue(started)
    }

    func testOnChangedFired() {
        var changed: Vec2?
        let binding = Binding(Vec2.zero)
        let draggable = Plane(
            offset: binding,
            anchor: false,
            onChanged: { changed = $0 }
        ) { EmptyView() }
        let context = BuiltNode()
        let model = PlaneModel(context: context)
        model.didInit(view: draggable)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragUpdate(at: Vec2(25, 35))
        XCTAssertEqual(changed!.x, 25, accuracy: 0.1)
        XCTAssertEqual(changed!.y, 35, accuracy: 0.1)
    }

    func testOnEndFired() {
        var ended = false
        let binding = Binding(Vec2.zero)
        let draggable = Plane(
            offset: binding,
            onEnd: { _ in ended = true }
        ) { EmptyView() }
        let context = BuiltNode()
        let model = PlaneModel(context: context)
        model.didInit(view: draggable)
        model.handleDragStart(at: Vec2(0, 0))
        model.handleDragEnd()
        XCTAssertTrue(ended)
    }
}

#endif
