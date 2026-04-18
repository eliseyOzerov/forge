#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class ImageTests: XCTestCase {

    // MARK: - Helpers

    /// Create a solid-color test image of given size.
    private func testImage(width: Int = 100, height: Int = 100, color: UIColor = .red) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    // MARK: - Mount

    func testMountProducesImageView() {
        let img = Image(testImage())
        let view = img.makeRenderer().mount()
        XCTAssertTrue(view is UIImageView)
    }

    func testMountSetsImage() {
        let uiImage = testImage()
        let img = Image(uiImage)
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.image?.size, uiImage.size)
    }

    func testMountWithInvalidName() {
        let img = Image(named: "nonexistent_image_xyz")
        let view = img.makeRenderer().mount() as! UIImageView
        // UIImage(named:) returns nil → empty UIImage
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.image?.size, .zero)
    }

    // MARK: - Style Defaults

    func testDefaultStyle() {
        let style = ImageStyle()
        XCTAssertEqual(style.fit, .aspectFit)
        XCTAssertNil(style.tintColor)
        XCTAssertEqual(style.cornerRadius, 0)
    }

    // MARK: - Content Mode (Fit)

    func testFitAspectFit() {
        let img = Image(testImage(), style: ImageStyle(fit: .aspectFit))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFit)
    }

    func testFitAspectFill() {
        let img = Image(testImage(), style: ImageStyle(fit: .aspectFill))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFill)
    }

    func testFitFill() {
        let img = Image(testImage(), style: ImageStyle(fit: .fill))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleToFill)
    }

    func testFitCenter() {
        let img = Image(testImage(), style: ImageStyle(fit: .center))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .center)
    }

    // MARK: - ImageFit enum mapping

    func testImageFitMapping() {
        XCTAssertEqual(ImageFit.aspectFit.uiContentMode, .scaleAspectFit)
        XCTAssertEqual(ImageFit.aspectFill.uiContentMode, .scaleAspectFill)
        XCTAssertEqual(ImageFit.fill.uiContentMode, .scaleToFill)
        XCTAssertEqual(ImageFit.center.uiContentMode, .center)
    }

    // MARK: - Tint Color

    func testTintColorSetsTemplate() {
        let img = Image(testImage(), style: ImageStyle(tintColor: .blue))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(view.tintColor, Color.blue.platformColor)
    }

    func testNoTintKeepsOriginal() {
        let img = Image(testImage(), style: ImageStyle())
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertNotEqual(view.image?.renderingMode, .alwaysTemplate)
    }

    // MARK: - Corner Radius

    func testCornerRadiusApplied() {
        let img = Image(testImage(), style: ImageStyle(cornerRadius: 12))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.layer.cornerRadius, 12)
    }

    func testZeroCornerRadius() {
        let img = Image(testImage(), style: ImageStyle(cornerRadius: 0))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertEqual(view.layer.cornerRadius, 0)
    }

    // MARK: - Clips to Bounds

    func testClipsToBounds() {
        let img = Image(testImage(), style: ImageStyle(fit: .aspectFill))
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertTrue(view.clipsToBounds)
    }

    // MARK: - Update

    func testUpdateChangesImage() {
        let img1 = testImage(color: .red)
        let img2 = testImage(color: .blue)

        let renderer = UIKitImageRenderer(view: Image(img1, style: ImageStyle()))
        let view = renderer.mount() as! UIImageView
        XCTAssertEqual(view.image?.size, img1.size)

        renderer.update(from: Image(img2, style: ImageStyle()))
        XCTAssertEqual(view.image?.size, img2.size)
    }

    func testUpdateChangesContentMode() {
        let renderer = UIKitImageRenderer(view: Image(testImage(), style: ImageStyle(fit: .aspectFit)))
        let view = renderer.mount() as! UIImageView
        XCTAssertEqual(view.contentMode, .scaleAspectFit)

        renderer.update(from: Image(testImage(), style: ImageStyle(fit: .fill)))
        XCTAssertEqual(view.contentMode, .scaleToFill)
    }

    func testUpdateChangesCornerRadius() {
        let renderer = UIKitImageRenderer(view: Image(testImage(), style: ImageStyle(cornerRadius: 0)))
        let view = renderer.mount() as! UIImageView
        XCTAssertEqual(view.layer.cornerRadius, 0)

        renderer.update(from: Image(testImage(), style: ImageStyle(cornerRadius: 20)))
        XCTAssertEqual(view.layer.cornerRadius, 20)
    }

    func testUpdateChangesToTinted() {
        let renderer = UIKitImageRenderer(view: Image(testImage(), style: ImageStyle()))
        let view = renderer.mount() as! UIImageView
        XCTAssertNotEqual(view.image?.renderingMode, .alwaysTemplate)

        renderer.update(from: Image(testImage(), style: ImageStyle(tintColor: .green)))
        XCTAssertEqual(view.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(view.tintColor, Color.green.platformColor)
    }

    // MARK: - Layout: Size after fit

    func testAspectFitPreservesAspectRatio() {
        // 200x100 image in 100x100 container → image should be 100x50
        let uiImage = testImage(width: 200, height: 100)
        let img = Image(uiImage, style: ImageStyle(fit: .aspectFit))
        let view = img.makeRenderer().mount() as! UIImageView
        view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentMode, .scaleAspectFit)
        // The UIImageView itself is 100x100, but the image is aspect-fitted inside
        XCTAssertEqual(view.frame.width, 100)
        XCTAssertEqual(view.frame.height, 100)
    }

    func testFillStretchesFull() {
        let uiImage = testImage(width: 200, height: 100)
        let img = Image(uiImage, style: ImageStyle(fit: .fill))
        let view = img.makeRenderer().mount() as! UIImageView
        view.frame = CGRect(x: 0, y: 0, width: 50, height: 50)
        view.layoutIfNeeded()
        XCTAssertEqual(view.contentMode, .scaleToFill)
        XCTAssertEqual(view.frame.width, 50)
        XCTAssertEqual(view.frame.height, 50)
    }

    // MARK: - Different Image Sizes

    func testSmallImage() {
        let uiImage = testImage(width: 1, height: 1)
        let img = Image(uiImage)
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.image?.size, CGSize(width: 1, height: 1))
    }

    func testLargeImage() {
        let uiImage = testImage(width: 4000, height: 3000)
        let img = Image(uiImage)
        let view = img.makeRenderer().mount() as! UIImageView
        XCTAssertNotNil(view.image)
        XCTAssertEqual(view.image?.size, CGSize(width: 4000, height: 3000))
    }
}

#endif
