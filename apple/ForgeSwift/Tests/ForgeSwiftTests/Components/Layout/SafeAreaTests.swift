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
final class SafeAreaTests: XCTestCase {

    // MARK: - Helpers

    private func makeSafeAreaView(
        edges: Edge.Set = .all,
        containerSize: CGSize = CGSize(width: 400, height: 800),
        childSize: CGSize = CGSize(width: 100, height: 50),
        safeAreaInsets insets: UIEdgeInsets = .zero
    ) -> (safeArea: SafeAreaView, child: FixedSizeView) {
        let safeArea = TestSafeAreaView(overrideInsets: insets)
        safeArea.edges = edges
        safeArea.frame = CGRect(origin: .zero, size: containerSize)

        let child = FixedSizeView(size: childSize)
        safeArea.addSubview(child)
        safeArea.layoutSubviews()
        return (safeArea, child)
    }

    // MARK: - Layout

    func testAllEdgesInset() {
        let insets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let (_, child) = makeSafeAreaView(safeAreaInsets: insets)

        XCTAssertEqual(child.frame.origin.x, 0)
        XCTAssertEqual(child.frame.origin.y, 44)
        XCTAssertEqual(child.frame.size.width, 400)
        XCTAssertEqual(child.frame.size.height, 800 - 44 - 34)
    }

    func testTopOnly() {
        let insets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let (_, child) = makeSafeAreaView(edges: [.top], safeAreaInsets: insets)

        XCTAssertEqual(child.frame.origin.y, 44)
        XCTAssertEqual(child.frame.size.height, 800 - 44)
    }

    func testBottomOnly() {
        let insets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let (_, child) = makeSafeAreaView(edges: [.bottom], safeAreaInsets: insets)

        XCTAssertEqual(child.frame.origin.y, 0)
        XCTAssertEqual(child.frame.size.height, 800 - 34)
    }

    func testHorizontalEdges() {
        let insets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        let (_, child) = makeSafeAreaView(edges: .horizontal, safeAreaInsets: insets)

        XCTAssertEqual(child.frame.origin.x, 16)
        XCTAssertEqual(child.frame.size.width, 400 - 32)
        XCTAssertEqual(child.frame.origin.y, 0)
        XCTAssertEqual(child.frame.size.height, 800)
    }

    func testNoEdgesNoInset() {
        let insets = UIEdgeInsets(top: 44, left: 16, bottom: 34, right: 16)
        let (_, child) = makeSafeAreaView(edges: [], safeAreaInsets: insets)

        XCTAssertEqual(child.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    func testZeroInsets() {
        let (_, child) = makeSafeAreaView(safeAreaInsets: .zero)
        XCTAssertEqual(child.frame, CGRect(x: 0, y: 0, width: 400, height: 800))
    }

    // MARK: - sizeThatFits

    func testSizeThatFitsAddsInsets() {
        let insets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let (safeArea, _) = makeSafeAreaView(
            childSize: CGSize(width: 200, height: 100),
            safeAreaInsets: insets
        )

        let size = safeArea.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 200)
        XCTAssertEqual(size.height, 100 + 44 + 34)
    }

    func testSizeThatFitsNoChild() {
        let safeArea = TestSafeAreaView(overrideInsets: .zero)
        safeArea.edges = .all
        XCTAssertEqual(safeArea.sizeThatFits(CGSize(width: 400, height: 800)), .zero)
    }

    func testSizeThatFitsPartialEdges() {
        let insets = UIEdgeInsets(top: 44, left: 16, bottom: 34, right: 16)
        let (safeArea, _) = makeSafeAreaView(
            edges: [.top],
            childSize: CGSize(width: 100, height: 50),
            safeAreaInsets: insets
        )

        let size = safeArea.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 100)
        XCTAssertEqual(size.height, 50 + 44)
    }

    // MARK: - intrinsicContentSize

    func testIntrinsicContentSizeAddsInsets() {
        let insets = UIEdgeInsets(top: 44, left: 0, bottom: 34, right: 0)
        let (safeArea, _) = makeSafeAreaView(
            childSize: CGSize(width: 200, height: 100),
            safeAreaInsets: insets
        )

        let intrinsic = safeArea.intrinsicContentSize
        XCTAssertEqual(intrinsic.width, 200)
        XCTAssertEqual(intrinsic.height, 100 + 44 + 34)
    }

    func testIntrinsicContentSizeNoChild() {
        let safeArea = TestSafeAreaView(overrideInsets: .zero)
        safeArea.edges = .all
        XCTAssertEqual(safeArea.intrinsicContentSize.width, UIView.noIntrinsicMetric)
        XCTAssertEqual(safeArea.intrinsicContentSize.height, UIView.noIntrinsicMetric)
    }

    // MARK: - Renderer

    func testRendererMountProducesSafeAreaView() {
        let view = SafeArea(edges: .all) { EmptyView() }
        let platformView = view.makeRenderer().mount()
        XCTAssertTrue(platformView is SafeAreaView)
    }

    func testRendererUpdateChangesEdges() {
        let renderer = SafeAreaRenderer(edges: .all)
        let platformView = renderer.mount() as! SafeAreaView
        XCTAssertEqual(platformView.edges, .all)

        renderer.update(from: SafeArea(edges: [.top]) { EmptyView() })
        XCTAssertEqual(platformView.edges, [.top])
    }

    // MARK: - Public API

    func testChildrenComputedFromChild() {
        let safeArea = SafeArea { EmptyView() }
        XCTAssertEqual(safeArea.children.count, 1)
    }

    func testDefaultEdgesAll() {
        let safeArea = SafeArea { EmptyView() }
        XCTAssertEqual(safeArea.edges, .all)
    }

    func testCustomEdges() {
        let safeArea = SafeArea(edges: .vertical) { EmptyView() }
        XCTAssertEqual(safeArea.edges, .vertical)
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
