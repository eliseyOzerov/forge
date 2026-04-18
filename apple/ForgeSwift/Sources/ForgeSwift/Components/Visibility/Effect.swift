#if canImport(UIKit)
import UIKit
import CoreImage

// MARK: - EffectView

/// Wraps a child and applies visual-only effects to its platform view.
/// No layout impact — the child is measured and positioned normally,
/// then effects are applied after layout.
struct EffectView: LeafView {
    let child: any View
    let effect: VisualEffect

    func makeRenderer() -> Renderer {
        EffectRenderer(view: self)
    }
}

// MARK: - VisualEffect

// TODO: Metal shader filter support
// The .filter() pipeline currently uses CIFilter (snapshot → CIImage → process → CALayer).
// To support Metal shaders with the same pipeline:
// 1. Add a shared MTLDevice + MTLCommandQueue on ForgeSwift (e.g. a MetalContext singleton)
// 2. Compile .metal shader files from the SDK or app bundle into MTLLibrary
// 3. Add a .metalFilter(shader:configure:) modifier that:
//    a. Converts CIImage → MTLTexture via CIContext.render(_:to:)
//    b. Encodes a compute pass with the shader pipeline + input/output textures
//    c. Converts output MTLTexture → CIImage via CIImage(mtlTexture:)
// 4. The existing applyFilter(to:filter:) method works unchanged — Metal
//    is just a different implementation of the (CIImage) -> CIImage? closure.

enum VisualEffect {
    case scale(x: Double, y: Double, anchor: Alignment)
    case rotate(angle: Double, anchor: Alignment, perspective: Double?)
    case opacity(Double)
    case offset(x: Double, y: Double, fractional: Bool)
    case blur(Double)
    case filter(@MainActor (CIImage) -> CIImage?)
    case clip(Shape)
}

// MARK: - EffectRenderer

final class EffectRenderer: Renderer {
    private weak var hostView: EffectHostView?
    private var view: EffectView

    init(view: EffectView) {
        self.view = view
    }

    func mount() -> PlatformView {
        let host = EffectHostView()
        self.hostView = host
        host.clipsToBounds = false

        let childPlatform = host.resolver.mount(view.child)
        host.childPlatform = childPlatform
        host.addSubview(childPlatform)
        host.effect = view.effect
        return host
    }

    func update(from newView: any View) {
        guard let ev = newView as? EffectView, let host = hostView else { return }
        view = ev

        if let existing = host.resolver.rootNode, existing.canUpdate(to: ev.child) {
            existing.update(from: ev.child)
        } else {
            host.subviews.forEach { $0.removeFromSuperview() }
            let childPlatform = host.resolver.mount(ev.child)
            host.childPlatform = childPlatform
            host.addSubview(childPlatform)
        }

        host.effect = ev.effect
    }
}

// MARK: - EffectHostView

/// Host view that manages two rendering paths:
///
/// **Direct path** (scale, rotate, offset, opacity, clip):
/// Transforms applied directly to the child's layer after layout.
///
/// **Filter path** (blur, future Metal shaders):
/// Child is snapshotted, processed through a filter pipeline,
/// and the result is displayed in a sublayer. The child stays in
/// the hierarchy (opacity 0) for hit testing and interaction.
/// The filter sublayer receives transforms instead.
final class EffectHostView: UIView {
    let resolver = Resolver()
    weak var childPlatform: UIView?

    /// Sublayer that displays filtered content. Sits above the child
    /// in the layer hierarchy. Only active when a filter effect is applied.
    private var filterLayer: CALayer?

    /// Shared CIContext for GPU-accelerated filter processing.
    /// Reused across frames to avoid setup cost.
    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false,
    ])

    var effect: VisualEffect = .opacity(1) {
        didSet { setNeedsLayout() }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        childPlatform?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        childPlatform?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let child = childPlatform else { return }

        // Reset child to identity for clean frame assignment
        child.layer.transform = CATransform3DIdentity
        child.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        child.layer.opacity = 1
        child.layer.mask = nil
        child.frame = bounds

        // Clear filter layer
        filterLayer?.removeFromSuperlayer()
        filterLayer = nil

        switch effect {
        case .scale(let x, let y, let anchor):
            child.layer.anchorPoint = anchor.anchorPoint
            child.layer.transform = CATransform3DMakeScale(x, y, 1)

        case .rotate(let angle, let anchor, let perspective):
            child.layer.anchorPoint = anchor.anchorPoint
            var t = CATransform3DIdentity
            if let p = perspective { t.m34 = -p }
            t = CATransform3DRotate(t, angle, 0, 0, 1)
            child.layer.transform = t

        case .opacity(let alpha):
            child.layer.opacity = Float(alpha)

        case .offset(let x, let y, let fractional):
            if fractional {
                let tx = x * Double(bounds.width)
                let ty = y * Double(bounds.height)
                child.layer.transform = CATransform3DMakeTranslation(tx, ty, 0)
            } else {
                child.layer.transform = CATransform3DMakeTranslation(x, y, 0)
            }

        case .blur(let radius):
            if radius > 0 {
                applyFilter(to: child) { input in
                    let f = CIFilter(name: "CIGaussianBlur")!
                    f.setValue(input, forKey: kCIInputImageKey)
                    f.setValue(radius, forKey: kCIInputRadiusKey)
                    return f.outputImage
                }
            }

        case .filter(let process):
            applyFilter(to: child, filter: process)

        case .clip(let shape):
            let mask = CAShapeLayer()
            mask.frame = child.bounds
            mask.path = shape.resolve(in: Rect(child.bounds)).cgPath
            child.layer.mask = mask
        }
    }

    // MARK: - Filter pipeline

    /// Snapshot the child, process through a filter, display result
    /// in a sublayer. The child becomes invisible but stays interactive.
    ///
    /// The filter closure receives a CIImage and returns a processed
    /// CIImage. This is the plug point for CIFilter chains or future
    /// Metal shader pipelines.
    private func applyFilter(
        to child: UIView,
        filter: (CIImage) -> CIImage?
    ) {
        let size = child.bounds.size
        guard size.width > 0, size.height > 0 else { return }

        let scale = UIScreen.main.scale

        // 1. Snapshot child's layer
        let renderer = UIGraphicsImageRenderer(
            size: size,
            format: {
                let f = UIGraphicsImageRendererFormat()
                f.scale = scale
                return f
            }()
        )
        let snapshot = renderer.image { ctx in
            child.layer.render(in: ctx.cgContext)
        }

        guard let ciInput = CIImage(image: snapshot),
              let ciOutput = filter(ciInput) else { return }

        // 2. Render the processed image. The output may be larger than
        //    the input (e.g. blur expands edges). We render the full
        //    output extent and position the layer to account for the
        //    expansion.
        let inputExtent = ciInput.extent
        let outputExtent = ciOutput.extent
        guard let cgImage = Self.ciContext.createCGImage(ciOutput, from: outputExtent) else { return }

        // 3. Display in a sublayer
        let fl = CALayer()
        fl.contents = cgImage
        fl.contentsScale = scale
        fl.contentsGravity = .center

        // Position: account for the expansion (blur extends beyond original bounds)
        let dx = outputExtent.origin.x - inputExtent.origin.x
        let dy = outputExtent.origin.y - inputExtent.origin.y
        fl.frame = CGRect(
            x: dx / scale,
            y: -dy / scale - (outputExtent.height - inputExtent.height) / scale,
            width: outputExtent.width / scale,
            height: outputExtent.height / scale
        )

        layer.addSublayer(fl)
        filterLayer = fl

        // 4. Hide child visually, keep for interaction
        child.layer.opacity = 0
    }
}

// MARK: - Alignment → anchor point

extension Alignment {
    var anchorPoint: CGPoint {
        CGPoint(x: (x + 1) / 2, y: (y + 1) / 2)
    }
}

// MARK: - View modifiers

public extension View {
    func scale(_ s: Double, anchor: Alignment = .center) -> some View {
        scale(s, s, anchor: anchor)
    }

    func scale(_ x: Double, _ y: Double, anchor: Alignment = .center) -> some View {
        EffectView(child: self, effect: .scale(x: x, y: y, anchor: anchor))
    }

    func rotate(_ angle: Double, anchor: Alignment = .center, perspective: Double? = nil) -> some View {
        EffectView(child: self, effect: .rotate(angle: angle, anchor: anchor, perspective: perspective))
    }

    func opacity(_ value: Double) -> some View {
        EffectView(child: self, effect: .opacity(value))
    }

    func offset(_ x: Double = 0, _ y: Double = 0, fractional: Bool = false) -> some View {
        EffectView(child: self, effect: .offset(x: x, y: y, fractional: fractional))
    }

    func blur(_ radius: Double) -> some View {
        EffectView(child: self, effect: .blur(radius))
    }

    /// Apply an arbitrary CIFilter chain to this view's rendered content.
    func filter(_ process: @escaping @MainActor (CIImage) -> CIImage?) -> some View {
        EffectView(child: self, effect: .filter(process))
    }

    func clip(_ shape: Shape) -> some View {
        EffectView(child: self, effect: .clip(shape))
    }
}

#endif
