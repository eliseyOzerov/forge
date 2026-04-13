#if canImport(UIKit)
import XCTest
@testable import ForgeSwift

final class SVGParserTests: XCTestCase {

    // MARK: - Basic Parsing

    func testParseMinimalSVG() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 50"></svg>
            """)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.viewBox.width, 100)
        XCTAssertEqual(doc!.viewBox.height, 50)
    }

    func testParseWidthHeightFallback() {
        let doc = SVGParser().parse("""
            <svg width="200" height="100"></svg>
            """)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.viewBox.width, 200)
        XCTAssertEqual(doc!.viewBox.height, 100)
    }

    func testParseWidthWithUnits() {
        let doc = SVGParser().parse("""
            <svg width="200px" height="100pt"></svg>
            """)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.viewBox.width, 200)
        XCTAssertEqual(doc!.viewBox.height, 100)
    }

    func testParseNoSizeDefaults() {
        let doc = SVGParser().parse("<svg></svg>")
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.viewBox.width, 100)
        XCTAssertEqual(doc!.viewBox.height, 100)
    }

    func testParseEmptyString() {
        XCTAssertNil(SVGParser().parse(""))
    }

    func testParseMalformedXML() {
        XCTAssertNil(SVGParser().parse("<svg><unclosed"))
    }

    func testParseFromData() {
        let data = "<svg viewBox=\"0 0 50 50\"></svg>".data(using: .utf8)!
        let doc = SVGParser().parse(data)
        XCTAssertNotNil(doc)
        XCTAssertEqual(doc!.viewBox.width, 50)
    }

    // MARK: - Elements

    func testParsePath() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><path d="M0 0 L100 100"/></svg>
            """)!
        XCTAssertEqual(doc.elements.count, 1)
        if case .path(let data) = doc.elements[0] {
            XCTAssertEqual(data.d, "M0 0 L100 100")
        } else { XCTFail("expected path") }
    }

    func testParseRect() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect x="10" y="20" width="80" height="60"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.x, 10); XCTAssertEqual(data.y, 20)
            XCTAssertEqual(data.width, 80); XCTAssertEqual(data.height, 60)
        } else { XCTFail("expected rect") }
    }

    func testParseRoundedRect() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect x="0" y="0" width="100" height="100" rx="10" ry="5"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.rx, 10); XCTAssertEqual(data.ry, 5)
        } else { XCTFail("expected rect") }
    }

    func testParseCircle() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="25"/></svg>
            """)!
        if case .circle(let data) = doc.elements[0] {
            XCTAssertEqual(data.cx, 50); XCTAssertEqual(data.cy, 50); XCTAssertEqual(data.r, 25)
        } else { XCTFail("expected circle") }
    }

    func testParseEllipse() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><ellipse cx="50" cy="50" rx="40" ry="20"/></svg>
            """)!
        if case .ellipse(let data) = doc.elements[0] {
            XCTAssertEqual(data.cx, 50); XCTAssertEqual(data.rx, 40); XCTAssertEqual(data.ry, 20)
        } else { XCTFail("expected ellipse") }
    }

    func testParseLine() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><line x1="10" y1="20" x2="90" y2="80"/></svg>
            """)!
        if case .line(let data) = doc.elements[0] {
            XCTAssertEqual(data.x1, 10); XCTAssertEqual(data.y1, 20)
            XCTAssertEqual(data.x2, 90); XCTAssertEqual(data.y2, 80)
        } else { XCTFail("expected line") }
    }

    func testParsePolygon() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><polygon points="0,0 100,0 50,100"/></svg>
            """)!
        if case .polygon(let data) = doc.elements[0] {
            XCTAssertEqual(data.points.count, 3)
            XCTAssertEqual(data.points[0], Point(0, 0))
            XCTAssertEqual(data.points[2], Point(50, 100))
        } else { XCTFail("expected polygon") }
    }

    func testParsePolyline() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><polyline points="0,0 50,50 100,0"/></svg>
            """)!
        if case .polyline(let data) = doc.elements[0] {
            XCTAssertEqual(data.points.count, 3)
        } else { XCTFail("expected polyline") }
    }

    func testParseMultipleElements() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <rect x="0" y="0" width="50" height="50"/>
                <circle cx="75" cy="75" r="20"/>
            </svg>
            """)!
        XCTAssertEqual(doc.elements.count, 2)
    }

    // MARK: - Groups

    func testParseGroup() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <g>
                    <rect x="0" y="0" width="50" height="50"/>
                    <circle cx="75" cy="75" r="20"/>
                </g>
            </svg>
            """)!
        XCTAssertEqual(doc.elements.count, 1)
        if case .group(let data) = doc.elements[0] {
            XCTAssertEqual(data.children.count, 2)
        } else { XCTFail("expected group") }
    }

    func testParseNestedGroups() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <g><g><rect x="0" y="0" width="10" height="10"/></g></g>
            </svg>
            """)!
        if case .group(let outer) = doc.elements[0],
           case .group(let inner) = outer.children[0] {
            XCTAssertEqual(inner.children.count, 1)
        } else { XCTFail("expected nested groups") }
    }

    // MARK: - IDs

    func testExplicitID() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect id="myRect" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.id, "myRect")
        } else { XCTFail() }
    }

    func testAutoGeneratedID() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.id, "Rect 1")
        } else { XCTFail() }
    }

    func testElementIDs() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <rect id="a" x="0" y="0" width="10" height="10"/>
                <circle id="b" cx="50" cy="50" r="10"/>
            </svg>
            """)!
        XCTAssertEqual(doc.elementIDs, ["a", "b"])
    }

    // MARK: - Paint Attributes

    func testFillColor() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect fill="#ff0000" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0],
           case .color(let c) = data.attributes.fill {
            XCTAssertEqual(c.red, 1, accuracy: 1e-2)
            XCTAssertEqual(c.green, 0, accuracy: 1e-2)
        } else { XCTFail("expected red fill") }
    }

    func testFillShortHex() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect fill="#f00" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0],
           case .color(let c) = data.attributes.fill {
            XCTAssertEqual(c.red, 1, accuracy: 1e-2)
        } else { XCTFail() }
    }

    func testFillNone() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect fill="none" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            if case .none = data.attributes.fill {} else { XCTFail("expected fill=none") }
        } else { XCTFail() }
    }

    func testFillCurrentColor() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect fill="currentColor" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            if case .currentColor = data.attributes.fill {} else { XCTFail("expected currentColor") }
        } else { XCTFail() }
    }

    func testNamedColors() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect fill="blue" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0],
           case .color(let c) = data.attributes.fill {
            XCTAssertEqual(c.blue, 1, accuracy: 1e-2)
        } else { XCTFail() }
    }

    func testStrokeAttributes() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect stroke="red" stroke-width="3" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            if case .color(let c) = data.attributes.stroke {
                XCTAssertEqual(c.red, 1, accuracy: 1e-2)
            } else { XCTFail("expected stroke color") }
            XCTAssertEqual(data.attributes.strokeWidth, 3)
        } else { XCTFail() }
    }

    func testStrokeLineCap() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><line stroke-linecap="round" x1="0" y1="0" x2="10" y2="10"/></svg>
            """)!
        if case .line(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.strokeLineCap, .round)
        } else { XCTFail() }
    }

    func testStrokeLineJoin() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><path stroke-linejoin="bevel" d="M0 0"/></svg>
            """)!
        if case .path(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.strokeLineJoin, .bevel)
        } else { XCTFail() }
    }

    func testOpacity() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect opacity="0.5" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.opacity, 0.5, accuracy: 1e-5)
        } else { XCTFail() }
    }

    func testFillOpacity() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect opacity="0.5" fill-opacity="0.5" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.opacity, 0.25, accuracy: 1e-5)
        } else { XCTFail() }
    }

    // MARK: - Transforms

    func testTransformTranslate() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect transform="translate(10,20)" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.transform.tx, 10, accuracy: 1e-5)
            XCTAssertEqual(data.attributes.transform.ty, 20, accuracy: 1e-5)
        } else { XCTFail() }
    }

    func testTransformScale() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect transform="scale(2)" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            XCTAssertEqual(data.attributes.transform.a, 2, accuracy: 1e-5)
            XCTAssertEqual(data.attributes.transform.d, 2, accuracy: 1e-5)
        } else { XCTFail() }
    }

    func testTransformRotate() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100"><rect transform="rotate(90)" x="0" y="0" width="10" height="10"/></svg>
            """)!
        if case .rect(let data) = doc.elements[0] {
            // 90 degrees → a≈0, b≈1, c≈-1, d≈0
            XCTAssertEqual(data.attributes.transform.a, cos(.pi/2), accuracy: 1e-5)
            XCTAssertEqual(data.attributes.transform.b, sin(.pi/2), accuracy: 1e-5)
        } else { XCTFail() }
    }

    // MARK: - Attribute Inheritance

    func testGroupAttributesInherited() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <g fill="red"><rect x="0" y="0" width="10" height="10"/></g>
            </svg>
            """)!
        if case .group(let g) = doc.elements[0],
           case .rect(let r) = g.children[0],
           case .color(let c) = r.attributes.fill {
            XCTAssertEqual(c.red, 1, accuracy: 1e-2)
        } else { XCTFail("child should inherit group fill") }
    }

    func testChildOverridesInherited() {
        let doc = SVGParser().parse("""
            <svg viewBox="0 0 100 100">
                <g fill="red"><rect fill="blue" x="0" y="0" width="10" height="10"/></g>
            </svg>
            """)!
        if case .group(let g) = doc.elements[0],
           case .rect(let r) = g.children[0],
           case .color(let c) = r.attributes.fill {
            XCTAssertEqual(c.blue, 1, accuracy: 1e-2)
            XCTAssertEqual(c.red, 0, accuracy: 1e-2)
        } else { XCTFail("child should override group fill") }
    }
}

#endif
