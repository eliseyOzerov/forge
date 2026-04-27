#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

/// A UIView that reports a fixed intrinsic size for testing layout.
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
final class BoxLayoutTests: XCTestCase {

    private let acc: CGFloat = 0.5

    // MARK: - Helpers

    /// Create a BoxView, add children, set frame, trigger layout, return the box.
    private func layoutBox(
        sizing: Frame = .fit,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        shape: AnyShape? = nil,
        containerSize: CGSize = CGSize(width: 200, height: 200),
        children: [UIView] = []
    ) -> BoxView {
        let box = BoxView()
        box.sizing = sizing
        box.padding = padding
        box.alignment = alignment
        box.clip = clip
        box.shape = shape
        for child in children { box.addSubview(child) }
        box.frame = CGRect(origin: .zero, size: containerSize)
        box.layoutSubviews()
        return box
    }

    private func child(_ w: CGFloat, _ h: CGFloat) -> FixedSizeView {
        FixedSizeView(size: CGSize(width: w, height: h))
    }

    // MARK: - sizeThatFits: Hug

    func testSizeThatFitsHugNoChildren() {
        let box = BoxView()
        box.sizing = .fit
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 0, accuracy: acc)
        XCTAssertEqual(size.height, 0, accuracy: acc)
    }

    func testSizeThatFitsHugNoChildrenWithPadding() {
        let box = BoxView()
        box.sizing = .fit
        box.padding = .all(20)
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 40, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    func testSizeThatFitsHugOneChild() {
        let box = BoxView()
        box.sizing = .fit
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testSizeThatFitsHugOneChildWithPadding() {
        let box = BoxView()
        box.sizing = .fit
        box.padding = Padding(top: 10, bottom: 20, leading: 5, trailing: 15)
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 80 + 5 + 15, accuracy: acc)
        XCTAssertEqual(size.height, 60 + 10 + 20, accuracy: acc)
    }

    func testSizeThatFitsHugMultipleChildrenTakesMax() {
        let box = BoxView()
        box.sizing = .fit
        box.addSubview(child(80, 40))
        box.addSubview(child(50, 90))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 90, accuracy: acc)
    }

    // MARK: - sizeThatFits: Fix

    func testSizeThatFitsFixIgnoresChildren() {
        let box = BoxView()
        box.sizing = .fixed(120, 80)
        box.addSubview(child(200, 200))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 120, accuracy: acc)
        XCTAssertEqual(size.height, 80, accuracy: acc)
    }

    func testSizeThatFitsFixNoChildren() {
        let box = BoxView()
        box.sizing = .fixed(50, 50)
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 50, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    // MARK: - sizeThatFits: Fill

    func testSizeThatFitsFillReturnsProposed() {
        let box = BoxView()
        box.sizing = .fill()
        let size = box.sizeThatFits(CGSize(width: 300, height: 250))
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 250, accuracy: acc)
    }

    // MARK: - sizeThatFits: Fix (additional)

    func testSizeThatFitsFixIgnoresProposed() {
        let box = BoxView()
        box.sizing = .fixed(80, 60)
        let a = box.sizeThatFits(CGSize(width: 300, height: 300))
        let b = box.sizeThatFits(CGSize(width: 50, height: 50))
        XCTAssertEqual(a.width, 80, accuracy: acc)
        XCTAssertEqual(b.width, 80, accuracy: acc)
    }

    func testSizeThatFitsFixIgnoresPadding() {
        let box = BoxView()
        box.sizing = .fixed(100, 80)
        box.padding = .all(20)
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        // Fix returns the outer size — padding eats into it, doesn't add to it.
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 80, accuracy: acc)
    }

    // MARK: - sizeThatFits: Fill (additional)

    func testSizeThatFitsFillIgnoresChildren() {
        let box = BoxView()
        box.sizing = .fill()
        box.addSubview(child(500, 500))
        let size = box.sizeThatFits(CGSize(width: 200, height: 200))
        XCTAssertEqual(size.width, 200, accuracy: acc)
        XCTAssertEqual(size.height, 200, accuracy: acc)
    }

    func testSizeThatFitsFillFraction() {
        let box = BoxView()
        box.sizing = Frame(.fill(0.5), .fill(0.25))
        let size = box.sizeThatFits(CGSize(width: 200, height: 400))
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    func testSizeThatFitsFillWithMin() {
        let box = BoxView()
        box.sizing = Frame(.fill(1, min: 150), .fill(1, min: 150))
        let size = box.sizeThatFits(CGSize(width: 100, height: 100))
        XCTAssertEqual(size.width, 150, accuracy: acc)
        XCTAssertEqual(size.height, 150, accuracy: acc)
    }

    func testSizeThatFitsFillWithMax() {
        let box = BoxView()
        box.sizing = Frame(.fill(1, max: 150), .fill(1, max: 150))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 150, accuracy: acc)
        XCTAssertEqual(size.height, 150, accuracy: acc)
    }

    // MARK: - sizeThatFits: Hug (additional)

    func testSizeThatFitsHugWithMin() {
        let box = BoxView()
        box.sizing = Frame(.fit(min: 100), .fit(min: 80))
        box.addSubview(child(40, 30))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 80, accuracy: acc)
    }

    func testSizeThatFitsHugWithMinNoEffect() {
        let box = BoxView()
        box.sizing = Frame(.fit(min: 50), .fit(min: 50))
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        // Content already exceeds min.
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testSizeThatFitsHugWithMax() {
        let box = BoxView()
        box.sizing = Frame(.fit(max: 60), .fit(max: 40))
        box.addSubview(child(100, 80))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 60, accuracy: acc)
        XCTAssertEqual(size.height, 40, accuracy: acc)
    }

    func testSizeThatFitsHugWithMinAndMax() {
        let box = BoxView()
        box.sizing = Frame(.fit(min: 50, max: 90), .fit(min: 50, max: 90))
        box.addSubview(child(30, 30))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        // Content 30 clamped to min 50.
        XCTAssertEqual(size.width, 50, accuracy: acc)
        XCTAssertEqual(size.height, 50, accuracy: acc)
    }

    // MARK: - sizeThatFits: Fit (intrinsic)

    func testSizeThatFitsFitReturnsIntrinsic() {
        let box = BoxView()
        box.sizing = Frame(.fit(), .fit())
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testSizeThatFitsFitWithPadding() {
        let box = BoxView()
        box.sizing = Frame(.fit(), .fit())
        box.padding = .all(10)
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 80, accuracy: acc)
    }

    func testSizeThatFitsFitZeroProposalReturnsIntrinsic() {
        let box = BoxView()
        box.sizing = Frame(.fit(), .fit())
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 0, height: 0))
        XCTAssertEqual(size.width, 80, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testSizeThatFitsFitWithMin() {
        let box = BoxView()
        box.sizing = Frame(.fit(min: 100), .fit(min: 100))
        box.addSubview(child(40, 30))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 100, accuracy: acc)
    }

    // MARK: - sizeThatFits: Mixed (additional)

    func testSizeThatFitsMixedWidthFixHeightHug() {
        let box = BoxView()
        box.sizing = Frame(.fix(100), .fit())
        box.addSubview(child(80, 60))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 100, accuracy: acc)
        XCTAssertEqual(size.height, 60, accuracy: acc)
    }

    func testSizeThatFitsMixedWidthFillHeightFix() {
        let box = BoxView()
        box.sizing = Frame(.fill(), .fix(75))
        let size = box.sizeThatFits(CGSize(width: 300, height: 300))
        XCTAssertEqual(size.width, 300, accuracy: acc)
        XCTAssertEqual(size.height, 75, accuracy: acc)
    }

    // MARK: - Alignment Positioning

    func testAlignmentCenter() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .center, children: [c])
        XCTAssertEqual(c.frame.origin.x, 75, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 75, accuracy: acc)
    }

    func testAlignmentTopLeft() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .topLeft, children: [c])
        XCTAssertEqual(c.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 0, accuracy: acc)
    }

    func testAlignmentTopRight() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .topRight, children: [c])
        XCTAssertEqual(c.frame.origin.x, 150, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 0, accuracy: acc)
    }

    func testAlignmentBottomLeft() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .bottomLeft, children: [c])
        XCTAssertEqual(c.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 150, accuracy: acc)
    }

    func testAlignmentBottomRight() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .bottomRight, children: [c])
        XCTAssertEqual(c.frame.origin.x, 150, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 150, accuracy: acc)
    }

    func testAlignmentTopCenter() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .topCenter, children: [c])
        XCTAssertEqual(c.frame.origin.x, 75, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 0, accuracy: acc)
    }

    func testAlignmentBottomCenter() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .bottomCenter, children: [c])
        XCTAssertEqual(c.frame.origin.x, 75, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 150, accuracy: acc)
    }

    func testAlignmentCenterLeft() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .centerLeft, children: [c])
        XCTAssertEqual(c.frame.origin.x, 0, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 75, accuracy: acc)
    }

    func testAlignmentCenterRight() {
        let c = child(50, 50)
        let box = layoutBox(sizing: .fixed(200, 200), alignment: .centerRight, children: [c])
        XCTAssertEqual(c.frame.origin.x, 150, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 75, accuracy: acc)
    }

    // MARK: - Padding

    func testPaddingOffsetsChildPosition() {
        let c = child(50, 50)
        let box = layoutBox(
            sizing: .fixed(200, 200),
            padding: Padding(top: 30, bottom: 10, leading: 20, trailing: 10),
            alignment: .topLeft,
            children: [c]
        )
        XCTAssertEqual(c.frame.origin.x, 20, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 30, accuracy: acc)
    }

    func testPaddingCenterAlignment() {
        // 200x200 box, padding 20 all → inset is 160x160, child 40x40 → centered in inset
        let c = child(40, 40)
        let box = layoutBox(
            sizing: .fixed(200, 200),
            padding: .all(20),
            alignment: .center,
            children: [c]
        )
        // Inset starts at (20, 20), size 160x160. Child centered: 20 + (160-40)/2 = 80
        XCTAssertEqual(c.frame.origin.x, 80, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 80, accuracy: acc)
    }

    func testPaddingBottomRightAlignment() {
        let c = child(40, 40)
        let box = layoutBox(
            sizing: .fixed(200, 200),
            padding: Padding(top: 10, bottom: 20, leading: 10, trailing: 30),
            alignment: .bottomRight,
            children: [c]
        )
        // Inset: x=10, y=10, w=200-10-30=160, h=200-10-20=170
        // bottomRight: x = 10 + 160 - 40 = 130, y = 10 + 170 - 40 = 140
        XCTAssertEqual(c.frame.origin.x, 130, accuracy: acc)
        XCTAssertEqual(c.frame.origin.y, 140, accuracy: acc)
    }

    // MARK: - Fill Children

    func testFillChildExpandsToInset() {
        let fillChild = BoxView()
        fillChild.sizing = .fill()
        // Give the fill child a small intrinsic size so we can verify it expands
        let box = layoutBox(
            sizing: .fixed(200, 200),
            padding: .all(10),
            alignment: .center,
            children: [fillChild]
        )
        // Inset: 180x180
        XCTAssertEqual(fillChild.frame.width, 180, accuracy: acc)
        XCTAssertEqual(fillChild.frame.height, 180, accuracy: acc)
    }

    func testFillChildWidthOnly() {
        let fillChild = BoxView()
        fillChild.sizing = Frame(.fill(), .fit())
        fillChild.addSubview(child(30, 50))
        let box = layoutBox(
            sizing: .fixed(200, 200),
            alignment: .center,
            children: [fillChild]
        )
        XCTAssertEqual(fillChild.frame.width, 200, accuracy: acc)
        // Height should be intrinsic (from child)
        // BoxView.sizeThatFits with hug height → child height
        XCTAssertEqual(fillChild.frame.height, 50, accuracy: acc)
    }

    // MARK: - Multiple Children (Overlay)

    func testOverlayBothChildrenPositioned() {
        let c1 = child(100, 100)
        let c2 = child(50, 50)
        let box = layoutBox(
            sizing: .fixed(200, 200),
            alignment: .center,
            children: [c1, c2]
        )
        // Both centered
        XCTAssertEqual(c1.frame.origin.x, 50, accuracy: acc)
        XCTAssertEqual(c1.frame.origin.y, 50, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.x, 75, accuracy: acc)
        XCTAssertEqual(c2.frame.origin.y, 75, accuracy: acc)
    }

    func testOverlayChildSizes() {
        let c1 = child(100, 100)
        let c2 = child(50, 50)
        let box = layoutBox(
            sizing: .fixed(200, 200),
            alignment: .center,
            children: [c1, c2]
        )
        XCTAssertEqual(c1.frame.width, 100, accuracy: acc)
        XCTAssertEqual(c1.frame.height, 100, accuracy: acc)
        XCTAssertEqual(c2.frame.width, 50, accuracy: acc)
        XCTAssertEqual(c2.frame.height, 50, accuracy: acc)
    }

    // MARK: - Shape Clipping

    func testClipTrueWithShapeSetsLayerMask() {
        let box = layoutBox(clip: true, shape: .circle())
        XCTAssertNotNil(box.layer.mask)
    }

    func testClipFalseNoLayerMask() {
        let box = layoutBox(clip: false, shape: .circle())
        XCTAssertNil(box.layer.mask)
    }

    func testClipTrueNoShapeUsesClipsToBounds() {
        let box = layoutBox(clip: true, shape: nil)
        XCTAssertNil(box.layer.mask, "No shape means no CAShapeLayer mask")
        XCTAssertTrue(box.clipsToBounds, "clip=true without shape falls back to clipsToBounds")
    }

    // MARK: - Intrinsic Content Size

    func testIntrinsicContentSizeFix() {
        let box = BoxView()
        box.sizing = .fixed(120, 80)
        XCTAssertEqual(box.intrinsicContentSize.width, 120, accuracy: acc)
        XCTAssertEqual(box.intrinsicContentSize.height, 80, accuracy: acc)
    }

    func testIntrinsicContentSizeHug() {
        let box = BoxView()
        box.sizing = .fit
        XCTAssertEqual(box.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        XCTAssertEqual(box.intrinsicContentSize.height, UIView.noIntrinsicMetric)
    }

    func testIntrinsicContentSizeFill() {
        let box = BoxView()
        box.sizing = .fill()
        XCTAssertEqual(box.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        XCTAssertEqual(box.intrinsicContentSize.height, UIView.noIntrinsicMetric)
    }


    // MARK: - Subview Ordering

    func testSubviewsExcludesInternalViews() {
        let box = BoxView()
        let c = child(50, 50)
        box.addSubview(c)
        XCTAssertEqual(box.subviews.count, 1, "subviews should only include content children")
        XCTAssertTrue(box.subviews.first === c)
    }

    func testInsertSubviewAtIndexRespectsInternalViews() {
        let box = BoxView()
        let c1 = child(50, 50)
        let c2 = child(30, 30)
        box.addSubview(c1)
        box.insertSubview(c2, at: 0)
        // c2 should be before c1 in content order
        XCTAssertTrue(box.subviews.first === c2, "insertSubview at 0 should put child first in content order")
        XCTAssertTrue(box.subviews.last === c1)
    }

    // MARK: - Clipping Modes

    func testClipTrueWithShapeSetsShapeMask() {
        let box = layoutBox(clip: true, shape: .circle())
        XCTAssertNotNil(box.layer.mask, "clip=true with shape should set a CAShapeLayer mask")
        XCTAssertFalse(box.clipsToBounds, "Shape mask handles clipping, clipsToBounds not needed")
    }

    func testClipFalseNoMaskNoClipsToBounds() {
        let box = layoutBox(clip: false, shape: .circle())
        XCTAssertNil(box.layer.mask)
        XCTAssertFalse(box.clipsToBounds)
    }

    func testClipFalseDisablesClipping() {
        let box = layoutBox(clip: false, shape: .circle())
        XCTAssertNil(box.layer.mask, "clip false should suppress shape mask")
        XCTAssertFalse(box.clipsToBounds, "clip false should not clip")
    }

    func testShapeMaskCachedAcrossLayouts() {
        let box = layoutBox(clip: true, shape: .circle(), containerSize: CGSize(width: 100, height: 100))
        let firstMask = box.layer.mask
        XCTAssertNotNil(firstMask)
        // Trigger another layout with same bounds
        box.layoutSubviews()
        XCTAssertTrue(box.layer.mask === firstMask, "Mask should be reused when shape and bounds are unchanged")
    }

    func testShapeMaskRebuiltOnBoundsChange() {
        let box = layoutBox(clip: true, shape: .circle(), containerSize: CGSize(width: 100, height: 100))
        let firstMask = box.layer.mask
        // Change bounds and re-layout
        box.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        box.layoutSubviews()
        XCTAssertFalse(box.layer.mask === firstMask, "Mask should be rebuilt when bounds change")
    }

}

#endif
