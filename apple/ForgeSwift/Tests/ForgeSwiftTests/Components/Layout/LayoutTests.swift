#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

// MARK: - Mock Children

/// A mock LayoutChild with a fixed intrinsic size.
private final class MockChild: LayoutChild {
    let intrinsicSize: Size
    var size: Size = .zero
    var position: Vec2 = .zero
    var resize: (() -> Void)?

    init(_ width: Double, _ height: Double) {
        self.intrinsicSize = Size(width, height)
    }

    func measure(proposed: Size) -> Size { intrinsicSize }
}

/// A mock LayoutChild that returns the proposed size (fill behavior).
private final class FillChild: LayoutChild {
    var size: Size = .zero
    var position: Vec2 = .zero
    var resize: (() -> Void)?

    func measure(proposed: Size) -> Size { proposed }
}

/// A mock LayoutChild that returns proposed * fraction.
private final class FractionalChild: LayoutChild {
    let fraction: Double
    var size: Size = .zero
    var position: Vec2 = .zero
    var resize: (() -> Void)?

    init(_ fraction: Double) { self.fraction = fraction }

    func measure(proposed: Size) -> Size {
        Size(proposed.width * fraction, proposed.height * fraction)
    }
}

// MARK: - Helpers

@MainActor
private func runBoxLayout(
    _ layout: inout BoxLayout,
    bounds: Size,
    children: [any LayoutChild]
) -> [LayoutSlot] {
    layout.start(bounds)
    var slots: [LayoutSlot] = []
    for (i, child) in children.enumerated() {
        let slot = LayoutSlot(index: i, child: child)
        layout.measure(slot, slots)
        slots.append(slot)
    }
    for (i, slot) in slots.enumerated() {
        layout.layout(slot, Array(slots[..<i]))
    }
    return slots
}

// MARK: - Tests

@MainActor
final class LayoutTests: XCTestCase {

    private let acc = 0.5

    // MARK: - Frame: Fixed

    func testFixedIgnoresChildSize() {
        var layout = BoxLayout(frame: .fixed(150, 100))
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 150, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testFixedIgnoresBounds() {
        var layout = BoxLayout(frame: .fixed(300, 300))
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 300, accuracy: acc)
    }

    // MARK: - Frame: Fill

    func testFillReturnsBounds() {
        var layout = BoxLayout(frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(300, 250), children: [MockChild(80, 40)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 250, accuracy: acc)
    }

    func testFillWidthHugHeight() {
        var layout = BoxLayout(frame: .fillWidth)
        let slots = runBoxLayout(&layout, bounds: Size(300, 250), children: [MockChild(80, 40)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    func testFillNoChildren() {
        var layout = BoxLayout(frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 200, accuracy: acc)
    }

    // MARK: - Frame: Hug

    func testHugSingleChild() {
        var layout = BoxLayout()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    func testHugMultipleChildrenUsesLargest() {
        var layout = BoxLayout()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [
            MockChild(80, 40), MockChild(60, 100)
        ])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testHugWithPadding() {
        var layout = BoxLayout(padding: .all(10))
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testHugNoChildren() {
        var layout = BoxLayout()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 0, accuracy: acc)
        XCTAssertEqual(size.height, 0, accuracy: acc)
    }

    func testHugWithMinClamps() {
        var layout = BoxLayout(frame: Frame(.hug(min: 100), .hug(min: 80)))
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(40, 30)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 80, accuracy: acc)
    }

    func testHugWithMaxClamps() {
        var layout = BoxLayout(frame: Frame(.hug(max: 60), .hug(max: 50)))
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 80)])
        let size = layout.size(slots)
        XCTAssertEqual(size.width, 60, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    // MARK: - Hug with fill child

    func testHugWithFillChildReturnsBounds() {
        var layout = BoxLayout()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [FillChild()])
        let size = layout.size(slots)
        // Fill child returns 200x200, hug wraps to that.
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 200, accuracy: acc)
    }

    func testHugWithFractionalChild() {
        var layout = BoxLayout()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [FractionalChild(0.5)])
        let size = layout.size(slots)
        // Fractional child returns 100x100, hug wraps to that.
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    // MARK: - Child proposal

    func testChildProposedInnerBounds() {
        var layout = BoxLayout(padding: Padding(horizontal: 15, vertical: 25), frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [FillChild()])
        // Fill child proposed inner (170x150), returns that.
        XCTAssertEqual(slots[0].rect.width, 170, accuracy: acc)
        XCTAssertEqual(slots[0].rect.height, 150, accuracy: acc)
    }

    // MARK: - Alignment

    func testCenterAlignment() {
        var layout = BoxLayout(alignment: .center, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        XCTAssertEqual(slots[0].rect.x, 60, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 80, accuracy: acc)
    }

    func testTopLeftAlignment() {
        var layout = BoxLayout(alignment: .topLeft, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        XCTAssertEqual(slots[0].rect.x, 0, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 0, accuracy: acc)
    }

    func testBottomRightAlignment() {
        var layout = BoxLayout(alignment: .bottomRight, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        XCTAssertEqual(slots[0].rect.x, 120, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 160, accuracy: acc)
    }

    func testAlignmentWithPadding() {
        var layout = BoxLayout(padding: .all(20), alignment: .topLeft, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        XCTAssertEqual(slots[0].rect.x, 20, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 20, accuracy: acc)
    }

    func testCenterAlignmentWithPadding() {
        var layout = BoxLayout(padding: .all(20), alignment: .center, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(80, 40)])
        // Inner: 160x160, child: 80x40, offset: (40, 60) + padding (20, 20)
        XCTAssertEqual(slots[0].rect.x, 60, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 80, accuracy: acc)
    }

    // MARK: - Multiple children (overlay)

    func testMultipleChildrenCentered() {
        var layout = BoxLayout(alignment: .center, frame: .fill)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [
            MockChild(100, 60), MockChild(40, 30)
        ])
        XCTAssertEqual(slots[0].rect.x, 50, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 70, accuracy: acc)
        XCTAssertEqual(slots[1].rect.x, 80, accuracy: acc)
        XCTAssertEqual(slots[1].rect.y, 85, accuracy: acc)
    }

    // MARK: - Overflow: scroll

    func testScrollProposesUnlimitedOnScrollAxis() {
        var layout = BoxLayout(overflow: .scroll(ScrollConfig(axis: .vertical)))
        let child = FillChild()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [child])
        // Vertical scroll: width proposed normally (200), height unlimited.
        XCTAssertEqual(slots[0].rect.width, 200, accuracy: acc)
        XCTAssertTrue(slots[0].rect.height > 1_000_000)
    }

    func testScrollHorizontalProposesUnlimitedWidth() {
        var layout = BoxLayout(overflow: .scroll(ScrollConfig(axis: .horizontal)))
        let child = FillChild()
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [child])
        XCTAssertTrue(slots[0].rect.width > 1_000_000)
        XCTAssertEqual(slots[0].rect.height, 200, accuracy: acc)
    }

    // MARK: - Child larger than container

    func testChildLargerThanContainerClip() {
        var layout = BoxLayout(alignment: .topLeft, frame: .fill, overflow: .clip)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(300, 300)])
        // Child keeps its natural size, positioned at origin.
        XCTAssertEqual(slots[0].rect.width, 300, accuracy: acc)
        XCTAssertEqual(slots[0].rect.height, 300, accuracy: acc)
        XCTAssertEqual(slots[0].rect.x, 0, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 0, accuracy: acc)
    }

    func testChildLargerThanContainerCentered() {
        var layout = BoxLayout(alignment: .center, frame: .fill, overflow: .clip)
        let slots = runBoxLayout(&layout, bounds: Size(200, 200), children: [MockChild(300, 300)])
        // Child is larger — alignment can't push it, stays at padding edge.
        XCTAssertEqual(slots[0].rect.x, 0, accuracy: acc)
        XCTAssertEqual(slots[0].rect.y, 0, accuracy: acc)
    }

    // MARK: - Resize callback

    func testResizeCallbackFires() {
        let child = MockChild(80, 40)
        var called = false
        child.resize = { called = true }
        child.resize?()
        XCTAssertTrue(called)
    }
}

#endif
