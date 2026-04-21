#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class ImageTests: XCTestCase {

    // MARK: - Helpers

    private func testImageData(width: Int = 100, height: Int = 100, color: UIColor = .red) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.pngData()!
    }

    private func makeLeaf(
        resolved: ResolvedImage? = nil,
        style: ImageStyle = ImageStyle()
    ) -> ImageLeaf {
        ImageLeaf(resolved: resolved ?? .data(testImageData()), style: style)
    }

    // MARK: - ImageOrigin

    func testImageOriginEquality() {
        let url = URL(string: "https://example.com/img.png")!
        let data = testImageData()

        XCTAssertTrue(originEqual(.image("logo"), .image("logo")))
        XCTAssertTrue(originEqual(.asset("data"), .asset("data")))
        XCTAssertTrue(originEqual(.resource("file.png"), .resource("file.png")))
        XCTAssertTrue(originEqual(.url(url), .url(url)))
        XCTAssertTrue(originEqual(.file(url), .file(url)))
        XCTAssertTrue(originEqual(.bytes(data), .bytes(data)))

        XCTAssertFalse(originEqual(.image("a"), .image("b")))
        XCTAssertFalse(originEqual(.image("x"), .asset("x")))
    }

    private func originEqual(_ a: ImageOrigin, _ b: ImageOrigin) -> Bool {
        switch (a, b) {
        case (.image(let a), .image(let b)): return a == b
        case (.asset(let a), .asset(let b)): return a == b
        case (.resource(let a), .resource(let b)): return a == b
        case (.file(let a), .file(let b)): return a == b
        case (.url(let a), .url(let b)): return a == b
        case (.bytes(let a), .bytes(let b)): return a == b
        default: return false
        }
    }

    // MARK: - Style Defaults

    func testDefaultStyle() {
        let style = ImageStyle()
        XCTAssertNil(style.size)
        XCTAssertEqual(style.fit, .cover)
        XCTAssertNil(style.state)
    }

    // MARK: - ImageFit Mapping

    func testImageFitMapping() {
        XCTAssertEqual(ImageFit.cover.uiContentMode, .scaleAspectFill)
        XCTAssertEqual(ImageFit.contain.uiContentMode, .scaleAspectFit)
        XCTAssertEqual(ImageFit.fill.uiContentMode, .scaleToFill)
        XCTAssertEqual(ImageFit.center.uiContentMode, .center)
    }

    // MARK: - Renderer Mount

    func testMountProducesImageView() {
        let leaf = makeLeaf()
        let view = leaf.makeRenderer().mount()
        XCTAssertTrue(view is UIImageView)
    }

    func testMountSetsImage() {
        let data = testImageData()
        let leaf = makeLeaf(resolved: .data(data))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
    }

    func testMountClipsToBounds() {
        let leaf = makeLeaf()
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertTrue(view.clipsToBounds)
    }

    // MARK: - Renderer Fit

    func testFitCover() {
        let leaf = makeLeaf(style: ImageStyle(fit: .cover))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFill)
    }

    func testFitContain() {
        let leaf = makeLeaf(style: ImageStyle(fit: .contain))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFit)
    }

    func testFitFill() {
        let leaf = makeLeaf(style: ImageStyle(fit: .fill))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleToFill)
    }

    func testFitCenter() {
        let leaf = makeLeaf(style: ImageStyle(fit: .center))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .center)
    }

    // MARK: - Renderer Size

    func testSizeApplied() {
        let leaf = makeLeaf(style: ImageStyle(size: Size(200, 150)))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.frame.size.width, 200)
        XCTAssertEqual(view.frame.size.height, 150)
    }

    func testNoSizeDoesNotSetFrame() {
        let leaf = makeLeaf(style: ImageStyle())
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.frame.size, .zero)
    }

    // MARK: - Renderer Update

    func testUpdateChangesImage() {
        let data1 = testImageData(color: .red)
        let data2 = testImageData(color: .blue)

        let renderer = UIKitImageRenderer(view: makeLeaf(resolved: .data(data1)))
        let view = renderer.mount() as! UIImageView
        let originalImage = view.image

        renderer.update(from: ImageLeaf(resolved: .data(data2), style: ImageStyle()))
        XCTAssertNotEqual(view.image?.pngData(), originalImage?.pngData())
    }

    func testUpdateChangesContentMode() {
        let renderer = UIKitImageRenderer(view: makeLeaf(style: ImageStyle(fit: .contain)))
        let view = renderer.mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFit)

        renderer.update(from: makeLeaf(style: ImageStyle(fit: .fill)))
        XCTAssertEqual(view.contentMode, .scaleToFill)
    }

    func testUpdateChangesSize() {
        let renderer = UIKitImageRenderer(view: makeLeaf(style: ImageStyle()))
        let view = renderer.mount() as! UIImageView
        XCTAssertEqual(view.frame.size, .zero)

        renderer.update(from: makeLeaf(style: ImageStyle(size: Size(50, 50))))
        XCTAssertEqual(view.frame.size, CGSize(width: 50, height: 50))
    }

    // MARK: - Named Image (Image Set)

    func testNamedResolution() {
        let leaf = ImageLeaf(resolved: .named("nonexistent_image_xyz"), style: ImageStyle())
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertNil(view.image)
    }

    // MARK: - Bytes Source

    func testBytesResolveImmediately() {
        let data = testImageData()
        let leaf = makeLeaf(resolved: .data(data))
        let view = leaf.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.image?.size, CGSize(width: 100, height: 100))
    }

    // MARK: - Image Public API

    func testImageInit() {
        let img = Image(.url(URL(string: "https://example.com/img.png")!))
        XCTAssertNotNil(img.source)
    }

    func testImageStyleClosure() {
        let img = Image(.bytes(testImageData()))
            .style { style, state in
                style.copy { $0.fit = .fill }
            }
        let resolved = img.style(.idle)
        XCTAssertEqual(resolved.fit, .fill)
    }
}

#endif
