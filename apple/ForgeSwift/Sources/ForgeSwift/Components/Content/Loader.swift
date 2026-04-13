import Foundation

// MARK: - LoaderStyle

public enum LoaderStyle: Sendable {
    case circular
    case dots
    case pulse
    case bars
    case orbit
    case ripple
    case bounce
    case wave
    case flip
    case fade

    var duration: Double {
        switch self {
        case .circular: 1.2
        case .dots:     1.0
        case .pulse:    1.4
        case .bars:     1.0
        case .orbit:    1.5
        case .ripple:   1.8
        case .bounce:   0.8
        case .wave:     1.2
        case .flip:     1.2
        case .fade:     1.2
        }
    }

    func painter() -> any LoaderPainter {
        switch self {
        case .circular: CircularPainter()
        case .dots:     DotsPainter()
        case .pulse:    PulsePainter()
        case .bars:     BarsPainter()
        case .orbit:    OrbitPainter()
        case .ripple:   RipplePainter()
        case .bounce:   BouncePainter()
        case .wave:     WavePainter()
        case .flip:     FlipPainter()
        case .fade:     FadePainter()
        }
    }
}

// MARK: - LoaderPainter

/// A function of (t, canvas, bounds, color) that paints one animation frame.
/// t cycles 0→1 over the loader's duration. All math is platform-agnostic.
public protocol LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color)
}

// MARK: - Loader

public struct Loader: LeafView {
    public let style: LoaderStyle
    public let color: Color
    public let size: Double

    public init(_ style: LoaderStyle = .circular, color: Color = .blue, size: Double = 32) {
        self.style = style
        self.color = color
        self.size = size
    }

    public func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        return LoaderRenderer(style: style, color: color, size: size)
        #else
        fatalError("Loader not implemented on this platform")
        #endif
    }
}

// MARK: - Painters

struct CircularPainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let center = Vec2(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        let radius = min(bounds.width, bounds.height) / 2 - 2
        let strokeWidth = min(bounds.width, bounds.height) * 0.08

        // Track
        canvas.strokeCircle(center: center, radius: radius, color: color.withAlpha(0.15), width: strokeWidth)

        // Spinning arc with varying sweep
        let startAngle = t * .pi * 2 * 3
        let sweepPhase = sin(t * .pi * 2)
        let sweep = Double.pi * (0.3 + 0.7 * (sweepPhase * 0.5 + 0.5))

        canvas.strokeArc(center: center, radius: radius, start: startAngle, sweep: sweep, color: color, width: strokeWidth, cap: .round)
    }
}

struct DotsPainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let count = 3
        let dotRadius = min(bounds.width, bounds.height) * 0.1
        let spacing = bounds.width / Double(count + 1)
        let cy = bounds.y + bounds.height / 2

        for i in 0..<count {
            let delay = Double(i) / Double(count)
            let phase = fmod(t - delay + 1, 1.0)
            let scale = 0.5 + 0.5 * sin(phase * .pi)

            canvas.fillCircle(
                center: Vec2(bounds.x + spacing * Double(i + 1), cy),
                radius: dotRadius * scale,
                color: color.withAlpha(0.4 + 0.6 * scale)
            )
        }
    }
}

struct PulsePainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let center = Vec2(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        let maxRadius = min(bounds.width, bounds.height) / 2
        let phase = sin(t * .pi * 2) * 0.5 + 0.5
        let radius = maxRadius * (0.4 + 0.6 * phase)
        let opacity = 0.3 + 0.7 * phase

        canvas.fillCircle(center: center, radius: radius, color: color.withAlpha(opacity))
    }
}

struct BarsPainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let count = 4
        let barWidth = bounds.width / Double(count * 2 - 1)
        let maxHeight = bounds.height * 0.8
        let minHeight = bounds.height * 0.2

        for i in 0..<count {
            let delay = Double(i) / Double(count)
            let phase = fmod(t - delay + 1, 1.0)
            let h = minHeight + (maxHeight - minHeight) * sin(phase * .pi)

            let left = bounds.x + Double(i) * barWidth * 2
            let top = bounds.y + (bounds.height - h) / 2

            canvas.fillRoundedRect(
                Rect(x: left, y: top, width: barWidth, height: h),
                radius: barWidth / 2,
                color: color
            )
        }
    }
}

struct OrbitPainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let center = Vec2(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        let orbitRadius = min(bounds.width, bounds.height) * 0.32
        let dotRadius = min(bounds.width, bounds.height) * 0.07

        // Track
        canvas.strokeCircle(center: center, radius: orbitRadius, color: color.withAlpha(0.1), width: 1)

        let count = 3
        for i in 0..<count {
            let angle = t * .pi * 2 + Double(i) * .pi * 2 / Double(count)
            let x = center.x + cos(angle) * orbitRadius
            let y = center.y + sin(angle) * orbitRadius
            let opacity = 0.4 + 0.6 * (Double(i + 1) / Double(count))
            let scale = 0.6 + 0.4 * (Double(i + 1) / Double(count))

            canvas.fillCircle(center: Vec2(x, y), radius: dotRadius * scale, color: color.withAlpha(opacity))
        }
    }
}

struct RipplePainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let center = Vec2(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        let maxRadius = min(bounds.width, bounds.height) / 2
        let count = 3

        for i in 0..<count {
            let delay = Double(i) / Double(count)
            let phase = fmod(t + delay, 1.0)
            let radius = maxRadius * phase
            let opacity = max(0, (1.0 - phase) * 0.6)

            canvas.strokeCircle(center: center, radius: radius, color: color.withAlpha(opacity), width: 2)
        }
    }
}

struct BouncePainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let cx = bounds.x + bounds.width / 2
        let dotRadius = min(bounds.width, bounds.height) * 0.12
        let bounceHeight = bounds.height * 0.6

        // Shadow
        let shadowScale = 0.3 + 0.7 * sin(t * .pi)
        let shadowRect = Rect(
            x: cx - dotRadius * shadowScale,
            y: bounds.y + bounds.height * 0.85 - dotRadius * 0.2 * shadowScale,
            width: dotRadius * 2 * shadowScale,
            height: dotRadius * 0.4 * shadowScale
        )
        canvas.fillEllipse(in: shadowRect, color: color.withAlpha(0.15 * shadowScale))

        // Ball with squash/stretch
        let bounce = abs(sin(t * .pi))
        let y = bounds.y + bounds.height * 0.8 - bounceHeight * bounce
        let stretch = 1.0 + 0.2 * bounce

        let ballRect = Rect(
            x: cx - dotRadius / stretch,
            y: y - dotRadius * stretch,
            width: dotRadius * 2 / stretch,
            height: dotRadius * 2 * stretch
        )
        canvas.fillEllipse(in: ballRect, color: color)
    }
}

struct WavePainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let count = 5
        let dotRadius = min(bounds.width, bounds.height) * 0.07
        let spacing = bounds.width / Double(count + 1)
        let amplitude = bounds.height * 0.25
        let cy = bounds.y + bounds.height / 2

        for i in 0..<count {
            let phase = t * .pi * 2 - Double(i) * 0.5
            let y = cy + sin(phase) * amplitude

            canvas.fillCircle(center: Vec2(bounds.x + spacing * Double(i + 1), y), radius: dotRadius, color: color)
        }
    }
}

struct FlipPainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let halfSize = min(bounds.width, bounds.height) * 0.3
        let radius = min(bounds.width, bounds.height) * 0.06

        // Simulate Y-axis rotation with scaleX
        let angle = t * .pi * 2
        let scaleX = max(0.05, abs(cos(angle)))

        canvas.save()
        canvas.translate(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        canvas.scale(scaleX, 1.0)
        canvas.rotate(t * .pi)

        let rect = Rect(x: -halfSize, y: -halfSize, width: halfSize * 2, height: halfSize * 2)
        canvas.fillRoundedRect(rect, radius: radius, color: color.withAlpha(0.3 + 0.7 * scaleX))

        canvas.restore()
    }
}

struct FadePainter: LoaderPainter {
    func paint(on canvas: Canvas, progress t: Double, bounds: Rect, color: Color) {
        let center = Vec2(bounds.x + bounds.width / 2, bounds.y + bounds.height / 2)
        let orbitRadius = min(bounds.width, bounds.height) * 0.34
        let dotRadius = min(bounds.width, bounds.height) * 0.07
        let count = 8

        for i in 0..<count {
            let angle = Double(i) / Double(count) * .pi * 2 - .pi / 2
            let x = center.x + cos(angle) * orbitRadius
            let y = center.y + sin(angle) * orbitRadius

            let active = fmod(t * Double(count), Double(count))
            let distance = fmod(Double(i) - active + Double(count), Double(count)) / Double(count)
            let opacity = max(0.15, 1.0 - distance)

            canvas.fillCircle(center: Vec2(x, y), radius: dotRadius, color: color.withAlpha(opacity))
        }
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class LoaderRenderer: Renderer {
    let style: LoaderStyle
    let color: Color
    let size: Double

    init(style: LoaderStyle, color: Color, size: Double) {
        self.style = style
        self.color = color
        self.size = size
    }

    func mount() -> PlatformView {
        let view = LoaderView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? LoaderView else { return }
        apply(to: view)
    }

    private func apply(to view: LoaderView) {
        view.painter = style.painter()
        view.loaderColor = color
        view.loaderSize = size
        view.duration = style.duration
        view.isOpaque = false
        view.backgroundColor = .clear
        view.invalidateIntrinsicContentSize()
        view.setNeedsDisplay()
    }
}

final class LoaderView: UIView {
    var painter: (any LoaderPainter) = CircularPainter()
    var loaderColor: Color = .blue
    var loaderSize: Double = 32
    var duration: Double = 1.2

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private(set) var progress: Double = 0

    override var intrinsicContentSize: CGSize {
        CGSize(width: loaderSize, height: loaderSize)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: loaderSize, height: loaderSize)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { startAnimation() }
        else { stopAnimation() }
    }

    private func startAnimation() {
        guard displayLink == nil else { return }
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let elapsed = CACurrentMediaTime() - startTime
        progress = fmod(elapsed, duration) / duration
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let canvas = CGCanvas(ctx)
        let bounds = Rect(x: 0, y: 0, width: Double(rect.width), height: Double(rect.height))
        painter.paint(on: canvas, progress: progress, bounds: bounds, color: loaderColor)
    }

    override func removeFromSuperview() {
        stopAnimation()
        super.removeFromSuperview()
    }
}

#endif
