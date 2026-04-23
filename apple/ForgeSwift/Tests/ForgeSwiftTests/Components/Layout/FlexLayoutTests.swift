#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

private class FixedSizeView: UIView {
    let fixedSize: CGSize
    init(size: CGSize) {
        self.fixedSize = size
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func sizeThatFits(_ size: CGSize) -> CGSize { fixedSize }
}

@MainActor
final class FlexLayoutTests: XCTestCase {

    private let acc = 0.01

    // MARK: - Helpers

    /// Create a FixedSizeView child.
    private func child(_ w: Double, _ h: Double) -> FixedSizeView {
        FixedSizeView(size: CGSize(width: w, height: h))
    }

    /// Create a FlexSlot with a dummy view and given measured size.
    private func slot(_ w: Double, _ h: Double, flex: Double? = nil, stretch: Bool = false) -> FlexSlot {
        let view = child(w, h)
        return FlexSlot(index: 0, view: view, measured: Size(w, h), flex: flex, stretch: stretch)
    }

    /// Create a FlexLine from slot sizes.
    private func line(_ slots: [FlexSlot], mainAxis: Axis = .horizontal) -> FlexLine {
        var line = FlexLine()
        let isH = mainAxis == .horizontal
        for s in slots {
            line.slots.append(s)
            // Bounds accumulation mirrors splitLines logic (no spacing — caller sets bounds if needed)
            let mainSize = line.bounds.on(mainAxis) + s.measured.on(mainAxis)
            let crossSize = max(line.bounds.on(mainAxis.cross), s.measured.on(mainAxis.cross))
            line.bounds = isH ? Size(mainSize, crossSize) : Size(crossSize, mainSize)
        }
        return line
    }

    /// Create a FlexLine with explicit bounds (useful when you need spacing included).
    private func line(_ slots: [FlexSlot], bounds: Size) -> FlexLine {
        FlexLine(slots: slots, bounds: bounds)
    }

    /// Create a configured FlexView for testing.
    private func flexView(
        axis: Axis = .horizontal,
        spacing: Double = 0,
        lineSpacing: Double = 0,
        alignment: Alignment = .center,
        spread: Spread? = nil,
        wrap: Bool = false
    ) -> FlexView {
        let view = FlexView()
        var style = FlexStyle()
        style.axis = axis
        style.spacing = spacing
        style.lineSpacing = lineSpacing
        style.alignment = alignment
        style.spread = spread
        style.wrap = wrap
        view.style = style
        return view
    }

    // MARK: - 1. applyFrames

    func testApplyFramesSetsChildFrames() {
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        var s1 = FlexSlot(index: 0, view: c1, measured: Size(40, 20))
        var s2 = FlexSlot(index: 1, view: c2, measured: Size(60, 30))
        s1.origin = Point(10, 5)
        s1.resolved = Size(40, 20)
        s2.origin = Point(60, 0)
        s2.resolved = Size(60, 30)
        var lines = [FlexLine(slots: [s1, s2], bounds: Size(120, 30))]

        let flex = flexView()
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.applyFrames(&lines)

        XCTAssertEqual(c1.frame.origin.x, 10, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 5, accuracy: acc)
        XCTAssertEqual(c1.frame.size.width, 40, accuracy: acc)
        XCTAssertEqual(c1.frame.size.height, 20, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 60, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.size.width, 60, accuracy: acc)
        XCTAssertEqual(c2.frame.size.height, 30, accuracy: acc)
    }

    // MARK: - 2. resolveMainSpacing

    // Remaining=70, 3 children, no flex

    func testResolveMainSpacingNilSpread() {
        let flex = flexView(spacing: 10, alignment: .center)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: false)
        // nil spread, center alignment: start = 70 * (0+1)/2 = 35
        XCTAssertEqual(start, 35, accuracy: acc)
        XCTAssertEqual(gap, 10, accuracy: acc)
    }

    func testResolveMainSpacingNilSpreadTopLeft() {
        let flex = flexView(spacing: 10, alignment: .topLeft)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: false)
        // topLeft: alignment.x = -1, start = 70 * (-1+1)/2 = 0
        XCTAssertEqual(start, 0, accuracy: acc)
        XCTAssertEqual(gap, 10, accuracy: acc)
    }

    func testResolveMainSpacingNilSpreadBottomRight() {
        let flex = flexView(spacing: 10, alignment: .bottomRight)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: false)
        // bottomRight: alignment.x = 1, start = 70 * (1+1)/2 = 70
        XCTAssertEqual(start, 70, accuracy: acc)
        XCTAssertEqual(gap, 10, accuracy: acc)
    }

    func testResolveMainSpacingPacked() {
        let flex = flexView(spacing: 10, alignment: .center, spread: .packed)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: false)
        XCTAssertEqual(start, 35, accuracy: acc)
        XCTAssertEqual(gap, 10, accuracy: acc)
    }

    func testResolveMainSpacingBetween() {
        let flex = flexView(spread: .between)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: false)
        XCTAssertEqual(start, 0, accuracy: acc)
        XCTAssertEqual(gap, 35, accuracy: acc) // 70 / 2
    }

    func testResolveMainSpacingBetweenOneChild() {
        let flex = flexView(spread: .between)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 1, hasFlex: false)
        XCTAssertEqual(start, 0, accuracy: acc)
        XCTAssertEqual(gap, 0, accuracy: acc)
    }

    func testResolveMainSpacingAround() {
        let flex = flexView(spread: .around)
        let (start, gap) = flex.resolveMainSpacing(remaining: 90, count: 3, hasFlex: false)
        // gap = 90/3 = 30, start = 30/2 = 15
        XCTAssertEqual(start, 15, accuracy: acc)
        XCTAssertEqual(gap, 30, accuracy: acc)
    }

    func testResolveMainSpacingEven() {
        let flex = flexView(spread: .even)
        let (start, gap) = flex.resolveMainSpacing(remaining: 80, count: 3, hasFlex: false)
        // gap = 80/4 = 20, start = 20
        XCTAssertEqual(start, 20, accuracy: acc)
        XCTAssertEqual(gap, 20, accuracy: acc)
    }

    func testResolveMainSpacingWithFlex() {
        let flex = flexView(spacing: 10, spread: .between)
        let (start, gap) = flex.resolveMainSpacing(remaining: 70, count: 3, hasFlex: true)
        // hasFlex overrides: start = 0, gap = spacing
        XCTAssertEqual(start, 0, accuracy: acc)
        XCTAssertEqual(gap, 10, accuracy: acc)
    }

    func testResolveMainSpacingZeroRemaining() {
        let flex = flexView(spread: .between)
        let (start, gap) = flex.resolveMainSpacing(remaining: 0, count: 3, hasFlex: false)
        XCTAssertEqual(start, 0, accuracy: acc)
        XCTAssertEqual(gap, 0, accuracy: acc)
    }

    // MARK: - 3. boundingBox

    func testBoundingBoxNoSpreadHorizontal() {
        let flex = flexView(axis: .horizontal, lineSpacing: 5)
        let s1 = slot(40, 20)
        let s2 = slot(60, 30)
        // Line bounds: main=100, cross=30
        flex.lines = [line([s1, s2], bounds: Size(100, 30))]
        flex.measuredSizeCache = Size(200, 100) // won't matter for nil spread
        let result = flex.boundingBox(in: Size(200, 100))
        // No spread: mainSize = max of line main = 100, crossSize = 30, no lineSpacing (1 line)
        XCTAssertEqual(result.width, 100, accuracy: acc)
        XCTAssertEqual(result.height, 30, accuracy: acc)
    }

    func testBoundingBoxWithSpreadHorizontal() {
        let flex = flexView(axis: .horizontal, spread: .between)
        let s1 = slot(40, 20)
        let s2 = slot(60, 30)
        flex.lines = [line([s1, s2], bounds: Size(100, 30))]
        let result = flex.boundingBox(in: Size(200, 100))
        // With spread: mainSize = proposed = 200
        XCTAssertEqual(result.width, 200, accuracy: acc)
        XCTAssertEqual(result.height, 30, accuracy: acc)
    }

    func testBoundingBoxMultiLineHorizontal() {
        let flex = flexView(axis: .horizontal, lineSpacing: 10)
        let s1 = slot(40, 20)
        let s2 = slot(60, 30)
        let s3 = slot(50, 25)
        flex.lines = [
            line([s1, s2], bounds: Size(100, 30)),
            line([s3], bounds: Size(50, 25))
        ]
        let result = flex.boundingBox(in: Size(200, 200))
        // mainSize = max(100, 50) = 100, crossSize = 30 + 25 + 10 = 65
        XCTAssertEqual(result.width, 100, accuracy: acc)
        XCTAssertEqual(result.height, 65, accuracy: acc)
    }

    func testBoundingBoxVertical() {
        let flex = flexView(axis: .vertical, lineSpacing: 5)
        let s1 = slot(40, 20)
        let s2 = slot(60, 30)
        // For vertical: main=height, cross=width. Line bounds stored as Size(cross, main) = Size(60, 50)
        flex.lines = [line([s1, s2], bounds: Size(60, 50))]
        let result = flex.boundingBox(in: Size(200, 400))
        // No spread: mainSize(height) = 50, crossSize(width) = 60
        XCTAssertEqual(result.width, 60, accuracy: acc)
        XCTAssertEqual(result.height, 50, accuracy: acc)
    }

    func testBoundingBoxEmptyLines() {
        let flex = flexView()
        flex.lines = []
        let result = flex.boundingBox(in: Size(200, 100))
        XCTAssertEqual(result.width, 0, accuracy: acc)
        XCTAssertEqual(result.height, 0, accuracy: acc)
    }

    // MARK: - 4. splitLines

    func testSplitLinesNoWrapSingleLine() {
        let flex = flexView(axis: .horizontal, spacing: 10)
        let slots = [slot(40, 20), slot(60, 30), slot(30, 10)]
        // Total with spacing: 40 + 10 + 60 + 10 + 30 = 150, fits in 200
        let result = flex.splitLines(slots: slots, size: Size(200, 100))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].slots.count, 3)
        XCTAssertEqual(result[0].bounds.width, 150, accuracy: acc)
        XCTAssertEqual(result[0].bounds.height, 30, accuracy: acc)
    }

    func testSplitLinesTwoLines() {
        let flex = flexView(axis: .horizontal, spacing: 10)
        let slots = [slot(80, 20), slot(80, 30), slot(80, 10)]
        // 80 + 10 + 80 = 170 fits, 170 + 10 + 80 = 260 > 200 → wraps
        let result = flex.splitLines(slots: slots, size: Size(200, 100))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].slots.count, 2)
        XCTAssertEqual(result[1].slots.count, 1)
        XCTAssertEqual(result[0].bounds.width, 170, accuracy: acc)
        XCTAssertEqual(result[0].bounds.height, 30, accuracy: acc)
        XCTAssertEqual(result[1].bounds.width, 80, accuracy: acc)
        XCTAssertEqual(result[1].bounds.height, 10, accuracy: acc)
    }

    func testSplitLinesOversizedChild() {
        let flex = flexView(axis: .horizontal, spacing: 0)
        let slots = [slot(50, 20), slot(250, 30), slot(50, 10)]
        // 250 > 200, but first in its line so it stays. 50 doesn't fit after 250.
        let result = flex.splitLines(slots: slots, size: Size(200, 100))
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].slots.count, 1)
        XCTAssertEqual(result[1].slots.count, 1)
        XCTAssertEqual(result[2].slots.count, 1)
    }

    func testSplitLinesEmpty() {
        let flex = flexView()
        let result = flex.splitLines(slots: [], size: Size(200, 100))
        XCTAssertEqual(result.count, 0)
    }

    func testSplitLinesVertical() {
        let flex = flexView(axis: .vertical, spacing: 5)
        let slots = [slot(40, 60), slot(50, 60), slot(30, 60)]
        // Vertical: main = height. 60 + 5 + 60 = 125, 125 + 5 + 60 = 190 > 150 → wraps
        let result = flex.splitLines(slots: slots, size: Size(200, 150))
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].slots.count, 2)
        XCTAssertEqual(result[1].slots.count, 1)
    }

    func testSplitLinesZeroSpacing() {
        let flex = flexView(axis: .horizontal, spacing: 0)
        let slots = [slot(100, 20), slot(100, 20)]
        // 100 + 100 = 200 == 200, fits exactly
        let result = flex.splitLines(slots: slots, size: Size(200, 100))
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].slots.count, 2)
    }

    // MARK: - 5. arrangeSlots

    // Helper: set up FlexView with measuredSizeCache and lines, then call arrangeSlots
    private func arrange(
        axis: Axis = .horizontal,
        spacing: Double = 0,
        lineSpacing: Double = 0,
        alignment: Alignment = .center,
        spread: Spread? = nil,
        measuredSize: Size,
        lines: [FlexLine]
    ) -> [FlexLine] {
        let flex = flexView(axis: axis, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread)
        flex.measuredSizeCache = measuredSize
        var mutableLines = lines
        flex.arrangeSlots(&mutableLines)
        return mutableLines
    }

    // -- No spread, center aligned, horizontal --

    func testArrangeNilSpreadCenter() {
        // 3 children: 40 + 60 + 30 = 130. Container main = 200. Remaining = 70.
        // Center: start = 35. Gap = 0 (no spacing). Cross: all same height, crossAlign doesn't matter.
        let s = [slot(40, 20), slot(60, 20), slot(30, 20)]
        let ln = line(s, bounds: Size(130, 20))
        let result = arrange(measuredSize: Size(200, 100), lines: [ln])

        XCTAssertEqual(result[0].slots[0].origin.x, 35, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 75, accuracy: acc)  // 35 + 40
        XCTAssertEqual(result[0].slots[2].origin.x, 135, accuracy: acc) // 75 + 60
    }

    func testArrangeNilSpreadTopLeft() {
        let s = [slot(40, 20), slot(60, 20)]
        let ln = line(s, bounds: Size(100, 20))
        let result = arrange(alignment: .topLeft, measuredSize: Size(200, 100), lines: [ln])

        // topLeft: start = 0, crossOffset = 0
        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].origin.y, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 40, accuracy: acc)
    }

    func testArrangeNilSpreadBottomRight() {
        let s = [slot(40, 20), slot(60, 30)]
        let ln = line(s, bounds: Size(100, 30))
        let result = arrange(alignment: .bottomRight, measuredSize: Size(200, 100), lines: [ln])

        // bottomRight: start = 100, crossAlign = 1
        // Slot 0: origin.x = 100, crossOffset = 0 + (30-20)*1 = 10
        XCTAssertEqual(result[0].slots[0].origin.x, 100, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].origin.y, 10, accuracy: acc)
        // Slot 1: origin.x = 140, crossOffset = 0 + (30-30)*1 = 0
        XCTAssertEqual(result[0].slots[1].origin.x, 140, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.y, 0, accuracy: acc)
    }

    // -- Spread modes --

    func testArrangeBetween() {
        let s = [slot(40, 20), slot(60, 20), slot(30, 20)]
        let ln = line(s, bounds: Size(130, 20))
        let result = arrange(spread: .between, measuredSize: Size(200, 20), lines: [ln])

        // Remaining = 70, gap = 70/2 = 35
        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 75, accuracy: acc)  // 0 + 40 + 35
        XCTAssertEqual(result[0].slots[2].origin.x, 170, accuracy: acc) // 75 + 60 + 35
    }

    func testArrangeAround() {
        let s = [slot(40, 20), slot(60, 20)]
        let ln = line(s, bounds: Size(100, 20))
        let result = arrange(spread: .around, measuredSize: Size(200, 20), lines: [ln])

        // Remaining = 100, gap = 100/2 = 50, start = 25
        XCTAssertEqual(result[0].slots[0].origin.x, 25, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 115, accuracy: acc) // 25 + 40 + 50
    }

    func testArrangeEven() {
        let s = [slot(40, 20), slot(60, 20)]
        let ln = line(s, bounds: Size(100, 20))
        let result = arrange(spread: .even, measuredSize: Size(200, 20), lines: [ln])

        // Remaining = 100, gap = 100/3 ≈ 33.33, start ≈ 33.33
        let g = 100.0 / 3.0
        XCTAssertEqual(result[0].slots[0].origin.x, g, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, g + 40 + g, accuracy: acc)
    }

    // -- Spacing --

    func testArrangeWithSpacing() {
        let s = [slot(40, 20), slot(60, 20)]
        let ln = line(s, bounds: Size(110, 20)) // 40 + 10 + 60
        let result = arrange(spacing: 10, alignment: .topLeft, measuredSize: Size(200, 100), lines: [ln])

        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 50, accuracy: acc) // 0 + 40 + 10
    }

    // -- Flex children --

    func testArrangeFlexChild() {
        // One flex child (weight 1) + one fixed child
        let s = [slot(40, 20, flex: 1), slot(60, 20)]
        let ln = line(s, bounds: Size(100, 20))
        let result = arrange(measuredSize: Size(200, 20), lines: [ln])

        // Remaining = 100, totalFlex = 1. Flex child gets 40 + 100 = 140.
        XCTAssertEqual(result[0].slots[0].resolved.width, 140, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].resolved.width, 60, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 140, accuracy: acc)
    }

    func testArrangeTwoFlexChildren() {
        let s = [slot(0, 20, flex: 2), slot(0, 20, flex: 1)]
        let ln = line(s, bounds: Size(0, 20))
        let result = arrange(measuredSize: Size(300, 20), lines: [ln])

        // Remaining = 300, flex1 gets 0 + 300*(2/3) = 200, flex2 gets 0 + 300*(1/3) = 100
        XCTAssertEqual(result[0].slots[0].resolved.width, 200, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].resolved.width, 100, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.x, 200, accuracy: acc)
    }

    // -- Cross-axis alignment --

    func testArrangeCrossAlignCenter() {
        // Two children with different heights, center aligned
        let s = [slot(40, 20), slot(60, 40)]
        let ln = line(s, bounds: Size(100, 40))
        let result = arrange(alignment: .center, measuredSize: Size(200, 100), lines: [ln])

        // Cross align = (0+1)/2 = 0.5. Slot 0: (40-20)*0.5 = 10. Slot 1: (40-40)*0.5 = 0.
        XCTAssertEqual(result[0].slots[0].origin.y, 10, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.y, 0, accuracy: acc)
    }

    func testArrangeCrossAlignBottom() {
        let s = [slot(40, 20), slot(60, 40)]
        let ln = line(s, bounds: Size(100, 40))
        let result = arrange(alignment: .bottomLeft, measuredSize: Size(200, 100), lines: [ln])

        // Cross align = (1+1)/2 = 1. Slot 0: (40-20)*1 = 20.
        XCTAssertEqual(result[0].slots[0].origin.y, 20, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.y, 0, accuracy: acc)
    }

    // -- Multi-line --

    func testArrangeMultiLineStacking() {
        let s1 = [slot(80, 30), slot(80, 20)]
        let s2 = [slot(60, 25)]
        let ln1 = line(s1, bounds: Size(160, 30))
        let ln2 = line(s2, bounds: Size(60, 25))
        let result = arrange(lineSpacing: 10, alignment: .topLeft, measuredSize: Size(200, 100), lines: [ln1, ln2])

        // Line 1 starts at cross 0, line 2 starts at 30 + 10 = 40
        XCTAssertEqual(result[0].slots[0].origin.y, 0, accuracy: acc)
        XCTAssertEqual(result[1].slots[0].origin.y, 40, accuracy: acc)
    }

    func testArrangeMultiLineCrossAlign() {
        let s1 = [slot(40, 20), slot(40, 40)]
        let s2 = [slot(40, 15)]
        let ln1 = line(s1, bounds: Size(80, 40))
        let ln2 = line(s2, bounds: Size(40, 15))
        let result = arrange(lineSpacing: 0, alignment: .center, measuredSize: Size(200, 100), lines: [ln1, ln2])

        // Line 1: slot 0 cross = (40-20)*0.5 = 10, slot 1 cross = 0
        XCTAssertEqual(result[0].slots[0].origin.y, 10, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.y, 0, accuracy: acc)
        // Line 2 starts at cross 40. Slot cross = (15-15)*0.5 = 0 → y = 40
        XCTAssertEqual(result[1].slots[0].origin.y, 40, accuracy: acc)
    }

    // -- Vertical axis --

    func testArrangeVerticalAxis() {
        let s = [slot(40, 30), slot(50, 60)]
        // Vertical: main=height, cross=width. Bounds: main=90, cross=50
        let ln = line(s, bounds: Size(50, 90))
        let result = arrange(axis: .vertical, alignment: .topLeft, measuredSize: Size(100, 200), lines: [ln])

        // Vertical: origins are (crossOffset, mainOffset). Flipped to (x, y).
        // Slot 0: main=0, cross=0 → origin = (0, 0)
        XCTAssertEqual(result[0].slots[0].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].origin.y, 0, accuracy: acc)
        // Slot 1: main=30, cross=0 → origin = (0, 30)
        XCTAssertEqual(result[0].slots[1].origin.x, 0, accuracy: acc)
        XCTAssertEqual(result[0].slots[1].origin.y, 30, accuracy: acc)
        // Resolved sizes are flipped: slot 0 = (40, 30), slot 1 = (50, 60)
        XCTAssertEqual(result[0].slots[0].resolved.width, 40, accuracy: acc)
        XCTAssertEqual(result[0].slots[0].resolved.height, 30, accuracy: acc)
    }

    // MARK: - 6. measureChildren

    func testMeasureChildrenSizes() {
        let flex = flexView()
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        flex.addSubview(c1)
        flex.addSubview(c2)
        let slots = flex.measureChildren(size: Size(200, 100))

        XCTAssertEqual(slots.count, 2)
        XCTAssertEqual(slots[0].measured.width, 40, accuracy: acc)
        XCTAssertEqual(slots[0].measured.height, 20, accuracy: acc)
        XCTAssertEqual(slots[1].measured.width, 60, accuracy: acc)
        XCTAssertEqual(slots[1].measured.height, 30, accuracy: acc)
        XCTAssertNil(slots[0].flex)
        XCTAssertNil(slots[1].flex)
    }

    func testMeasureChildrenWithFlexData() {
        let flex = flexView()
        let c1 = child(40, 20)
        let host = ParentDataView<FlexData>()
        host.data = FlexData(flex: 2, stretch: true)
        host.addSubview(c1)
        flex.addSubview(host)

        let slots = flex.measureChildren(size: Size(200, 100))
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].flex!, 2, accuracy: acc)
        XCTAssertTrue(slots[0].stretch)
    }

    // MARK: - 7. End-to-end layoutSubviews

    func testEndToEndHorizontalPacked() {
        let flex = flexView(axis: .horizontal, spacing: 10, alignment: .topLeft)
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        flex.layoutSubviews()

        // No spread, topLeft: start = 0
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c1.frame.size.width, 40, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 50, accuracy: acc) // 40 + 10
        XCTAssertEqual(c2.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.size.width, 60, accuracy: acc)
    }

    func testEndToEndVerticalBetween() {
        let flex = flexView(axis: .vertical, alignment: .topLeft, spread: .between)
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        flex.layoutSubviews()

        // Vertical between: main=height. Children 20+30=50, remaining=50, gap=50
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 70, accuracy: acc) // 0 + 20 + 50
    }

    func testEndToEndWrap() {
        let flex = flexView(axis: .horizontal, spacing: 0, lineSpacing: 5, alignment: .topLeft, wrap: true)
        let c1 = child(80, 20)
        let c2 = child(80, 30)
        let c3 = child(80, 25)
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.addSubview(c3)
        flex.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        flex.layoutSubviews()

        // Line 1: c1 + c2 = 160 ≤ 200 → fits. Line 2: c3.
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 80, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 0, accuracy: acc)
        // Line 2: cross starts at max(20,30) + 5 = 35
        XCTAssertEqual(c3.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c3.frame.origin.y, 35, accuracy: acc)
    }

    func testEndToEndEmpty() {
        let flex = flexView()
        flex.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        flex.layoutSubviews()
        // No crash, no children
    }

    func testEndToEndSingleChild() {
        let flex = flexView(axis: .horizontal, alignment: .center, spread: .between)
        let c1 = child(40, 20)
        flex.addSubview(c1)
        flex.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
        flex.layoutSubviews()

        // Between with 1 child: start=0, gap=0
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c1.frame.size.width, 40, accuracy: acc)
    }

    func testSizeThatFitsReturnsCorrectSize() {
        let flex = flexView(axis: .horizontal, spacing: 10, alignment: .topLeft)
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        flex.addSubview(c1)
        flex.addSubview(c2)
        let size = flex.sizeThatFits(CGSize(width: 200, height: 100))

        // No spread: main = 40 + 10 + 60 = 110, cross = max(20,30) = 30
        XCTAssertEqual(size.width, 110, accuracy: acc)
        XCTAssertEqual(size.height, 30, accuracy: acc)
    }

    func testSizeThatFitsWithSpread() {
        let flex = flexView(axis: .horizontal, spread: .between)
        let c1 = child(40, 20)
        let c2 = child(60, 30)
        flex.addSubview(c1)
        flex.addSubview(c2)
        let size = flex.sizeThatFits(CGSize(width: 200, height: 100))

        // With spread: main = proposed = 200
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 30, accuracy: acc)
    }

    func testSizeThatFitsChildrenOverflow() {
        let flex = flexView(axis: .vertical, spacing: 10, alignment: .topLeft)
        let c1 = child(40, 100)
        let c2 = child(60, 150)
        let c3 = child(50, 200)
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.addSubview(c3)
        let size = flex.sizeThatFits(CGSize(width: 200, height: 300))

        // No spread: main = 100 + 10 + 150 + 10 + 200 = 470, cross = max(40,60,50) = 60
        // Should report actual content size, not clamp to proposed 300
        XCTAssertEqual(size.height, 470, accuracy: acc)
        XCTAssertEqual(size.width, 60, accuracy: acc)
    }

    func testSizeThatFitsHorizontalOverflow() {
        let flex = flexView(axis: .horizontal, spacing: 5)
        let c1 = child(100, 30)
        let c2 = child(120, 20)
        let c3 = child(80, 25)
        flex.addSubview(c1)
        flex.addSubview(c2)
        flex.addSubview(c3)
        let size = flex.sizeThatFits(CGSize(width: 200, height: 100))

        // No spread: main = 100 + 5 + 120 + 5 + 80 = 310, cross = 30
        XCTAssertEqual(size.width, 310, accuracy: acc)
        XCTAssertEqual(size.height, 30, accuracy: acc)
    }
}

#endif
