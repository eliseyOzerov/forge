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

    // MARK: - Subview Routing

    func testChildRoutedIntoScrollView() {
        let host = ScrollHostView()
        host.configure(ScrollConfig())
        let c = child(50, 50)
        host.addSubview(c)
        XCTAssertTrue(c.superview is UIScrollView, "Child should be inside UIScrollView")
    }

    func testSubviewsReportsScrollViewChildren() {
        let host = ScrollHostView()
        host.configure(ScrollConfig())
        let c = child(50, 50)
        host.addSubview(c)
        XCTAssertEqual(host.subviews.count, 1)
        XCTAssertTrue(host.subviews.first === c)
    }

    // MARK: - Content Size

    func testContentSizeMatchesChild() {
        let host = ScrollHostView()
        host.configure(ScrollConfig())
        let c = child(300, 400)
        host.addSubview(c)
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.layoutSubviews()

        let scrollView = Mirror(reflecting: host).children
            .first { $0.label == "scrollView" }?.value as? UIScrollView
        XCTAssertNotNil(scrollView, "Scroll view should exist")
        XCTAssertEqual(scrollView!.contentSize.width, 300, accuracy: 0.5)
        XCTAssertEqual(scrollView!.contentSize.height, 400, accuracy: 0.5)
    }

    // MARK: - Configuration

    func testConfigureUpdatesScrollViewProperties() {
        let host = ScrollHostView()
        var config = ScrollConfig()
        config.bounces = false
        config.showsIndicators = false
        config.paging = true
        host.configure(config)

        let scrollView = Mirror(reflecting: host).children
            .first { $0.label == "scrollView" }?.value as? UIScrollView
        XCTAssertNotNil(scrollView)
        XCTAssertFalse(scrollView!.bounces)
        XCTAssertFalse(scrollView!.showsHorizontalScrollIndicator)
        XCTAssertFalse(scrollView!.showsVerticalScrollIndicator)
        XCTAssertTrue(scrollView!.isPagingEnabled)
    }

    // MARK: - Axis

    func testVerticalAxisProposesUnlimitedHeight() {
        let host = ScrollHostView()
        host.configure(ScrollConfig(axis: .vertical))
        let c = child(100, 800)
        host.addSubview(c)
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.layoutSubviews()

        // Child should be laid out at its full height
        XCTAssertEqual(c.frame.height, 800, accuracy: 0.5)
        // But width should be constrained to viewport
        XCTAssertEqual(c.frame.width, 100, accuracy: 0.5)
    }

    func testHorizontalAxisProposesUnlimitedWidth() {
        let host = ScrollHostView()
        host.configure(ScrollConfig(axis: .horizontal))
        let c = child(800, 100)
        host.addSubview(c)
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.layoutSubviews()

        XCTAssertEqual(c.frame.width, 800, accuracy: 0.5)
        XCTAssertEqual(c.frame.height, 100, accuracy: 0.5)
    }

    // MARK: - ScrollState

    func testScrollStateUpdatedOnLayout() {
        let state = ScrollState()
        var config = ScrollConfig()
        config.state = state
        let host = ScrollHostView()
        host.configure(config)
        let c = child(300, 400)
        host.addSubview(c)
        host.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.layoutSubviews()

        XCTAssertEqual(state.contentSize.width, 300, accuracy: 0.5)
        XCTAssertEqual(state.contentSize.height, 400, accuracy: 0.5)
        XCTAssertEqual(state.viewportSize.width, 200, accuracy: 0.5)
        XCTAssertEqual(state.viewportSize.height, 200, accuracy: 0.5)
    }
}

#endif
