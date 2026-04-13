#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class SurfaceTests: XCTestCase {

    let testShape = Shape.rect()
    let testRect = CGRect(x: 0, y: 0, width: 100, height: 100)

    // MARK: - Helpers

    /// Render a surface into a bitmap and return pixel color at (x, y).
    private func renderAndSample(_ surface: Surface, shape: Shape? = nil, at point: (Int, Int) = (50, 50), size: CGSize = CGSize(width: 100, height: 100)) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let sr = SurfaceRenderer(surface: surface, shape: shape ?? testShape, bounds: CGRect(origin: .zero, size: size))
            sr.render(in: ctx.cgContext)
        }
        return pixelColor(of: image, at: point)
    }

    private func pixelColor(of image: UIImage, at point: (Int, Int)) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let cgImage = image.cgImage else { return (0, 0, 0, 0) }
        let width = cgImage.width
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * cgImage.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData, width: width, height: cgImage.height,
                                       bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return (0, 0, 0, 0)
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: cgImage.height))
        let offset = (point.1 * bytesPerRow) + (point.0 * bytesPerPixel)
        let r = CGFloat(pixelData[offset]) / 255
        let g = CGFloat(pixelData[offset + 1]) / 255
        let b = CGFloat(pixelData[offset + 2]) / 255
        let a = CGFloat(pixelData[offset + 3]) / 255
        return (r, g, b, a)
    }

    // MARK: - Builder Structure

    func testEmptySurface() {
        let surface = Surface()
        let layers = surface.build(shape: testShape)
        XCTAssertTrue(layers.isEmpty)
    }

    func testColorAddsLayer() {
        let surface = Surface().color(Color(1, 0, 0))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ShapeLayer)
    }

    func testGradientAddsLayer() {
        let surface = Surface().gradient(.linear(LinearGradient(colors: [.red, .blue])))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testMultipleLayersAccumulate() {
        let surface = Surface().color(.red).color(.blue).color(.green)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 3)
    }

    func testShapeAddsLayer() {
        let surface = Surface().shape({ _ in .circle() }, .color(.red))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testStrokeAddsLayer() {
        let surface = Surface().stroke(Stroke(width: 2), .color(.black))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is StrokeLayer)
    }

    func testShadowAddsLayer() {
        let surface = Surface().shadow()
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ShadowLayer)
    }

    func testBorderAddsStroke() {
        let surface = Surface().border(.black, width: 1)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is StrokeLayer)
    }

    // MARK: - Transforms Wrap Prior

    func testClipWrapsPrior() {
        let surface = Surface().color(.red).clip(.circle())
        let layers = surface.build(shape: testShape)
        // clip wraps prior → 1 ClipLayer containing the ShapeLayer
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ClipLayer)
    }

    func testFadeWrapsPrior() {
        let surface = Surface().color(.red).fade(0.5)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is FadeLayer)
    }

    func testScaleWrapsPrior() {
        let surface = Surface().color(.red).scale(0.5)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ScaleLayer)
    }

    func testBlendWrapsPrior() {
        let surface = Surface().color(.red).blend(.multiply)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is BlendLayer)
    }

    func testTransformAfterTransform() {
        let surface = Surface().color(.red).fade(0.5).scale(2)
        let layers = surface.build(shape: testShape)
        // scale wraps (fade wraps (color)) → 1 ScaleLayer
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ScaleLayer)
    }

    func testLayerAfterTransform() {
        let surface = Surface().color(.red).clip(.circle()).color(.blue)
        let layers = surface.build(shape: testShape)
        // clip wraps red → ClipLayer, then blue added after → 2 layers
        XCTAssertEqual(layers.count, 2)
        XCTAssertTrue(layers[0] is ClipLayer)
        XCTAssertTrue(layers[1] is ShapeLayer)
    }

    // MARK: - Compose

    func testCompose() {
        let surface = Surface().compose { $0.color(.red).color(.blue) }
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is ComposeLayer)
    }

    // MARK: - Closure Init

    func testClosureInit() {
        let surface = Surface { $0.color(.red).border(.black) }
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 2)
    }

    // MARK: - Static Factories

    func testStaticColor() {
        let surface = Surface.color(.red)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testStaticBorder() {
        let surface = Surface.border(.black)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    // MARK: - Rendering: Color Fill

    func testRenderRedFill() {
        let surface = Surface().color(Color(1, 0, 0))
        let (r, _, _, a) = renderAndSample(surface)
        XCTAssertGreaterThan(r, 0.8)
        XCTAssertGreaterThan(a, 0.8)
    }

    func testRenderBlueFill() {
        let surface = Surface().color(Color(0, 0, 1))
        let (_, _, b, _) = renderAndSample(surface)
        XCTAssertGreaterThan(b, 0.8)
    }

    func testRenderEmptySurfaceIsTransparent() {
        let surface = Surface()
        let (_, _, _, a) = renderAndSample(surface)
        XCTAssertEqual(a, 0, accuracy: 0.02)
    }

    // MARK: - Rendering: Layer Order

    func testRenderLastColorWins() {
        // Red then blue → center should be blue
        let surface = Surface().color(Color(1, 0, 0)).color(Color(0, 0, 1))
        let (r, _, b, _) = renderAndSample(surface)
        XCTAssertEqual(r, 0, accuracy: 0.02)
        XCTAssertEqual(b, 1, accuracy: 0.02)
    }

    // MARK: - Rendering: Clip

    func testRenderClipToCircle() {
        // Fill full rect red, clip to circle. Corner should be transparent.
        let surface = Surface().color(Color(1, 0, 0)).clip(.circle())
        let (_, _, _, aCenter) = renderAndSample(surface, at: (50, 50))
        let (_, _, _, aCorner) = renderAndSample(surface, at: (2, 2))
        XCTAssertEqual(aCenter, 1, accuracy: 0.02)
        XCTAssertEqual(aCorner, 0, accuracy: 0.02)
    }

    // MARK: - Rendering: Fade

    func testRenderFade() {
        let surface = Surface().color(Color(1, 0, 0)).fade(0.5)
        let (_, _, _, a) = renderAndSample(surface)
        // 50% opacity → alpha should be roughly 0.5
        XCTAssertEqual(a, 0.5, accuracy: 0.1)
    }

    // MARK: - Rendering: Shape

    func testRenderShapeOnlyInsideCircle() {
        let surface = Surface().shape({ _ in .circle() }, .color(Color(0, 1, 0)))
        let (_, gCenter, _, aCenter) = renderAndSample(surface, at: (50, 50))
        let (_, _, _, aCorner) = renderAndSample(surface, at: (2, 2))
        XCTAssertGreaterThan(gCenter, 0.8)
        XCTAssertGreaterThan(aCenter, 0.8)
        XCTAssertEqual(aCorner, 0, accuracy: 0.05)
    }

    // MARK: - Rendering: Gradient

    func testRenderLinearGradient() {
        let gradient = LinearGradient(colors: [Color(1, 0, 0), Color(0, 0, 1)])
        let surface = Surface().gradient(.linear(gradient))
        let (rTop, _, bTop, _) = renderAndSample(surface, at: (50, 5))
        let (rBottom, _, bBottom, _) = renderAndSample(surface, at: (50, 95))
        // Top should be more red, bottom more blue
        XCTAssertGreaterThan(rTop, rBottom)
        XCTAssertGreaterThan(bBottom, bTop)
    }

    // MARK: - Radial Gradient

    func testRadialGradientAddsLayer() {
        let stops = [GradientStop(Color(1, 0, 0), at: 0), GradientStop(Color(0, 0, 1), at: 1)]
        let surface = Surface().gradient(.radial(RadialGradient(stops: stops)))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testRadialGradientDefaults() {
        let stops = [GradientStop(Color(1, 0, 0), at: 0), GradientStop(Color(0, 0, 1), at: 1)]
        let g = RadialGradient(stops: stops)
        XCTAssertEqual(g.center.x, 0.5)
        XCTAssertEqual(g.center.y, 0.5)
        XCTAssertEqual(g.radius, 0.5)
    }

    // MARK: - Angular Gradient

    func testAngularGradientAddsLayer() {
        let stops = [GradientStop(Color(1, 0, 0), at: 0), GradientStop(Color(0, 0, 1), at: 1)]
        let surface = Surface().gradient(.angular(AngularGradient(stops: stops)))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testAngularGradientDefaults() {
        let stops = [GradientStop(Color(1, 0, 0), at: 0), GradientStop(Color(0, 0, 1), at: 1)]
        let g = AngularGradient(stops: stops)
        XCTAssertEqual(g.center.x, 0.5)
        XCTAssertEqual(g.center.y, 0.5)
        XCTAssertEqual(g.startAngle, 0)
        XCTAssertEqual(g.endAngle, .pi * 2, accuracy: 0.001)
    }

    // MARK: - Stroke Dash

    func testStrokeWithDashAddsLayer() {
        let dash = Dash([5, 3])
        let stroke = Stroke(width: 2, dash: dash)
        let surface = Surface().stroke(stroke, .color(.black))
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
    }

    func testDashEvenFactory() {
        let dash = Dash.even(10)
        XCTAssertEqual(dash.pattern, [10, 10])
        XCTAssertEqual(dash.phase, 0)
    }

    // MARK: - Transform Layers

    func testTranslateWrapsChildren() {
        let surface = Surface().color(.red).translate(10, 20)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is TranslateLayer)
    }

    func testRotateWrapsChildren() {
        let surface = Surface().color(.red).rotate(.pi / 4)
        let layers = surface.build(shape: testShape)
        XCTAssertEqual(layers.count, 1)
        XCTAssertTrue(layers[0] is RotateLayer)
    }

    // MARK: - BlendMode Mapping

    func testBlendModeNormal() {
        XCTAssertEqual(BlendMode.normal.cgBlendMode, .normal)
    }

    func testBlendModeMultiply() {
        XCTAssertEqual(BlendMode.multiply.cgBlendMode, .multiply)
    }

    func testBlendModeScreen() {
        XCTAssertEqual(BlendMode.screen.cgBlendMode, .screen)
    }

    func testBlendModeOverlay() {
        XCTAssertEqual(BlendMode.overlay.cgBlendMode, .overlay)
    }
}

#endif
