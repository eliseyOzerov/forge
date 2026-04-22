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
final class ComposedLayoutTests: XCTestCase {

    private let acc: CGFloat = 0.5

    // MARK: - Helpers

    private func child(_ w: CGFloat, _ h: CGFloat) -> FixedSizeView {
        FixedSizeView(size: CGSize(width: w, height: h))
    }

    /// Create a BoxView with given sizing, padding, alignment, and children.
    private func makeBox(
        sizing: Frame = .hug,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        children: [UIView] = []
    ) -> BoxView {
        let box = BoxView()
        box.sizing = sizing
        box.padding = padding
        box.alignment = alignment
        for child in children { box.addSubview(child) }
        return box
    }

    /// Create a FlexView (Column or Row) with given config and children.
    private func makeFlex(
        axis: NSLayoutConstraint.Axis = .vertical,
        spacing: Double = 0,
        alignment: Alignment = .center,
        spread: Spread = .packed,
        children: [UIView]
    ) -> FlexView {
        let flex = FlexView()
        flex.flexAxis = axis
        flex.flexSpacing = spacing
        flex.flexAlignment = alignment
        flex.flexSpread = spread
        for child in children { flex.addSubview(child) }
        return flex
    }

    /// Set frame and trigger layout on a view.
    private func layout(_ view: UIView, size: CGSize) {
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubviews()
        // Also layout children that are themselves layout containers
        for sub in view.subviews {
            if sub is BoxView || sub is FlexView {
                sub.layoutSubviews()
            }
        }
    }

    // MARK: - Box inside Flex

    func testHugBoxInColumn() {
        let innerChild = child(60, 40)
        let box = makeBox(sizing: .hug, children: [innerChild])
        let column = makeFlex(axis: .vertical, children: [box])

        layout(column, size: CGSize(width: 200, height: 400))

        // Box hugs to child: 60x40
        XCTAssertEqual(box.frame.width, 60, accuracy: acc)
        XCTAssertEqual(box.frame.height, 40, accuracy: acc)
    }

    func testFillWidthBoxInColumn() {
        let innerChild = child(60, 40)
        let box = makeBox(sizing: .fillWidth, children: [innerChild])
        let column = makeFlex(axis: .vertical, children: [box])

        layout(column, size: CGSize(width: 200, height: 400))

        // Box fills width of column (200), hugs height to child (40)
        XCTAssertEqual(box.frame.width, 200, accuracy: acc)
        XCTAssertEqual(box.frame.height, 40, accuracy: acc)
    }

    func testFixedBoxInRow() {
        let box = makeBox(sizing: .fixed(80, 60))
        let row = makeFlex(axis: .horizontal, children: [box])

        layout(row, size: CGSize(width: 300, height: 200))

        XCTAssertEqual(box.frame.width, 80, accuracy: acc)
        XCTAssertEqual(box.frame.height, 60, accuracy: acc)
    }

    func testTwoFixedBoxesInRow() {
        let box1 = makeBox(sizing: .fixed(80, 60))
        let box2 = makeBox(sizing: .fixed(50, 40))
        let row = makeFlex(axis: .horizontal, spacing: 10, alignment: .topLeft, children: [box1, box2])

        layout(row, size: CGSize(width: 300, height: 200))

        XCTAssertEqual(box1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(box2.frame.origin.x, 90, accuracy: acc) // 80 + 10
    }

    // MARK: - Flex inside Box

    func testColumnInsideFillBox() {
        let c1 = child(60, 30)
        let c2 = child(60, 30)
        let column = makeFlex(axis: .vertical, spacing: 10, alignment: .topLeft, children: [c1, c2])
        let box = makeBox(sizing: .fixed(200, 200), alignment: .topLeft, children: [column])

        layout(box, size: CGSize(width: 200, height: 200))

        // Column is a child of box. Box proposes 200x200, column sizes to content.
        // Column sizeThatFits: w=60, h=30+30+10=70
        XCTAssertEqual(column.frame.width, 60, accuracy: acc)
        XCTAssertEqual(column.frame.height, 70, accuracy: acc)
        // Children within column
        XCTAssertEqual(c1.frame.origin.y, 0, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 40, accuracy: acc)
    }

    func testRowInsideHugBox() {
        let c1 = child(40, 30)
        let c2 = child(60, 30)
        let row = makeFlex(axis: .horizontal, spacing: 5, children: [c1, c2])
        let box = makeBox(sizing: .hug, children: [row])

        let size = box.sizeThatFits(CGSize(width: 400, height: 400))

        // Row: w=40+60+5=105, h=30. Box hugs to row.
        XCTAssertEqual(size.width, 105, accuracy: acc)
        XCTAssertEqual(size.height, 30, accuracy: acc)
    }

    // MARK: - Nested Flex

    func testRowInsideColumn() {
        let c1 = child(40, 20)
        let c2 = child(40, 20)
        let row = makeFlex(axis: .horizontal, spacing: 10, children: [c1, c2])

        let c3 = child(60, 30)
        let column = makeFlex(axis: .vertical, spacing: 5, alignment: .topLeft, children: [row, c3])

        layout(column, size: CGSize(width: 200, height: 400))

        // Row: w=40+40+10=90, h=20
        XCTAssertEqual(row.frame.width, 90, accuracy: acc)
        XCTAssertEqual(row.frame.height, 20, accuracy: acc)
        XCTAssertEqual(row.frame.origin.y, 0, accuracy: acc)
        // c3 below row
        XCTAssertEqual(c3.frame.origin.y, 25, accuracy: acc) // 20 + 5
    }

    func testColumnInsideRow() {
        let c1 = child(40, 20)
        let c2 = child(40, 20)
        let column = makeFlex(axis: .vertical, spacing: 5, children: [c1, c2])

        let c3 = child(60, 30)
        let row = makeFlex(axis: .horizontal, spacing: 10, alignment: .topLeft, children: [column, c3])

        layout(row, size: CGSize(width: 400, height: 200))

        // Column: w=40, h=20+20+5=45
        XCTAssertEqual(column.frame.width, 40, accuracy: acc)
        XCTAssertEqual(column.frame.height, 45, accuracy: acc)
        XCTAssertEqual(column.frame.origin.x, 0, accuracy: acc)
        // c3 right of column
        XCTAssertEqual(c3.frame.origin.x, 50, accuracy: acc) // 40 + 10
    }

    // MARK: - Complex Compositions

    func testRowOfEqualWidthFlexBoxes() {
        let b1 = makeBox(sizing: Frame(.flex(), .hug()), children: [child(10, 30)])
        let b2 = makeBox(sizing: Frame(.flex(), .hug()), children: [child(10, 30)])
        let b3 = makeBox(sizing: Frame(.flex(), .hug()), children: [child(10, 30)])
        let row = makeFlex(axis: .horizontal, alignment: .topLeft, children: [b1, b2, b3])

        layout(row, size: CGSize(width: 300, height: 100))

        // Three flex boxes, each weight=1, total=3 → each gets 100
        XCTAssertEqual(b1.frame.width, 100, accuracy: acc)
        XCTAssertEqual(b2.frame.width, 100, accuracy: acc)
        XCTAssertEqual(b3.frame.width, 100, accuracy: acc)
        XCTAssertEqual(b1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(b2.frame.origin.x, 100, accuracy: acc)
        XCTAssertEqual(b3.frame.origin.x, 200, accuracy: acc)
    }

    func testColumnWithHeaderAndFlexBody() {
        let header = makeBox(sizing: Frame(.fill(), .fix(50)), children: [child(100, 50)])
        let body = makeBox(sizing: Frame(.fill(), .flex()), children: [child(100, 100)])
        let column = makeFlex(axis: .vertical, alignment: .topLeft, children: [header, body])

        layout(column, size: CGSize(width: 300, height: 400))

        // Header: fixed 50h
        XCTAssertEqual(header.frame.height, 50, accuracy: acc)
        XCTAssertEqual(header.frame.origin.y, 0, accuracy: acc)
        // Body: fills remaining 350h
        XCTAssertEqual(body.frame.height, 350, accuracy: acc)
        XCTAssertEqual(body.frame.origin.y, 50, accuracy: acc)
    }

    func testPaddedBoxWithCenteredColumn() {
        let c1 = child(60, 30)
        let c2 = child(60, 30)
        let column = makeFlex(axis: .vertical, spacing: 10, children: [c1, c2])
        let box = makeBox(sizing: .fixed(200, 200), padding: .all(20), alignment: .center, children: [column])

        layout(box, size: CGSize(width: 200, height: 200))

        // Inset: 160x160. Column: w=60, h=70. Centered in inset.
        // Column origin: x = 20 + (160-60)/2 = 70, y = 20 + (160-70)/2 = 65
        XCTAssertEqual(column.frame.origin.x, 70, accuracy: acc)
        XCTAssertEqual(column.frame.origin.y, 65, accuracy: acc)
    }

    func testBoxWithPaddingContainingRowWithSpacing() {
        let c1 = child(40, 30)
        let c2 = child(40, 30)
        let c3 = child(40, 30)
        let row = makeFlex(axis: .horizontal, spacing: 10, children: [c1, c2, c3])
        let box = makeBox(sizing: .hug, padding: .all(15), children: [row])

        let size = box.sizeThatFits(CGSize(width: 500, height: 500))

        // Row: w=40*3 + 10*2 = 140, h=30
        // Box: w=140 + 30 = 170, h=30 + 30 = 60
        XCTAssertEqual(size.width, 170, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    // MARK: - Fill Propagation

    func testFillBoxInsideFillBoxInsideFlex() {
        let innerContent = child(30, 30)
        let innerBox = makeBox(sizing: .fill, children: [innerContent])
        let outerBox = makeBox(sizing: Frame(.flex(), .hug()), children: [innerBox])
        let row = makeFlex(axis: .horizontal, alignment: .topLeft, children: [outerBox])

        layout(row, size: CGSize(width: 300, height: 200))

        // outerBox is fill-width in row → 300
        XCTAssertEqual(outerBox.frame.width, 300, accuracy: acc)
        // innerBox is fill inside outerBox → also 300
        outerBox.layoutSubviews()
        XCTAssertEqual(innerBox.frame.width, 300, accuracy: acc)
    }

    func testColumnWithMixedSizingChildren() {
        // Header (fixed), body (flex), footer (fixed)
        let header = makeBox(sizing: Frame(.fill(), .fix(40)))
        let body = makeBox(sizing: Frame(.fill(), .flex()))
        let footer = makeBox(sizing: Frame(.fill(), .fix(60)))
        let column = makeFlex(axis: .vertical, alignment: .topLeft, children: [header, body, footer])

        layout(column, size: CGSize(width: 300, height: 500))

        XCTAssertEqual(header.frame.height, 40, accuracy: acc)
        XCTAssertEqual(header.frame.origin.y, 0, accuracy: acc)
        // Body fills: 500 - 40 - 60 = 400
        XCTAssertEqual(body.frame.height, 400, accuracy: acc)
        XCTAssertEqual(body.frame.origin.y, 40, accuracy: acc)
        XCTAssertEqual(footer.frame.height, 60, accuracy: acc)
        XCTAssertEqual(footer.frame.origin.y, 440, accuracy: acc)
    }

    func testRowWithSpacingAndPaddedBoxChildren() {
        // Each box has 10px padding containing a 40x30 child
        let b1 = makeBox(sizing: .hug, padding: .all(10), children: [child(40, 30)])
        let b2 = makeBox(sizing: .hug, padding: .all(10), children: [child(40, 30)])
        let row = makeFlex(axis: .horizontal, spacing: 20, alignment: .topLeft, children: [b1, b2])

        layout(row, size: CGSize(width: 400, height: 200))

        // Each box: 40+20=60 wide, 30+20=50 tall
        XCTAssertEqual(b1.frame.width, 60, accuracy: acc)
        XCTAssertEqual(b1.frame.height, 50, accuracy: acc)
        XCTAssertEqual(b1.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(b2.frame.origin.x, 80, accuracy: acc) // 60 + 20
    }

    // MARK: - sizeThatFits Composition

    func testSizeThatFitsColumnOfBoxes() {
        let b1 = makeBox(sizing: .hug, padding: .all(5), children: [child(40, 20)])
        let b2 = makeBox(sizing: .hug, children: [child(60, 30)])
        let column = makeFlex(axis: .vertical, spacing: 10, children: [b1, b2])

        let size = column.sizeThatFits(CGSize(width: 300, height: 300))

        // b1: 50x30, b2: 60x30
        // Column: w=max(50,60)=60, h=30+30+10=70
        XCTAssertEqual(size.width, 60, accuracy: acc)
        XCTAssertEqual(size.height, 70, accuracy: acc)
    }

    func testSizeThatFitsNestedRowInColumn() {
        let c1 = child(30, 20)
        let c2 = child(30, 20)
        let row = makeFlex(axis: .horizontal, spacing: 5, children: [c1, c2])
        let c3 = child(40, 25)
        let column = makeFlex(axis: .vertical, spacing: 8, children: [row, c3])

        let size = column.sizeThatFits(CGSize(width: 300, height: 300))

        // Row: w=30+30+5=65, h=20
        // Column: w=max(65,40)=65, h=20+25+8=53
        XCTAssertEqual(size.width, 65, accuracy: acc)
        XCTAssertEqual(size.height, 53, accuracy: acc)
    }
}

#endif
