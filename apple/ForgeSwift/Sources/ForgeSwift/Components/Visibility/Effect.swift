#if canImport(UIKit)
import UIKit
import CoreImage

// MARK: - Effect

/// A chain of visual operations applied to a view without affecting
/// layout. Built with a fluent API:
///
///     view.effect { $0.scale(1.5).blur(8).opacity(0.5) }
///
// TODO: Metal shader filter support
// The .filter() pipeline currently uses CIFilter (snapshot → CIImage → process → CGImage).
// To support Metal shaders:
// 1. Add a shared MTLDevice + MTLCommandQueue (MetalContext singleton)
// 2. Add a .metalFilter(shader:configure:) method
// 3. Same pipeline: CIImage → MTLTexture → shader → MTLTexture → CIImage

/// A chain of visual operations (scale, rotate, blur, etc.) applied without affecting layout.
public final class Effect {
    private(set) var operations: [EffectOp] = []

    public init() {}

    @discardableResult
    public func scale(_ s: Double, anchor: Alignment = .center) -> Effect {
        scale(s, s, anchor: anchor)
    }

    @discardableResult
    public func scale(_ x: Double, _ y: Double, anchor: Alignment = .center) -> Effect {
        operations.append(.scale(x: x, y: y, anchor: anchor)); return self
    }

    @discardableResult
    public func rotate(_ angle: Double, anchor: Alignment = .center, perspective: Double? = nil) -> Effect {
        operations.append(.rotate(angle: angle, anchor: anchor, perspective: perspective)); return self
    }

    @discardableResult
    public func opacity(_ value: Double) -> Effect {
        operations.append(.opacity(value)); return self
    }

    @discardableResult
    public func offset(_ x: Double = 0, _ y: Double = 0, fractional: Bool = false) -> Effect {
        operations.append(.offset(x: x, y: y, fractional: fractional)); return self
    }

    @discardableResult
    public func blur(_ radius: Double) -> Effect {
        operations.append(.blur(radius)); return self
    }

    @discardableResult
    public func filter(_ process: @escaping @MainActor (CIImage) -> CIImage?) -> Effect {
        operations.append(.filter(process)); return self
    }

    @discardableResult
    public func clip(_ shape: AnyShape) -> Effect {
        operations.append(.clip(shape)); return self
    }
}

// MARK: - EffectOp

/// Individual visual operation within an Effect chain.
enum EffectOp {
    case scale(x: Double, y: Double, anchor: Alignment)
    case rotate(angle: Double, anchor: Alignment, perspective: Double?)
    case opacity(Double)
    case offset(x: Double, y: Double, fractional: Bool)
    case blur(Double)
    case filter(@MainActor (CIImage) -> CIImage?)
    case clip(AnyShape)

    var isFilter: Bool {
        switch self {
        case .blur, .filter: true
        default: false
        }
    }

    var isTransform: Bool {
        switch self {
        case .scale, .rotate, .offset: true
        default: false
        }
    }
}

// MARK: - EffectView

/// Proxy view that applies an Effect to its child.
struct EffectView: ProxyView {
    let child: any View
    let effect: Effect

    func makeRenderer() -> ProxyRenderer {
        EffectRenderer(view: self)
    }
}

// MARK: - EffectRenderer

final class EffectRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var hostView: EffectHostView?
    private var view: EffectView

    init(view: EffectView) {
        self.view = view
    }

    func mount() -> PlatformView {
        let host = EffectHostView()
        self.hostView = host
        host.clipsToBounds = false
        host.operations = view.effect.operations
        return host
    }

    func update(from newView: any View) {
        guard let ev = newView as? EffectView, let host = hostView else { return }
        let oldOps = view.effect.operations
        view = ev

        host.childPlatform = host.subviews.first
        host.invalidateSnapshot()
        host.operations = ev.effect.operations
    }
}

// MARK: - EffectHostView

/// Three-stage cached pipeline:
///
/// 1. **Snapshot** — child rendered at identity. Cached as CIImage.
///    Invalidated when child content changes.
/// 2. **Filter** — blur/CIFilter applied to snapshot. Cached as CGImage.
///    Invalidated when filter ops change or snapshot invalidates.
/// 3. **Transform** — scale/rotate/offset applied to the output layer.
///    Just layer properties, no re-render.
///
/// Opacity and clip are applied to the output layer directly.
/// When no filters are active, transforms go on the child's layer
/// (no snapshot needed).
final class EffectHostView: UIView {
    weak var childPlatform: UIView?

    private var outputLayer: CALayer?

    // Cache
    private var cachedSnapshot: CIImage?
    private var cachedFilterResult: CGImage?
    private var cachedFilterOps: [ObjectIdentifier] = [] // identity tokens for filter ops
    private var snapshotSize: CGSize = .zero

    private static let ciContext = CIContext(options: [
        .useSoftwareRenderer: false,
        .cacheIntermediates: false,
    ])

    var operations: [EffectOp] = [] {
        didSet { setNeedsLayout() }
    }

    func invalidateSnapshot() {
        cachedSnapshot = nil
        cachedFilterResult = nil
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        (childPlatform ?? subviews.first)?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        (childPlatform ?? subviews.first)?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if childPlatform == nil { childPlatform = subviews.first }
        guard let child = childPlatform else { return }

        // Reset
        child.layer.transform = CATransform3DIdentity
        child.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        child.layer.opacity = 1
        child.layer.mask = nil
        child.isHidden = false
        child.frame = bounds
        outputLayer?.removeFromSuperlayer()
        outputLayer = nil

        if bounds.size != snapshotSize {
            invalidateSnapshot()
            snapshotSize = bounds.size
        }

        if operations.contains(where: { $0.isFilter }) {
            applyWithFilters(child: child)
        } else {
            applyDirect(child: child)
        }
    }

    // MARK: - Direct path (no filters)

    private func applyDirect(child: UIView) {
        let (transform, anchor, opacity, clipShape) = buildLayerProps()
        child.layer.anchorPoint = anchor
        child.layer.transform = transform
        if let opacity { child.layer.opacity = Float(opacity) }
        if let shape = clipShape {
            let mask = CAShapeLayer()
            mask.frame = child.bounds
            mask.path = shape.path(in: Rect(child.bounds)).cgPath
            child.layer.mask = mask
        }
    }

    // MARK: - Filter path (cached pipeline)

    private func applyWithFilters(child: UIView) {
        guard bounds.width > 0, bounds.height > 0 else { return }

        let scale = UIScreen.main.scale
        let filterOpsChanged = hasFilterOpsChanged()

        // Stage 1: Snapshot (reuse if valid)
        if cachedSnapshot == nil {
            cachedSnapshot = captureSnapshot(of: child, scale: scale)
            cachedFilterResult = nil // snapshot changed → filter invalid
        }

        // Stage 2: Filter (reuse if valid)
        if cachedFilterResult == nil || filterOpsChanged {
            if let snapshot = cachedSnapshot {
                cachedFilterResult = applyFilterChain(to: snapshot, scale: scale)
                updateFilterOpsIdentity()
            }
        }

        // Stage 3: Display with transforms
        guard let result = cachedFilterResult else { return }
        let fl = makeOutputLayer(cgImage: result, scale: scale)
        applyTransformsToLayer(fl)
        layer.addSublayer(fl)
        outputLayer = fl
        child.isHidden = true
    }

    private func captureSnapshot(of child: UIView, scale: CGFloat) -> CIImage? {
        let savedClips = disableClipping(in: child)
        defer { restoreClipping(savedClips) }

        let renderer = UIGraphicsImageRenderer(
            size: bounds.size,
            format: {
                let f = UIGraphicsImageRendererFormat()
                f.scale = scale
                return f
            }()
        )
        let image = renderer.image { ctx in
            child.layer.render(in: ctx.cgContext)
        }
        return CIImage(image: image)
    }

    private func applyFilterChain(to input: CIImage, scale: CGFloat) -> CGImage? {
        var ciImage = input
        for op in operations {
            switch op {
            case .blur(let radius) where radius > 0:
                let f = CIFilter(name: "CIGaussianBlur")!
                f.setValue(ciImage, forKey: kCIInputImageKey)
                f.setValue(radius * Double(scale), forKey: kCIInputRadiusKey)
                if let out = f.outputImage { ciImage = out }
            case .filter(let process):
                if let out = process(ciImage) { ciImage = out }
            default: break
            }
        }
        return Self.ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private func makeOutputLayer(cgImage: CGImage, scale: CGFloat) -> CALayer {
        let fl = CALayer()
        fl.contents = cgImage
        fl.contentsScale = scale
        fl.contentsGravity = .center

        // The filter output extent may differ from input (blur expands).
        // Center the output on the host's bounds.
        let w = CGFloat(cgImage.width) / scale
        let h = CGFloat(cgImage.height) / scale
        fl.frame = CGRect(
            x: (bounds.width - w) / 2,
            y: (bounds.height - h) / 2,
            width: w,
            height: h
        )
        return fl
    }

    private func applyTransformsToLayer(_ fl: CALayer) {
        let (transform, anchor, opacity, clipShape) = buildLayerProps()
        fl.anchorPoint = anchor
        fl.transform = transform
        if let opacity { fl.opacity = Float(opacity) }
        if let shape = clipShape {
            let mask = CAShapeLayer()
            mask.frame = fl.bounds
            mask.path = shape.path(in: Rect(fl.bounds)).cgPath
            fl.mask = mask
        }
    }

    // MARK: - Transform builder

    /// Build the final transform, anchor, opacity, and clip from
    /// the operations list. Scale and rotate compose around the anchor.
    /// Offset is applied in parent space (independent of rotation).
    private func buildLayerProps() -> (
        transform: CATransform3D,
        anchor: CGPoint,
        opacity: Double?,
        clip: AnyShape?
    ) {
        var scaleRotate = CATransform3DIdentity
        var anchor = CGPoint(x: 0.5, y: 0.5)
        var offsetX = 0.0
        var offsetY = 0.0
        var opacity: Double?
        var clipShape: AnyShape?

        for op in operations {
            switch op {
            case .scale(let x, let y, let a):
                anchor = a.anchorPoint
                scaleRotate = CATransform3DScale(scaleRotate, x, y, 1)
            case .rotate(let angle, let a, let perspective):
                anchor = a.anchorPoint
                if let p = perspective { scaleRotate.m34 = -p }
                scaleRotate = CATransform3DRotate(scaleRotate, angle, 0, 0, 1)
            case .offset(let x, let y, let fractional):
                offsetX += fractional ? x * Double(bounds.width) : x
                offsetY += fractional ? y * Double(bounds.height) : y
            case .opacity(let a):
                opacity = a
            case .clip(let shape):
                clipShape = shape
            default: break
            }
        }

        // Compose: offset in parent space, then scale+rotate around anchor
        // CATransform3DConcat(A, B) = A * B, applied as B(A(point))
        // We want: first scaleRotate around anchor, then offset in parent space
        // = offset * scaleRotate
        let offset = CATransform3DMakeTranslation(offsetX, offsetY, 0)
        let transform = CATransform3DConcat(scaleRotate, offset)

        return (transform, anchor, opacity, clipShape)
    }

    // MARK: - Filter ops change detection

    /// Simple identity check: did the filter operations change since
    /// last render? Uses the blur radius values as identity tokens.
    private var lastFilterSignature: [Double] = []

    private func hasFilterOpsChanged() -> Bool {
        let sig = filterSignature()
        return sig != lastFilterSignature
    }

    private func updateFilterOpsIdentity() {
        lastFilterSignature = filterSignature()
    }

    private func filterSignature() -> [Double] {
        operations.compactMap { op in
            switch op {
            case .blur(let r): r
            default: nil
            }
        }
    }

    // MARK: - Clipping helpers

    private func disableClipping(in view: UIView) -> [UIView] {
        var clipped: [UIView] = []
        func walk(_ v: UIView) {
            if v.clipsToBounds {
                clipped.append(v)
                v.clipsToBounds = false
            }
            for sub in v.subviews { walk(sub) }
        }
        walk(view)
        return clipped
    }

    private func restoreClipping(_ views: [UIView]) {
        for v in views { v.clipsToBounds = true }
    }
}

// MARK: - Alignment → anchor point

extension Alignment {
    var anchorPoint: CGPoint {
        CGPoint(x: (x + 1) / 2, y: (y + 1) / 2)
    }
}

// MARK: - View modifier

public extension View {
    /// Apply a chain of visual effects without affecting layout.
    ///
    ///     view.effect { $0.scale(1.5).blur(8).opacity(0.5) }
    func effect(_ build: (Effect) -> Effect) -> some View {
        EffectView(child: self, effect: build(Effect()))
    }
}

#endif
