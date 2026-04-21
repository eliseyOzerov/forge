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
    override var intrinsicContentSize: CGSize { fixedSize }
}

@MainActor
final class SafeAreaInsetTests: XCTestCase {

    // MARK: - Helpers

    private func makeInsetView(
        edge: Edge = .top,
        containerSize: CGSize = CGSize(width: 400, height: 800),
        overlaySize: CGSize = CGSize(width: 400, height: 88)
    ) -> SafeAreaInsetView {
        let view = SafeAreaInsetView()
        view.edge = edge
        view.frame = CGRect(origin: .zero, size: containerSize)

        // Child 0 = content
        let content = UIView()
        view.addSubview(content)

        // Child 1 = overlay
        let overlay = FixedSizeView(size: overlaySize)
        view.addSubview(overlay)

        view.layoutSubviews()
        return view
    }

    // MARK: - Layout: Top edge

    func testTopOverlayPositionedAtTop() {
        let view = makeInsetView(edge: .top, overlaySize: CGSize(width: 400, height: 88))
        let overlay = view.subviews[1]
        XCTAssertEqual(overlay.frame, CGRect(x: 0, y: 0, width: 400, height: 88))
    }

    func testTopContentFillsBounds() {
        let view = makeInsetView(edge: .top)
        let content = view.subviews[0]
        XCTAssertEqual(content.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    func testTopAdjustment() {
        let view = makeInsetView(edge: .top, overlaySize: CGSize(width: 400, height: 88))
        XCTAssertEqual(view.safeAreaAdjustment.top, 88)
        XCTAssertEqual(view.safeAreaAdjustment.bottom, 0)
        XCTAssertEqual(view.safeAreaAdjustment.left, 0)
        XCTAssertEqual(view.safeAreaAdjustment.right, 0)
    }

    // MARK: - Layout: Bottom edge

    func testBottomOverlayPositionedAtBottom() {
        let view = makeInsetView(edge: .bottom, overlaySize: CGSize(width: 400, height: 60))
        let overlay = view.subviews[1]
        XCTAssertEqual(overlay.frame, CGRect(x: 0, y: 740, width: 400, height: 60))
    }

    func testBottomAdjustment() {
        let view = makeInsetView(edge: .bottom, overlaySize: CGSize(width: 400, height: 60))
        XCTAssertEqual(view.safeAreaAdjustment.top, 0)
        XCTAssertEqual(view.safeAreaAdjustment.bottom, 60)
    }

    // MARK: - Layout: Leading edge

    func testLeadingOverlayPositionedAtLeading() {
        let view = makeInsetView(edge: .leading, overlaySize: CGSize(width: 80, height: 800))
        let overlay = view.subviews[1]
        XCTAssertEqual(overlay.frame, CGRect(x: 0, y: 0, width: 80, height: 800))
    }

    func testLeadingAdjustment() {
        let view = makeInsetView(edge: .leading, overlaySize: CGSize(width: 80, height: 800))
        XCTAssertEqual(view.safeAreaAdjustment.left, 80)
        XCTAssertEqual(view.safeAreaAdjustment.right, 0)
    }

    // MARK: - Layout: Trailing edge

    func testTrailingOverlayPositionedAtTrailing() {
        let view = makeInsetView(edge: .trailing, overlaySize: CGSize(width: 80, height: 800))
        let overlay = view.subviews[1]
        XCTAssertEqual(overlay.frame, CGRect(x: 320, y: 0, width: 80, height: 800))
    }

    func testTrailingAdjustment() {
        let view = makeInsetView(edge: .trailing, overlaySize: CGSize(width: 80, height: 800))
        XCTAssertEqual(view.safeAreaAdjustment.left, 0)
        XCTAssertEqual(view.safeAreaAdjustment.right, 80)
    }

    // MARK: - SafeArea integration

    func testSafeAreaViewPicksUpAdjustment() {
        // Build hierarchy: SafeAreaInsetView > SafeAreaView > child
        let insetView = SafeAreaInsetView()
        insetView.edge = .top
        insetView.frame = CGRect(x: 0, y: 0, width: 400, height: 800)

        // Content = a SafeAreaView with a child
        let safeArea = TestSafeAreaView(overrideInsets: UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0))
        safeArea.edges = .all
        insetView.addSubview(safeArea)

        let child = UIView()
        safeArea.addSubview(child)

        // Overlay = 88pt navbar
        let overlay = FixedSizeView(size: CGSize(width: 400, height: 88))
        insetView.addSubview(overlay)

        // Layout the inset view first, then the safe area
        insetView.layoutSubviews()
        safeArea.frame = insetView.subviews[0].frame
        safeArea.layoutSubviews()

        // SafeAreaView should include both device insets AND the overlay adjustment
        // Top: 44 (device) + 88 (navbar) = 132
        // Bottom: 34 (device)
        XCTAssertEqual(child.frame.origin.y, 132, accuracy: 0.1)
        XCTAssertEqual(child.frame.size.height, 800 - 132 - 34, accuracy: 0.1)
    }

    // MARK: - sizeThatFits

    func testSizeThatFitsDelegatesToContent() {
        let view = SafeAreaInsetView()
        view.edge = .top

        let content = FixedSizeView(size: CGSize(width: 300, height: 500))
        view.addSubview(content)

        let overlay = FixedSizeView(size: CGSize(width: 400, height: 88))
        view.addSubview(overlay)

        let size = view.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 300)
        XCTAssertEqual(size.height, 500)
    }

    // MARK: - Single child fallback

    func testSingleChildFillsBounds() {
        let view = SafeAreaInsetView()
        view.frame = CGRect(x: 0, y: 0, width: 400, height: 800)

        let child = UIView()
        view.addSubview(child)
        view.layoutSubviews()

        XCTAssertEqual(child.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    // MARK: - Renderer

    func testRendererMountProducesInsetView() {
        let view = SafeAreaInset(edge: .top, overlay: { EmptyView() }) { EmptyView() }
        let platformView = view.makeRenderer().mount()
        XCTAssertTrue(platformView is SafeAreaInsetView)
    }

    func testRendererUpdateChangesEdge() {
        let renderer = SafeAreaInsetRenderer(edge: .top)
        let platformView = renderer.mount() as! SafeAreaInsetView
        XCTAssertEqual(platformView.edge, .top)

        renderer.update(from: SafeAreaInset(edge: .bottom, overlay: { EmptyView() }) { EmptyView() })
        XCTAssertEqual(platformView.edge, .bottom)
    }

    // MARK: - Public API

    func testChildrenOrder() {
        let inset = SafeAreaInset(edge: .top, overlay: { EmptyView() }) { EmptyView() }
        XCTAssertEqual(inset.children.count, 2)
    }

    func testDefaultEdgeIsTop() {
        let inset = SafeAreaInset(overlay: { EmptyView() }) { EmptyView() }
        XCTAssertEqual(inset.edge, .top)
    }
}

// MARK: - TestSafeAreaView

/// SafeAreaView subclass that allows overriding safeAreaInsets for testing.
private class TestSafeAreaView: SafeAreaView {
    private let overrideInsets: UIEdgeInsets

    init(overrideInsets: UIEdgeInsets) {
        self.overrideInsets = overrideInsets
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var safeAreaInsets: UIEdgeInsets { overrideInsets }
}

#endif
