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

/// SafeAreaHostView subclass that allows overriding safeAreaInsets for testing.
private class TestSafeAreaHostView: SafeAreaHostView {
    private let overrideInsets: UIEdgeInsets
    init(overrideInsets: UIEdgeInsets) {
        self.overrideInsets = overrideInsets
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }
    override var safeAreaInsets: UIEdgeInsets { overrideInsets }
}

@MainActor
final class SafeAreaTests: XCTestCase {

    private func host(
        edges: Edge.Set = .all,
        containerSize: CGSize = CGSize(width: 400, height: 800),
        childSize: CGSize = CGSize(width: 100, height: 50),
        insets: UIEdgeInsets = .zero
    ) -> (host: SafeAreaHostView, child: FixedSizeView) {
        let h = TestSafeAreaHostView(overrideInsets: insets)
        h.edges = edges
        h.frame = CGRect(origin: .zero, size: containerSize)
        let c = FixedSizeView(size: childSize)
        h.addSubview(c)
        h.layoutSubviews()
        return (h, c)
    }

    // MARK: - Layout

    func testAllEdgesInset() {
        let (_, c) = host(insets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
        XCTAssertEqual(c.frame.origin.y, 44)
        XCTAssertEqual(c.frame.size.height, 800 - 44 - 34)
    }

    func testTopOnly() {
        let (_, c) = host(edges: [.top], insets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
        XCTAssertEqual(c.frame.origin.y, 44)
        XCTAssertEqual(c.frame.size.height, 800 - 44)
    }

    func testBottomOnly() {
        let (_, c) = host(edges: [.bottom], insets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
        XCTAssertEqual(c.frame.origin.y, 0)
        XCTAssertEqual(c.frame.size.height, 800 - 34)
    }

    func testHorizontalEdges() {
        let (_, c) = host(edges: .horizontal, insets: UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16))
        XCTAssertEqual(c.frame.origin.x, 16)
        XCTAssertEqual(c.frame.size.width, 400 - 32)
    }

    func testNoEdgesNoInset() {
        let (_, c) = host(edges: [], insets: UIEdgeInsets(top: 44, left: 16, bottom: 34, right: 16))
        XCTAssertEqual(c.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    func testZeroInsets() {
        let (_, c) = host(insets: .zero)
        XCTAssertEqual(c.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    // MARK: - sizeThatFits

    func testSizeThatFitsDelegatesToChild() {
        let (h, _) = host(childSize: CGSize(width: 200, height: 100), insets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
        let size = h.sizeThatFits(CGSize(width: 400, height: 800))
        // SafeArea is a passthrough for sizing — reports child size
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, 100)
    }

    func testSizeThatFitsNoChild() {
        let h = TestSafeAreaHostView(overrideInsets: .zero)
        h.edges = .all
        XCTAssertEqual(h.sizeThatFits(CGSize(width: 400, height: 800)), .zero)
    }

    // MARK: - SafeInset

    func testSafeInsetOverlayPositionedAtTop() {
        let container = SafeInsetHostView()
        container.edge = .top
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 400, height: 44))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        container.layoutSubviews()

        XCTAssertEqual(overlay.frame, CGRect(x: 0, y: 0, width: 400, height: 44))
        XCTAssertEqual(content.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    func testSafeInsetOverlayPositionedAtBottom() {
        let container = SafeInsetHostView()
        container.edge = .bottom
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 400, height: 49))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        container.layoutSubviews()

        XCTAssertEqual(overlay.frame, CGRect(x: 0, y: 751, width: 400, height: 49))
    }

    func testSafeInsetProvidesPadding() {
        let container = SafeInsetHostView()
        container.edge = .top
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 400, height: 44))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        container.layoutSubviews()

        XCTAssertEqual(container.insets.top, 44, accuracy: 0.5)
    }
}

#endif
