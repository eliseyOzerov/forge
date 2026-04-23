#if canImport(UIKit)
import UIKit
import XCTest
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
final class ScrollTests: XCTestCase {

    private func child(_ w: CGFloat, _ h: CGFloat) -> FixedSizeView {
        FixedSizeView(size: CGSize(width: w, height: h))
    }

    private func host(_ style: ScrollableStyle = ScrollableStyle()) -> ScrollableHostView {
        let h = ScrollableHostView()
        h.configure(style)
        return h
    }

    private func scrollView(of host: ScrollableHostView) -> UIScrollView? {
        Mirror(reflecting: host).children
            .first { $0.label == "scrollView" }?.value as? UIScrollView
    }

    // MARK: - Subview Routing

    func testChildRoutedIntoScrollView() {
        let h = host()
        let c = child(50, 50)
        h.addSubview(c)
        XCTAssertTrue(c.superview is UIScrollView)
    }

    func testSubviewsReportsScrollViewChildren() {
        let h = host()
        let c = child(50, 50)
        h.addSubview(c)
        XCTAssertEqual(h.subviews.count, 1)
        XCTAssertTrue(h.subviews.first === c)
    }

    // MARK: - Content Size

    func testContentSizeMatchesChild() {
        let h = host()
        let c = child(300, 400)
        h.addSubview(c)
        h.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        h.layoutSubviews()

        let sv = scrollView(of: h)
        XCTAssertNotNil(sv)
        XCTAssertEqual(sv!.contentSize.width, 300, accuracy: 0.5)
        XCTAssertEqual(sv!.contentSize.height, 400, accuracy: 0.5)
    }

    // MARK: - Configuration

    func testConfigureUpdatesScrollViewProperties() {
        var style = ScrollableStyle()
        style.bounces = false
        style.scrollbar = true
        style.enabled = false
        let h = host(style)

        let sv = scrollView(of: h)
        XCTAssertNotNil(sv)
        XCTAssertFalse(sv!.bounces)
        XCTAssertFalse(sv!.isScrollEnabled)
        XCTAssertTrue(sv!.showsVerticalScrollIndicator)
    }

    func testKeyboardDismissOnDrag() {
        var style = ScrollableStyle()
        style.keyboardDismiss = .onDrag
        let h = host(style)
        let sv = scrollView(of: h)
        XCTAssertEqual(sv!.keyboardDismissMode, .onDrag)
    }

    func testKeyboardDismissInteractive() {
        var style = ScrollableStyle()
        style.keyboardDismiss = .interactive
        let h = host(style)
        let sv = scrollView(of: h)
        XCTAssertEqual(sv!.keyboardDismissMode, .interactive)
    }

    // MARK: - Axis

    func testVerticalAxisProposesUnlimitedHeight() {
        let h = host(ScrollableStyle(axis: .vertical))
        let c = child(100, 800)
        h.addSubview(c)
        h.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        h.layoutSubviews()

        XCTAssertEqual(c.frame.height, 800, accuracy: 0.5)
        XCTAssertEqual(c.frame.width, 100, accuracy: 0.5)
    }

    func testHorizontalAxisProposesUnlimitedWidth() {
        let h = host(ScrollableStyle(axis: .horizontal))
        let c = child(800, 100)
        h.addSubview(c)
        h.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        h.layoutSubviews()

        XCTAssertEqual(c.frame.width, 800, accuracy: 0.5)
        XCTAssertEqual(c.frame.height, 100, accuracy: 0.5)
    }

    // MARK: - Sizing

    func testSizeThatFitsVerticalBounce() {
        let h = host(ScrollableStyle(axis: .vertical, bounces: true))
        let c = child(100, 50)
        h.addSubview(c)
        let size = h.sizeThatFits(CGSize(width: 200, height: 400))
        // Bounces: takes proposed height. Cross: child width.
        XCTAssertEqual(size.width, 100, accuracy: 0.5)
        XCTAssertEqual(size.height, 400, accuracy: 0.5)
    }

    func testSizeThatFitsVerticalNoBounce() {
        let h = host(ScrollableStyle(axis: .vertical, bounces: false))
        let c = child(100, 50)
        h.addSubview(c)
        let size = h.sizeThatFits(CGSize(width: 200, height: 400))
        // No bounce: min(child, proposed) on scroll axis.
        XCTAssertEqual(size.width, 100, accuracy: 0.5)
        XCTAssertEqual(size.height, 50, accuracy: 0.5)
    }

    func testSizeThatFitsVerticalNoBounceOverflow() {
        let h = host(ScrollableStyle(axis: .vertical, bounces: false))
        let c = child(100, 800)
        h.addSubview(c)
        let size = h.sizeThatFits(CGSize(width: 200, height: 400))
        // Content overflows: capped at proposed.
        XCTAssertEqual(size.height, 400, accuracy: 0.5)
    }

    // MARK: - Padding

    func testPaddingSetsContentInset() {
        var style = ScrollableStyle()
        style.padding = Padding(top: 10, bottom: 20, leading: 5, trailing: 15)
        let h = host(style)
        let sv = scrollView(of: h)
        XCTAssertEqual(sv!.contentInset.top, 10, accuracy: 0.5)
        XCTAssertEqual(sv!.contentInset.bottom, 20, accuracy: 0.5)
        XCTAssertEqual(sv!.contentInset.left, 5, accuracy: 0.5)
        XCTAssertEqual(sv!.contentInset.right, 15, accuracy: 0.5)
    }
}

#endif
