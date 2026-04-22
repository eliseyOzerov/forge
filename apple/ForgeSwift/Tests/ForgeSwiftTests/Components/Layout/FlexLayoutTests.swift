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

    private let acc: CGFloat = 0.5

    // MARK: - Helpers

    private func child(_ w: CGFloat, _ h: CGFloat) -> FixedSizeView {
        FixedSizeView(size: CGSize(width: w, height: h))
    }

    /// Create a BoxView with flex sizing on the given axis for weighted distribution testing.
    private func fillBox(
        weight: Int = 1,
        axis: NSLayoutConstraint.Axis = .horizontal,
        intrinsicCross: CGFloat = 30
    ) -> BoxView {
        let box = BoxView()
        if axis == .horizontal {
            box.sizing = Frame(.flex(weight), .hug())
        } else {
            box.sizing = Frame(.hug(), .flex(weight))
        }
        // Add a child so cross-axis measurement returns something
        let c = FixedSizeView(size: CGSize(width: intrinsicCross, height: intrinsicCross))
        box.addSubview(c)
        return box
    }

    /// Create a FlexView (Column or Row), add children, set frame, trigger layout.
    private func layoutFlex(
        axis: NSLayoutConstraint.Axis = .vertical,
        spacing: Double = 0,
        lineSpacing: Double = 0,
        alignment: Alignment = .center,
        spread: Spread = .packed,
        wrap: Bool = false,
        containerSize: CGSize = CGSize(width: 200, height: 400),
        children: [UIView]
    ) -> FlexView {
        let flex = FlexView()
        flex.flexAxis = axis
        flex.flexSpacing = spacing
        flex.flexLineSpacing = lineSpacing
        flex.flexAlignment = alignment
        flex.flexSpread = spread
        flex.flexWrap = wrap
        for child in children { flex.addSubview(child) }
        flex.frame = CGRect(origin: .zero, size: containerSize)
        flex.layoutSubviews()
        return flex
    }

    private func sizeFlex(
        axis: NSLayoutConstraint.Axis = .vertical,
        spacing: Double = 0,
        spread: Spread = .packed,
        wrap: Bool = false,
        proposed: CGSize = CGSize(width: 200, height: 400),
        children: [UIView]
    ) -> CGSize {
        let flex = FlexView()
        flex.flexAxis = axis
        flex.flexSpacing = spacing
        flex.flexSpread = spread
        flex.flexWrap = wrap
        for child in children { flex.addSubview(child) }
        return flex.sizeThatFits(proposed)
    }

    // MARK: - sizeThatFits: Column

    func testColumnSizeThatFitsZeroChildren() {
        let size = sizeFlex(axis: .vertical, children: [])
        XCTAssertEqual(size.width, 0, accuracy: acc)
        XCTAssertEqual(size.height, 0, accuracy: acc)
    }

    func testColumnSizeThatFitsSingleChild() {
        let size = sizeFlex(axis: .vertical, children: [child(80, 50)])
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    func testColumnSizeThatFitsTwoChildren() {
        let size = sizeFlex(axis: .vertical, spacing: 10, children: [child(80, 50), child(60, 40)])
        // width = max(80, 60) = 80, height = 50 + 40 + 10 = 100
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testColumnSizeThatFitsThreeChildrenWithSpacing() {
        let size = sizeFlex(axis: .vertical, spacing: 5, children: [child(60, 30), child(60, 30), child(60, 30)])
        // height = 30*3 + 5*2 = 100
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testColumnSizeThatFitsWithFillChild() {
        let fb = fillBox(axis: .vertical)
        let size = sizeFlex(axis: .vertical, proposed: CGSize(width: 200, height: 400), children: [child(60, 30), fb])
        // Has a fill child → takes proposed height
        XCTAssertEqual(size.height, 400, accuracy: acc)
    }

    func testColumnSizeThatFitsSpreadTakesProposed() {
        let size = sizeFlex(axis: .vertical, spread: .between, proposed: CGSize(width: 200, height: 400), children: [child(60, 30), child(60, 30)])
        XCTAssertEqual(size.height, 400, accuracy: acc)
    }

    // MARK: - sizeThatFits: Row

    func testRowSizeThatFitsSingleChild() {
        let size = sizeFlex(axis: .horizontal, children: [child(80, 50)])
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    func testRowSizeThatFitsTwoChildren() {
        let size = sizeFlex(axis: .horizontal, spacing: 10, children: [child(80, 50), child(60, 40)])
        // width = 80 + 60 + 10 = 150, height = max(50, 40) = 50
        XCTAssertEqual(size.width, 150, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    func testRowSizeThatFitsWithFillChild() {
        let fb = fillBox(axis: .horizontal)
        let size = sizeFlex(axis: .horizontal, proposed: CGSize(width: 300, height: 200), children: [child(60, 30), fb])
        XCTAssertEqual(size.width, 300, accuracy: acc)
    }

    // MARK: - Child Positioning: Column, packed, center

    func testColumnPackedCenterTwoChildren() {
        let c1 = child(100, 50)
        let c2 = child(60, 50)
        let flex = layoutFlex(
            axis: .vertical, spacing: 10, alignment: .center,
            containerSize: CGSize(width: 200, height: 400),
            children: [c1, c2]
        )
        // Group height = 50 + 50 + 10 = 110. Centered in 400 → starts at (400-110)/2 = 145
        // Cross: line.crossSize=100, container=200, center → offset = (200-100)*0.5 = 50
        // c1: crossOffset = (100-100)*0.5 + 50 = 50, c2: (100-60)*0.5 + 50 = 70
        XCTAssertEqual(c1.frame.origin.y, 145, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.x, 50, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 205, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 70, accuracy: acc)
    }

    func testColumnPackedTopLeft() {
        let c1 = child(80, 40)
        let c2 = child(60, 40)
        let flex = layoutFlex(
            axis: .vertical, spacing: 0, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 400),
            children: [c1, c2]
        )
        // TopLeft: main align = top (factor 0), cross align = left (factor 0)
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 40, accuracy: acc)
    }

    func testColumnPackedBottomRight() {
        let c1 = child(80, 40)
        let c2 = child(60, 40)
        let flex = layoutFlex(
            axis: .vertical, spacing: 0, alignment: .bottomRight,
            containerSize: CGSize(width: 200, height: 400),
            children: [c1, c2]
        )
        // Group height = 80. Bottom-aligned: starts at 400 - 80 = 320
        // Cross: line.crossSize=80, container=200, right → offset = (200-80)*1 = 120
        // c1: crossOffset = (80-80)*1 + 120 = 120, c2: (80-60)*1 + 120 = 140
        XCTAssertEqual(c1.frame.origin.y, 320, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.x, 120, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 360, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 140, accuracy: acc)
    }

    // MARK: - Child Positioning: Row, packed

    func testRowPackedCenterTwoChildren() {
        let c1 = child(60, 80)
        let c2 = child(60, 40)
        let flex = layoutFlex(
            axis: .horizontal, spacing: 10, alignment: .center,
            containerSize: CGSize(width: 300, height: 200),
            children: [c1, c2]
        )
        // Group width = 60 + 60 + 10 = 130. Centered in 300 → starts at (300-130)/2 = 85
        // Cross: line.crossSize=80, container=200, center → offset = (200-80)*0.5 = 60
        // c1: crossOffset = (80-80)*0.5 + 60 = 60
        // c2: crossOffset = (80-40)*0.5 + 60 = 80
        XCTAssertEqual(c1.frame.origin.x, 85, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 60, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 155, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 80, accuracy: acc)
    }

    // MARK: - Spread Modes

    // Row, 200px wide, three 20px children. Used = 60, Free = 140.

    func testSpreadBetween() {
        let c1 = child(20, 20)
        let c2 = child(20, 20)
        let c3 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .between,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1, c2, c3]
        )
        // between: (0, 140/2 = 70)
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 90, accuracy: acc)  // 0 + 20 + 70
        XCTAssertEqual(c3.frame.origin.x, 180, accuracy: acc) // 90 + 20 + 70
    }

    func testSpreadAround() {
        let c1 = child(20, 20)
        let c2 = child(20, 20)
        let c3 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .around,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1, c2, c3]
        )
        // around: space = 140/3 ≈ 46.67, before = 23.33, between = 46.67
        let space = 140.0 / 3.0
        XCTAssertEqual(c1.frame.origin.x, space / 2, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, space / 2 + 20 + space, accuracy: acc)
        XCTAssertEqual(c3.frame.origin.x, space / 2 + 20 + space + 20 + space, accuracy: acc)
    }

    func testSpreadEven() {
        let c1 = child(20, 20)
        let c2 = child(20, 20)
        let c3 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .even,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1, c2, c3]
        )
        // even: space = 140/4 = 35
        XCTAssertEqual(c1.frame.origin.x, 35, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 35 + 20 + 35, accuracy: acc) // 90
        XCTAssertEqual(c3.frame.origin.x, 35 + 20 + 35 + 20 + 35, accuracy: acc) // 145
    }

    func testSpreadPacked() {
        let c1 = child(20, 20)
        let c2 = child(20, 20)
        let c3 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spacing: 5, alignment: .topLeft, spread: .packed,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1, c2, c3]
        )
        // packed, topLeft: starts at x=0
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 25, accuracy: acc)
        XCTAssertEqual(c3.frame.origin.x, 50, accuracy: acc)
    }

    // MARK: - Spread with Single Child

    func testSpreadBetweenSingleChild() {
        let c1 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .between,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1]
        )
        // between with 1 child: (0, 0) → child at 0
        XCTAssertEqual(c1.frame.origin.x, 0, accuracy: acc)
    }

    func testSpreadAroundSingleChild() {
        let c1 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .around,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1]
        )
        // around: space = 180/1 = 180, before = 90 → centered
        XCTAssertEqual(c1.frame.origin.x, 90, accuracy: acc)
    }

    func testSpreadEvenSingleChild() {
        let c1 = child(20, 20)
        let flex = layoutFlex(
            axis: .horizontal, spread: .even,
            containerSize: CGSize(width: 200, height: 50),
            children: [c1]
        )
        // even: space = 180/2 = 90 → child at 90
        XCTAssertEqual(c1.frame.origin.x, 90, accuracy: acc)
    }

    // MARK: - Fill Children in Flex

    func testSingleFillChildInRow() {
        let fb = fillBox(axis: .horizontal, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .horizontal,
            containerSize: CGSize(width: 200, height: 100),
            children: [fb]
        )
        // Single fill child with flex=1, normalizedFlex=max(1,1)=1 → gets all free space
        // No fixed children → freeSpace = 200, share = 200 * 1/1 = 200
        XCTAssertEqual(fb.frame.width, 200, accuracy: acc)
    }

    func testTwoEqualFillChildrenInRow() {
        let fb1 = fillBox(axis: .horizontal, intrinsicCross: 30)
        let fb2 = fillBox(axis: .horizontal, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .horizontal,
            containerSize: CGSize(width: 200, height: 100),
            children: [fb1, fb2]
        )
        // Each flex=1, totalFlex=2, each gets 200*1/2 = 100
        XCTAssertEqual(fb1.frame.width, 100, accuracy: acc)
        XCTAssertEqual(fb2.frame.width, 100, accuracy: acc)
    }

    func testFillChildrenUnequalFlex() {
        let fb1 = fillBox(weight: 2, axis: .horizontal, intrinsicCross: 30)
        let fb2 = fillBox(weight: 1, axis: .horizontal, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .horizontal,
            containerSize: CGSize(width: 300, height: 100),
            children: [fb1, fb2]
        )
        // totalFlex=3, fb1 gets 300*2/3 = 200, fb2 gets 300*1/3 = 100
        XCTAssertEqual(fb1.frame.width, 200, accuracy: acc)
        XCTAssertEqual(fb2.frame.width, 100, accuracy: acc)
    }

    func testFillChildHalfFractionAlone() {
        let fb = BoxView()
        fb.sizing = Frame(.fill(0.5), .hug())
        fb.addSubview(FixedSizeView(size: CGSize(width: 30, height: 30)))
        let flex = layoutFlex(
            axis: .horizontal,
            containerSize: CGSize(width: 200, height: 100),
            children: [fb]
        )
        // fill(0.5) → 200 * 0.5 = 100
        XCTAssertEqual(fb.frame.width, 100, accuracy: acc)
    }

    func testMixedFixedAndFillChildren() {
        let fixed = child(60, 30)
        let fb = fillBox(axis: .horizontal, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .horizontal,
            containerSize: CGSize(width: 200, height: 100),
            children: [fixed, fb]
        )
        // Fixed takes 60, fill gets remaining: 200 - 60 = 140
        XCTAssertEqual(fixed.frame.width, 60, accuracy: acc)
        XCTAssertEqual(fb.frame.width, 140, accuracy: acc)
    }

    func testFillChildPositionedAfterFixed() {
        let fixed = child(60, 30)
        let fb = fillBox(axis: .horizontal, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 100),
            children: [fixed, fb]
        )
        XCTAssertEqual(fixed.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(fb.frame.origin.x, 60, accuracy: acc)
    }

    // MARK: - Fill Children in Column

    func testSingleFillChildInColumn() {
        let fb = fillBox(axis: .vertical, intrinsicCross: 30)
        let flex = layoutFlex(
            axis: .vertical,
            containerSize: CGSize(width: 200, height: 400),
            children: [fb]
        )
        XCTAssertEqual(fb.frame.height, 400, accuracy: acc)
    }

    func testMixedFixedAndFillInColumn() {
        let header = child(200, 50)
        let body = fillBox(axis: .vertical, intrinsicCross: 100)
        let flex = layoutFlex(
            axis: .vertical,
            containerSize: CGSize(width: 200, height: 400),
            children: [header, body]
        )
        XCTAssertEqual(header.frame.height, 50, accuracy: acc)
        XCTAssertEqual(body.frame.height, 350, accuracy: acc)
    }

    // MARK: - Wrapping

    func testWrapThreeChildrenInRow() {
        // 200px row, three 80px children. First two fit (160 < 200), third wraps.
        let c1 = child(80, 30)
        let c2 = child(80, 30)
        let c3 = child(80, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft, wrap: true,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1, c2, c3]
        )
        // Line 1: c1, c2; Line 2: c3
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c3.frame.origin.y, 30, accuracy: acc) // Below first line
        XCTAssertEqual(c3.frame.origin.x, 0, accuracy: acc)  // Start of new line
    }

    func testWrapLineCrossSizeIsTallestChild() {
        let c1 = child(80, 30)
        let c2 = child(80, 60) // Taller
        let c3 = child(80, 20)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft, wrap: true,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1, c2, c3]
        )
        // Line 1: c1(30), c2(60) → cross size = 60. Line 2: c3 starts at y=60
        XCTAssertEqual(c3.frame.origin.y, 60, accuracy: acc)
    }

    func testWrapLineSpacing() {
        let c1 = child(80, 30)
        let c2 = child(80, 30)
        let c3 = child(80, 30)
        let flex = layoutFlex(
            axis: .horizontal, lineSpacing: 10, alignment: .topLeft, wrap: true,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1, c2, c3]
        )
        // Line 1 cross = 30. Line 2 starts at 30 + 10 = 40
        XCTAssertEqual(c3.frame.origin.y, 40, accuracy: acc)
    }

    func testWrapSizeThatFits() {
        let c1 = child(80, 30)
        let c2 = child(80, 30)
        let c3 = child(80, 30)
        let flex = FlexView()
        flex.flexAxis = .horizontal
        flex.flexWrap = true
        flex.flexLineSpacing = 10
        for c in [c1, c2, c3] { flex.addSubview(c) }
        let size = flex.sizeThatFits(CGSize(width: 200, height: 400))
        // Two lines: cross = 30 + 30 + 10 = 70, main = proposed = 200
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 70, accuracy: acc)
    }

    func testWrapSingleItemWiderThanExtent() {
        let c1 = child(50, 30)
        let c2 = child(250, 30) // Wider than 200px container
        let c3 = child(50, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft, wrap: true,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1, c2, c3]
        )
        // c1 fits on line 1. c2 doesn't fit with c1 → wraps to line 2.
        // c3 doesn't fit with c2 (250 > 200) → wraps to line 3.
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 30, accuracy: acc)
        XCTAssertEqual(c3.frame.origin.y, 60, accuracy: acc)
        // c2 still reports its full width (doesn't shrink)
        XCTAssertEqual(c2.frame.width, 250, accuracy: acc)
    }

    // MARK: - Cross-axis alignment within a line

    func testCrossAxisAlignmentCenter() {
        // Row with children of different heights — shorter child centered in line
        let tall = child(40, 80)
        let short = child(40, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .center,
            containerSize: CGSize(width: 200, height: 200),
            children: [tall, short]
        )
        // Cross: line.crossSize=80, container=200, center → offset = (200-80)*0.5 = 60
        // tall: (80-80)*0.5 + 60 = 60, short: (80-30)*0.5 + 60 = 85
        XCTAssertEqual(tall.frame.origin.y, 60, accuracy: acc)
        XCTAssertEqual(short.frame.origin.y, 85, accuracy: acc)
    }

    func testCrossAxisAlignmentTop() {
        let tall = child(40, 80)
        let short = child(40, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 200),
            children: [tall, short]
        )
        // crossAlignFactor = 0 → offset = (200-80)*0 = 0, both at y=0
        XCTAssertEqual(tall.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(short.frame.origin.y, 0, accuracy: acc)
    }

    func testCrossAxisAlignmentBottom() {
        let tall = child(40, 80)
        let short = child(40, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .bottomLeft,
            containerSize: CGSize(width: 200, height: 200),
            children: [tall, short]
        )
        // Cross: line.crossSize=80, container=200, bottom → offset = (200-80)*1 = 120
        // tall: (80-80)*1 + 120 = 120, short: (80-30)*1 + 120 = 170
        XCTAssertEqual(tall.frame.origin.y, 120, accuracy: acc)
        XCTAssertEqual(short.frame.origin.y, 170, accuracy: acc)
    }

    // MARK: - Column spread modes

    func testColumnSpreadBetween() {
        let c1 = child(40, 30)
        let c2 = child(40, 30)
        let c3 = child(40, 30)
        let flex = layoutFlex(
            axis: .vertical, spread: .between,
            containerSize: CGSize(width: 200, height: 300),
            children: [c1, c2, c3]
        )
        // Used = 90, free = 210, between = 210/2 = 105
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 135, accuracy: acc) // 0 + 30 + 105
        XCTAssertEqual(c3.frame.origin.y, 270, accuracy: acc) // 135 + 30 + 105
    }

    func testColumnSpreadEven() {
        let c1 = child(40, 30)
        let c2 = child(40, 30)
        let flex = layoutFlex(
            axis: .vertical, spread: .even,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1, c2]
        )
        // Used = 60, free = 140, space = 140/3 ≈ 46.67
        let space = 140.0 / 3.0
        XCTAssertEqual(c1.frame.origin.y, space, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, space + 30 + space, accuracy: acc)
    }

    // MARK: - Edge Cases

    func testZeroChildrenLayout() {
        let flex = layoutFlex(axis: .horizontal, children: [])
        // Should not crash
        XCTAssertEqual(flex.subviews.count, 0)
    }

    func testSingleChildNoSpread() {
        let c1 = child(60, 40)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .center,
            containerSize: CGSize(width: 200, height: 100),
            children: [c1]
        )
        // Packed center: x = (200-60)/2 = 70
        XCTAssertEqual(c1.frame.origin.x, 70, accuracy: acc)
    }

    func testChildSizePreserved() {
        let c1 = child(80, 40)
        let c2 = child(60, 50)
        let flex = layoutFlex(axis: .vertical, children: [c1, c2])
        XCTAssertEqual(c1.frame.width, 80, accuracy: acc)
        XCTAssertEqual(c1.frame.height, 40, accuracy: acc)
        XCTAssertEqual(c2.frame.width, 60, accuracy: acc)
        XCTAssertEqual(c2.frame.height, 50, accuracy: acc)
    }

    func testSpacingWithTwoChildren() {
        let c1 = child(40, 40)
        let c2 = child(40, 40)
        let flex = layoutFlex(
            axis: .vertical, spacing: 20, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 400),
            children: [c1, c2]
        )
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 60, accuracy: acc) // 40 + 20
    }

    // MARK: - Fill Min/Max Clamping

    func testFlexMinClamped() {
        // Flex with min=120 in a 200px row with a 100px fixed child.
        // Free space = 100, share = 100, but min = 120 → clamped to 120.
        let fixed = child(100, 30)
        let fb = BoxView()
        fb.sizing = Frame(.flex(1, min: 120), .hug())
        fb.addSubview(FixedSizeView(size: CGSize(width: 30, height: 30)))
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 100),
            children: [fixed, fb]
        )
        XCTAssertEqual(fb.frame.width, 120, accuracy: acc)
    }

    func testFlexMaxClamped() {
        // Flex with max=80 in a 200px row (no other children).
        // Free space = 200, but max = 80 → clamped to 80.
        let fb = BoxView()
        fb.sizing = Frame(.flex(1, max: 80), .hug())
        fb.addSubview(FixedSizeView(size: CGSize(width: 30, height: 30)))
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft,
            containerSize: CGSize(width: 200, height: 100),
            children: [fb]
        )
        XCTAssertEqual(fb.frame.width, 80, accuracy: acc)
    }

    func testFlexMinMaxBothApplied() {
        // Two flex children in 300px. Each gets 150, min=100 max=120 → clamped to 120.
        let fb1 = BoxView()
        fb1.sizing = Frame(.flex(1, min: 100, max: 120), .hug())
        fb1.addSubview(FixedSizeView(size: CGSize(width: 30, height: 30)))
        let fb2 = BoxView()
        fb2.sizing = Frame(.flex(1, min: 100, max: 120), .hug())
        fb2.addSubview(FixedSizeView(size: CGSize(width: 30, height: 30)))
        let flex = layoutFlex(
            axis: .horizontal, alignment: .topLeft,
            containerSize: CGSize(width: 300, height: 100),
            children: [fb1, fb2]
        )
        XCTAssertEqual(fb1.frame.width, 120, accuracy: acc)
        XCTAssertEqual(fb2.frame.width, 120, accuracy: acc)
    }

    // MARK: - Single-line Cross Alignment Against Container

    func testSingleLineCrossAlignCenter() {
        // Single row in 200px tall container, tallest child = 40px.
        // Center alignment → child centered in full 200px, not in 40px line.
        let c1 = child(60, 40)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .center,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1]
        )
        // (200 - 40) * 0.5 = 80
        XCTAssertEqual(c1.frame.origin.y, 80, accuracy: acc)
    }

    func testSingleLineCrossAlignBottom() {
        let c1 = child(60, 40)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .bottomLeft,
            containerSize: CGSize(width: 200, height: 200),
            children: [c1]
        )
        // (200 - 40) * 1.0 = 160
        XCTAssertEqual(c1.frame.origin.y, 160, accuracy: acc)
    }

    // MARK: - Multi-line Stacks From Top

    func testMultiLineStacksFromTop() {
        // Wrapped row: lines should stack from y=0, not be centered.
        let c1 = child(120, 30)
        let c2 = child(120, 30)
        let flex = layoutFlex(
            axis: .horizontal, alignment: .center, wrap: true,
            containerSize: CGSize(width: 200, height: 400),
            children: [c1, c2]
        )
        // Line 1 at y=0, line 2 at y=30 (stacked from top)
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 30, accuracy: acc)
    }
}

#endif
