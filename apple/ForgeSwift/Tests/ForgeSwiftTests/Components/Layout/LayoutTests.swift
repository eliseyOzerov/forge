#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

/// A mock LayoutChild with a fixed intrinsic size.
private final class MockChild: LayoutChild {
    let intrinsicSize: Size
    var rect: Rect = .zero
    var resize: (() -> Void)?

    init(_ width: Double, _ height: Double) {
        self.intrinsicSize = Size(width, height)
    }

    func measure(proposed: Size) -> Size { intrinsicSize }
}

/// A mock LayoutChild that returns the proposed size (fill behavior).
private final class FillChild: LayoutChild {
    var rect: Rect = .zero
    var resize: (() -> Void)?

    func measure(proposed: Size) -> Size { proposed }
}

@MainActor
final class LayoutTests: XCTestCase {

    private let acc = 0.5

    // MARK: - Helpers

    /// Run a layout pass and return the slots.
    private func run(
        _ layout: inout some Layout,
        bounds: Size,
        children: [any LayoutChild]
    ) -> [LayoutSlot] {
        layout.start(bounds)
        var laid: [LayoutSlot] = []
        for (i, child) in children.enumerated() {
            var slot = LayoutSlot(index: i, child: child)
            layout.propose(&slot, laid)
            slot.rect = Rect(
                x: 0, y: 0,
                width: child.measure(proposed: slot.bounds).width,
                height: child.measure(proposed: slot.bounds).height
            )
            layout.position(&slot, laid)
            child.rect = slot.rect
            laid.append(slot)
        }
        return laid
    }

    // MARK: - BoxLayout: Sizing

    func testHugSingleChild() {
        var layout = BoxLayout()
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    func testHugMultipleChildren() {
        var layout = BoxLayout()
        let a = MockChild(80, 40)
        let b = MockChild(60, 100)
        let laid = run(&layout, bounds: Size(200, 200), children: [a, b])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testHugWithPadding() {
        var layout = BoxLayout(padding: .all(10))
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testFixedSize() {
        var layout = BoxLayout(frame: .fixed(150, 100))
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 150, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testFillSize() {
        var layout = BoxLayout(frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(300, 250), children: [child])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 250, accuracy: acc)
    }

    func testFillWidthHugHeight() {
        var layout = BoxLayout(frame: .fillWidth)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(300, 250), children: [child])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    // MARK: - BoxLayout: Alignment

    func testCenterAlignment() {
        var layout = BoxLayout(alignment: .center, frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        XCTAssertEqual(laid[0].rect.x, 60, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 80, accuracy: acc)
    }

    func testTopLeftAlignment() {
        var layout = BoxLayout(alignment: .topLeft, frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        XCTAssertEqual(laid[0].rect.x, 0, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 0, accuracy: acc)
    }

    func testBottomRightAlignment() {
        var layout = BoxLayout(alignment: .bottomRight, frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        XCTAssertEqual(laid[0].rect.x, 120, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 160, accuracy: acc)
    }

    func testAlignmentWithPadding() {
        var layout = BoxLayout(padding: .all(20), alignment: .topLeft, frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        XCTAssertEqual(laid[0].rect.x, 20, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 20, accuracy: acc)
    }

    func testCenterAlignmentWithPadding() {
        var layout = BoxLayout(padding: .all(20), alignment: .center, frame: .fill)
        let child = MockChild(80, 40)
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        // Inner: 160x160, child: 80x40, offset: (40, 60) + padding (20, 20)
        XCTAssertEqual(laid[0].rect.x, 60, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 80, accuracy: acc)
    }

    // MARK: - BoxLayout: Proposal

    func testChildProposedInnerBounds() {
        var layout = BoxLayout(padding: Padding(horizontal: 15, vertical: 25), frame: .fill)
        let child = FillChild()
        let laid = run(&layout, bounds: Size(200, 200), children: [child])
        // Fill child should be proposed 200-30=170 x 200-50=150
        XCTAssertEqual(laid[0].rect.width, 170, accuracy: acc)
        XCTAssertEqual(laid[0].rect.height, 150, accuracy: acc)
    }

    // MARK: - BoxLayout: No Children

    func testHugNoChildren() {
        var layout = BoxLayout()
        let laid = run(&layout, bounds: Size(200, 200), children: [])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 0, accuracy: acc)
        XCTAssertEqual(size.height, 0, accuracy: acc)
    }

    func testFillNoChildren() {
        var layout = BoxLayout(frame: .fill)
        let laid = run(&layout, bounds: Size(200, 200), children: [])
        let size = layout.size(laid)
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 200, accuracy: acc)
    }

    // MARK: - BoxLayout: Multiple Children (overlay)

    func testMultipleChildrenCentered() {
        var layout = BoxLayout(alignment: .center, frame: .fill)
        let a = MockChild(100, 60)
        let b = MockChild(40, 30)
        let laid = run(&layout, bounds: Size(200, 200), children: [a, b])
        // a: centered at (50, 70)
        XCTAssertEqual(laid[0].rect.x, 50, accuracy: acc)
        XCTAssertEqual(laid[0].rect.y, 70, accuracy: acc)
        // b: centered at (80, 85)
        XCTAssertEqual(laid[1].rect.x, 80, accuracy: acc)
        XCTAssertEqual(laid[1].rect.y, 85, accuracy: acc)
    }

    // MARK: - LayoutChild resize callback

    func testResizeCallbackFires() {
        let child = MockChild(80, 40)
        var called = false
        child.resize = { called = true }
        child.resize?()
        XCTAssertTrue(called)
    }
}

#endif
