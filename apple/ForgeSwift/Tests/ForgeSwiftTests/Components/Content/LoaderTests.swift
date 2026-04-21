#if canImport(UIKit)
import XCTest
import UIKit
@testable import ForgeSwift

@MainActor
final class LoaderTests: XCTestCase {

    // MARK: - Helpers

    /// Render a painter at a given progress into a bitmap, return whether any non-clear pixels exist.
    private func painterProducesOutput(_ painter: any LoaderPainter, progress: Double, color: Color = .red) -> Bool {
        let size = 64
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            let bounds = Rect(x: 0, y: 0, width: Double(size), height: Double(size))
            painter.paint(on: canvas, progress: progress, bounds: bounds, color: color)
        }
        return hasNonClearPixels(image)
    }

    private func hasNonClearPixels(_ image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: &pixelData, width: width, height: height,
                                       bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace,
                                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return false
        }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        // Check if any pixel has non-zero alpha
        for i in stride(from: 3, to: pixelData.count, by: 4) {
            if pixelData[i] > 0 { return true }
        }
        return false
    }

    // MARK: - LoaderStyle

    func testAllStylesHaveDuration() {
        let styles: [LoaderStyle] = [.circular, .dots, .pulse, .bars, .orbit, .ripple, .bounce, .wave, .flip, .fade]
        for style in styles {
            XCTAssertGreaterThan(style.duration, 0, "\(style) should have positive duration")
        }
    }

    func testAllStylesCreatePainters() {
        let styles: [LoaderStyle] = [.circular, .dots, .pulse, .bars, .orbit, .ripple, .bounce, .wave, .flip, .fade]
        for style in styles {
            let painter = style.painter()
            XCTAssertNotNil(painter, "\(style) should create a painter")
        }
    }

    // MARK: - Loader struct

    func testLoaderDefaults() {
        let loader = Loader()
        XCTAssertEqual(loader.size, 32)
    }

    func testLoaderCustomValues() {
        let loader = Loader(.dots, color: .red, size: 48)
        XCTAssertEqual(loader.size, 48)
    }

    // MARK: - Mount

    func testMountProducesLoaderView() {
        let loader = Loader()
        let view = loader.makeRenderer().mount()
        XCTAssertTrue(view is LoaderView)
    }

    func testLoaderViewIntrinsicSize() {
        let loader = Loader(.circular, size: 64)
        let view = loader.makeRenderer().mount() as! LoaderView
        XCTAssertEqual(view.intrinsicContentSize.width, 64)
        XCTAssertEqual(view.intrinsicContentSize.height, 64)
    }

    func testLoaderViewSizeThatFits() {
        let loader = Loader(.circular, size: 40)
        let view = loader.makeRenderer().mount() as! LoaderView
        let size = view.sizeThatFits(CGSize(width: 200, height: 200))
        XCTAssertEqual(size.width, 40)
        XCTAssertEqual(size.height, 40)
    }

    func testLoaderViewIsTransparent() {
        let loader = Loader()
        let view = loader.makeRenderer().mount() as! LoaderView
        XCTAssertFalse(view.isOpaque)
        XCTAssertEqual(view.backgroundColor, .clear)
    }

    // MARK: - Update

    func testUpdateChangesStyle() {
        let renderer = LoaderRenderer(view: Loader(.circular, color: .red, size: 32))
        let view = renderer.mount() as! LoaderView
        XCTAssertEqual(view.duration, LoaderStyle.circular.duration)

        renderer.update(from: Loader(.dots, color: .blue, size: 48))
        XCTAssertEqual(view.duration, LoaderStyle.dots.duration)
        XCTAssertEqual(view.loaderSize, 48)
    }

    // MARK: - Painters produce output

    func testCircularPainterOutput() {
        XCTAssertTrue(painterProducesOutput(CircularPainter(), progress: 0.5))
    }

    func testDotsPainterOutput() {
        XCTAssertTrue(painterProducesOutput(DotsPainter(), progress: 0.5))
    }

    func testPulsePainterOutput() {
        XCTAssertTrue(painterProducesOutput(PulsePainter(), progress: 0.5))
    }

    func testBarsPainterOutput() {
        XCTAssertTrue(painterProducesOutput(BarsPainter(), progress: 0.5))
    }

    func testOrbitPainterOutput() {
        XCTAssertTrue(painterProducesOutput(OrbitPainter(), progress: 0.5))
    }

    func testRipplePainterOutput() {
        XCTAssertTrue(painterProducesOutput(RipplePainter(), progress: 0.5))
    }

    func testBouncePainterOutput() {
        XCTAssertTrue(painterProducesOutput(BouncePainter(), progress: 0.5))
    }

    func testWavePainterOutput() {
        XCTAssertTrue(painterProducesOutput(WavePainter(), progress: 0.5))
    }

    func testFlipPainterOutput() {
        XCTAssertTrue(painterProducesOutput(FlipPainter(), progress: 0.5))
    }

    func testFadePainterOutput() {
        XCTAssertTrue(painterProducesOutput(FadePainter(), progress: 0.5))
    }

    // MARK: - Painters at boundary progress values

    func testPaintersAtZero() {
        let painters: [any LoaderPainter] = [
            CircularPainter(), DotsPainter(), PulsePainter(), BarsPainter(), OrbitPainter(),
            RipplePainter(), BouncePainter(), WavePainter(), FlipPainter(), FadePainter()
        ]
        for painter in painters {
            XCTAssertTrue(painterProducesOutput(painter, progress: 0), "\(type(of: painter)) should produce output at t=0")
        }
    }

    func testPaintersAtOne() {
        let painters: [any LoaderPainter] = [
            CircularPainter(), DotsPainter(), PulsePainter(), BarsPainter(), OrbitPainter(),
            RipplePainter(), BouncePainter(), WavePainter(), FlipPainter(), FadePainter()
        ]
        for painter in painters {
            XCTAssertTrue(painterProducesOutput(painter, progress: 1), "\(type(of: painter)) should produce output at t=1")
        }
    }

    // MARK: - CGCanvas basics

    func testCanvasFillRectProducesPixels() {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.fillRect(Rect(x: 0, y: 0, width: 32, height: 32), color: .red)
        }
        XCTAssertTrue(hasNonClearPixels(image))
    }

    func testCanvasFillCircleProducesPixels() {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.fillCircle(center: Vec2(16, 16), radius: 10, color: .blue)
        }
        XCTAssertTrue(hasNonClearPixels(image))
    }

    func testCanvasClipRestrictsDrawing() {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.save()
            var clipPath = Path(); clipPath.addRect(Rect(x: 0, y: 0, width: 0, height: 0))
            canvas.clip(clipPath) // Clip to nothing
            canvas.fillRect(Rect(x: 0, y: 0, width: 32, height: 32), color: .red)
            canvas.restore()
        }
        XCTAssertFalse(hasNonClearPixels(image))
    }

    func testCanvasSaveRestoreTransform() {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.save()
            canvas.translate(100, 100) // shift off-screen
            canvas.restore() // undo translate
            canvas.fillRect(Rect(x: 0, y: 0, width: 32, height: 32), color: .red)
        }
        XCTAssertTrue(hasNonClearPixels(image))
    }

    func testCanvasTranslateShiftsDrawing() {
        let size = 32
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.save()
            canvas.translate(100, 100) // Shift everything off-screen
            canvas.fillRect(Rect(x: 0, y: 0, width: 10, height: 10), color: .red)
            canvas.restore()
        }
        XCTAssertFalse(hasNonClearPixels(image))
    }

    func testCanvasDrawWithOpacity() {
        let size = 32
        let full = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.fillRect(Rect(x: 0, y: 0, width: 32, height: 32), color: .red)
        }
        let half = UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in
            let canvas = CGCanvas(ctx.cgContext)
            canvas.fillRect(Rect(x: 0, y: 0, width: 32, height: 32), paint: Paint.color(.red).copy { $0.opacity = 0.5 })
        }
        // Both should have pixels
        XCTAssertTrue(hasNonClearPixels(full))
        XCTAssertTrue(hasNonClearPixels(half))
    }
}

#endif
