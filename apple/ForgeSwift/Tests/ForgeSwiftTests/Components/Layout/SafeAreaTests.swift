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

    // MARK: - SafeArea Layout

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

    // MARK: - SafeArea re-provides zeroed edges

    func testInsetsProviderZerosConsumedEdges() {
        let (h, _) = host(edges: .vertical, insets: UIEdgeInsets(top: 44, left: 16, bottom: 34, right: 16))
        // Consumed vertical, so provided insets should have top=0, bottom=0, horizontal preserved
        let provided = h.insets
        XCTAssertEqual(provided.top, 0)
        XCTAssertEqual(provided.bottom, 0)
        XCTAssertEqual(provided.leading, 16)
        XCTAssertEqual(provided.trailing, 16)
    }

    // MARK: - SafeArea sizing

    func testSizeThatFitsDelegatesToChild() {
        let (h, _) = host(childSize: CGSize(width: 200, height: 100))
        let size = h.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, 100)
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

        XCTAssertEqual(overlay.frame.origin.y, 0, accuracy: 0.5)
        XCTAssertEqual(overlay.frame.size.height, 44, accuracy: 0.5)
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

        XCTAssertEqual(overlay.frame.origin.y, 751, accuracy: 0.5)
        XCTAssertEqual(overlay.frame.size.height, 49, accuracy: 0.5)
    }

    func testSafeInsetAddsToInsets() {
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

    // MARK: - SafeInset leading/trailing

    func testSafeInsetOverlayPositionedAtLeading() {
        let container = SafeInsetHostView()
        container.edge = .leading
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 60, height: 800))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        container.layoutSubviews()

        XCTAssertEqual(overlay.frame.origin.x, 0, accuracy: 0.5)
        XCTAssertEqual(overlay.frame.size.width, 60, accuracy: 0.5)
        XCTAssertEqual(overlay.frame.size.height, 800, accuracy: 0.5)
    }

    func testSafeInsetOverlayPositionedAtTrailing() {
        let container = SafeInsetHostView()
        container.edge = .trailing
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 60, height: 800))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        container.layoutSubviews()

        XCTAssertEqual(overlay.frame.origin.x, 340, accuracy: 0.5)
        XCTAssertEqual(overlay.frame.size.width, 60, accuracy: 0.5)
    }

    func testSafeInsetAddsToInsetsLeading() {
        let container = SafeInsetHostView()
        container.edge = .leading
        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 60, height: 800))
        container.addSubview(content)
        container.addSubview(overlay)
        container.frame = CGRect(x: 0, y: 0, width: 400, height: 800)

        XCTAssertEqual(container.insets.leading, 60, accuracy: 0.5)
        XCTAssertEqual(container.insets.top, 0, accuracy: 0.5)
    }

    // MARK: - SafeInset sizing

    func testSafeInsetSizeThatFitsDelegatesToContent() {
        let container = SafeInsetHostView()
        container.edge = .top
        let content = FixedSizeView(size: CGSize(width: 200, height: 300))
        let overlay = FixedSizeView(size: CGSize(width: 200, height: 44))
        container.addSubview(content)
        container.addSubview(overlay)

        let size = container.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 200, accuracy: 0.5)
        XCTAssertEqual(size.height, 300, accuracy: 0.5)
    }

    // MARK: - Chained SafeInsets

    func testChainedSafeInsetsStack() {
        // Outer: top inset of 44. Inner: bottom inset of 49.
        // Inner should see top=44 from outer and add bottom=49.
        let outer = SafeInsetHostView()
        outer.edge = .top
        let inner = SafeInsetHostView()
        inner.edge = .bottom

        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let topOverlay = FixedSizeView(size: CGSize(width: 400, height: 44))
        let bottomOverlay = FixedSizeView(size: CGSize(width: 400, height: 49))

        // Build tree: outer > inner > content, outer has topOverlay, inner has bottomOverlay
        inner.addSubview(content)
        inner.addSubview(bottomOverlay)
        outer.addSubview(inner)
        outer.addSubview(topOverlay)

        outer.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        outer.layoutSubviews()
        inner.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        inner.layoutSubviews()

        // Outer provides top=44
        XCTAssertEqual(outer.insets.top, 44, accuracy: 0.5)
        XCTAssertEqual(outer.insets.bottom, 0, accuracy: 0.5)

        // Inner inherits top=44 from outer, adds bottom=49
        XCTAssertEqual(inner.insets.top, 44, accuracy: 0.5)
        XCTAssertEqual(inner.insets.bottom, 49, accuracy: 0.5)
    }

    // MARK: - SafeArea inside SafeInset

    func testSafeAreaInsideSafeInsetFindsProvider() {
        // SafeInset provides top=44. SafeArea inside should consume it.
        let insetHost = SafeInsetHostView()
        insetHost.edge = .top
        let safeHost = SafeAreaHostView()
        safeHost.edges = .all

        let content = FixedSizeView(size: CGSize(width: 400, height: 800))
        let overlay = FixedSizeView(size: CGSize(width: 400, height: 44))

        safeHost.addSubview(content)
        insetHost.addSubview(safeHost)
        insetHost.addSubview(overlay)

        insetHost.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        insetHost.layoutSubviews()
        safeHost.frame = CGRect(x: 0, y: 0, width: 400, height: 800)
        safeHost.layoutSubviews()

        // SafeArea should have inset the child by top=44
        XCTAssertEqual(content.frame.origin.y, 44, accuracy: 0.5)
        XCTAssertEqual(content.frame.size.height, 756, accuracy: 0.5)

        // SafeArea re-provides with top zeroed
        XCTAssertEqual(safeHost.insets.top, 0, accuracy: 0.5)
    }

    // MARK: - Edge.Set

    func testEdgeSetInverse() {
        XCTAssertEqual(Edge.Set.top.inverse, [.bottom, .leading, .trailing])
        XCTAssertEqual(Edge.Set.all.inverse, [])
        XCTAssertEqual(Edge.Set.none.inverse, .all)
        XCTAssertEqual(Edge.Set.vertical.inverse, .horizontal)
    }

    // MARK: - Public API

    func testSafeAreaDefaultEdges() {
        let sa = SafeArea { Box() {} }
        XCTAssertEqual(sa.edges, .all)
    }

    func testSafeAreaCustomEdges() {
        let sa = SafeArea(edges: .vertical) { Box() {} }
        XCTAssertEqual(sa.edges, .vertical)
    }
}

#endif
