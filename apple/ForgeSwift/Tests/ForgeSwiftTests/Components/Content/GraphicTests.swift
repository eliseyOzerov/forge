import Testing
@testable import ForgeSwift

// MARK: - GraphicStyle (platform-agnostic)

@Suite("GraphicStyle")
struct GraphicStyleTests {

    @Test func defaults() {
        let style = GraphicStyle()
        #expect(style.size == nil)
        #expect(style.fit == .cover)
        #expect(style.state == nil)
    }

    @Test func initWithFields() {
        let size = Size(100, 200)
        let style = GraphicStyle(size: size, fit: .contain)
        #expect(style.size == size)
        #expect(style.fit == .contain)
    }
}

// MARK: - GraphicOrigin

@Suite("GraphicOrigin")
struct GraphicOriginTests {

    @Test func cases() {
        let string = GraphicOrigin.string("<svg></svg>")
        let data = GraphicOrigin.data(Data())
        let asset = GraphicOrigin.asset("icon")
        let file = GraphicOrigin.file(URL(fileURLWithPath: "/tmp/test.svg"))

        if case .string(let s) = string { #expect(s == "<svg></svg>") }
        else { Issue.record("Expected .string") }

        if case .data(let d) = data { #expect(d.isEmpty) }
        else { Issue.record("Expected .data") }

        if case .asset(let n) = asset { #expect(n == "icon") }
        else { Issue.record("Expected .asset") }

        if case .file(let u) = file { #expect(u.lastPathComponent == "test.svg") }
        else { Issue.record("Expected .file") }
    }
}

// MARK: - GraphicLeaf + Renderer (UIKit only)

#if canImport(UIKit)
import XCTest
import UIKit

@MainActor
final class GraphicViewTests: XCTestCase {

    func testGraphicInit() {
        let graphic = Graphic(.string("<svg></svg>"))
        if case .string(let s) = graphic.source {
            XCTAssertEqual(s, "<svg></svg>")
        } else {
            XCTFail("Expected .string source")
        }
        let style = graphic.style(.idle)
        XCTAssertNil(style.size)
        XCTAssertEqual(style.fit, .cover)
    }

    func testStyleModifier() {
        let graphic = Graphic(.string("<svg></svg>"))
            .style { style, _ in GraphicStyle(size: Size(64, 64), fit: .contain) }
        let style = graphic.style(.idle)
        XCTAssertEqual(style.fit, .contain)
        XCTAssertEqual(style.size, Size(64, 64))
    }

    func testMountProducesView() {
        let doc = SVGParser().parse("<svg viewBox=\"0 0 100 50\"><rect width=\"100\" height=\"50\"/></svg>")!
        let leaf = GraphicLeaf(document: doc, style: GraphicStyle())
        let renderer = leaf.makeRenderer()
        let view = renderer.mount()
        XCTAssertTrue(view is GraphicCanvasView)
    }

    func testIntrinsicSizeFromViewBox() {
        let doc = SVGParser().parse("<svg viewBox=\"0 0 100 50\"><rect width=\"100\" height=\"50\"/></svg>")!
        let leaf = GraphicLeaf(document: doc, style: GraphicStyle())
        let renderer = leaf.makeRenderer()
        let view = renderer.mount() as! GraphicCanvasView
        XCTAssertEqual(view.intrinsicContentSize, CGSize(width: 100, height: 50))
    }

    func testIntrinsicSizeFromExplicitSize() {
        let doc = SVGParser().parse("<svg viewBox=\"0 0 100 50\"><rect width=\"100\" height=\"50\"/></svg>")!
        let leaf = GraphicLeaf(document: doc, style: GraphicStyle(size: Size(200, 100)))
        let renderer = leaf.makeRenderer()
        let view = renderer.mount() as! GraphicCanvasView
        XCTAssertEqual(view.intrinsicContentSize, CGSize(width: 200, height: 100))
    }

    func testFitModeApplied() {
        let doc = SVGParser().parse("<svg viewBox=\"0 0 100 50\"><rect width=\"100\" height=\"50\"/></svg>")!
        let leaf = GraphicLeaf(document: doc, style: GraphicStyle(fit: .contain))
        let renderer = leaf.makeRenderer()
        let view = renderer.mount() as! GraphicCanvasView
        XCTAssertEqual(view.graphicFit, .contain)
    }
}

#endif
