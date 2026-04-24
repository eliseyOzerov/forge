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
final class SafeAreaTests: XCTestCase {

    // MARK: - SafeAreaPadding

    func testSafeAreaPaddingEquality() {
        let a = SafeAreaPadding(Padding(top: 10))
        let b = SafeAreaPadding(Padding(top: 10))
        let c = SafeAreaPadding(Padding(top: 20))
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
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

    func testSafeInsetSizeThatFitsDelegatesToContent() {
        let container = SafeInsetHostView()
        container.edge = .top
        let content = FixedSizeView(size: CGSize(width: 200, height: 100))
        let overlay = FixedSizeView(size: CGSize(width: 200, height: 44))
        container.addSubview(content)
        container.addSubview(overlay)

        let size = container.sizeThatFits(CGSize(width: 400, height: 800))
        XCTAssertEqual(size.width, 200, accuracy: 0.5)
        XCTAssertEqual(size.height, 100, accuracy: 0.5)
    }

    // MARK: - Edge.Set

    func testEdgeSetInverse() {
        XCTAssertEqual(Edge.Set.top.inverse, [.bottom, .leading, .trailing])
        XCTAssertEqual(Edge.Set.all.inverse, [])
        XCTAssertEqual(Edge.Set([]).inverse, .all)
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
