#if canImport(UIKit)
import UIKit
import CoreImage

// MARK: - EffectOp

@MainActor public protocol EffectOp {
    /// Apply this op to a UIView's layer.
    func apply(to view: UIView)
    /// Whether this op produces pixel data (snapshot/blur/filter).
    var isImageOp: Bool { get }
    /// Value equality for diffing.
    func isEqual(to other: any EffectOp) -> Bool
}

extension EffectOp {
    public var isImageOp: Bool { false }
}

// MARK: - Layer ops (cheap, just layer properties)

public struct ScaleOp: EffectOp, Equatable {
    public let x, y: Double
    public let anchor: Alignment

    public func apply(to view: UIView) {
        view.layer.anchorPoint = anchor.anchorPoint
        view.layer.transform = CATransform3DScale(view.layer.transform, x, y, 1)
    }

    public func isEqual(to other: any EffectOp) -> Bool { (other as? Self) == self }
}

public struct RotateOp: EffectOp, Equatable {
    public let angle: Double
    public let anchor: Alignment
    public let perspective: Double?

    public func apply(to view: UIView) {
        view.layer.anchorPoint = anchor.anchorPoint
        if let p = perspective { view.layer.transform.m34 = -p }
        view.layer.transform = CATransform3DRotate(view.layer.transform, angle, 0, 0, 1)
    }

    public func isEqual(to other: any EffectOp) -> Bool { (other as? Self) == self }
}

public struct OpacityOp: EffectOp, Equatable {
    public let value: Double

    public func apply(to view: UIView) {
        view.layer.opacity = Float(value)
    }

    public func isEqual(to other: any EffectOp) -> Bool { (other as? Self) == self }
}

public struct OffsetOp: EffectOp, Equatable {
    public let x, y: Double
    public let fractional: Bool

    public func apply(to view: UIView) {
        let tx = fractional ? x * Double(view.superview?.bounds.width ?? 0) : x
        let ty = fractional ? y * Double(view.superview?.bounds.height ?? 0) : y
        let t = CATransform3DMakeTranslation(tx, ty, 0)
        view.layer.transform = CATransform3DConcat(view.layer.transform, t)
    }

    public func isEqual(to other: any EffectOp) -> Bool { (other as? Self) == self }
}

@MainActor public struct ClipOp: EffectOp {
    public let shape: Shape

    public func apply(to view: UIView) {
        let mask = CAShapeLayer()
        mask.frame = view.bounds
        mask.path = shape.resolve(in: Rect(view.bounds)).cgPath
        view.layer.mask = mask
    }

    public func isEqual(to other: any EffectOp) -> Bool { false }
}

// MARK: - Image ops (expensive, cached)

public struct SnapshotOp: EffectOp, Equatable {
    public var isImageOp: Bool { true }
    public func apply(to view: UIView) {} // handled by host
    public func isEqual(to other: any EffectOp) -> Bool { other is SnapshotOp }
}

public struct BlurOp: EffectOp, Equatable {
    public let radius: Double
    public var isImageOp: Bool { true }

    public func apply(to view: UIView) {} // handled by host

    /// Apply blur to a CIImage.
    func process(_ input: CIImage) -> CIImage? {
        guard radius > 0 else { return input }
        let f = CIFilter(name: "CIGaussianBlur")!
        f.setValue(input, forKey: kCIInputImageKey)
        f.setValue(radius, forKey: kCIInputRadiusKey)
        return f.outputImage
    }

    public func isEqual(to other: any EffectOp) -> Bool { (other as? Self) == self }
}

@MainActor public struct FilterOp: EffectOp {
    public let process: @MainActor (CIImage) -> CIImage?
    public var isImageOp: Bool { true }

    public func apply(to view: UIView) {} // handled by host
    public func isEqual(to other: any EffectOp) -> Bool { false }
}

// MARK: - Effect (builder)

@MainActor public final class Effect {
    private(set) var operations: [any EffectOp] = []

    public init() {}

    @discardableResult
    public func scale(_ s: Double, anchor: Alignment = .center) -> Effect {
        scale(s, s, anchor: anchor)
    }

    @discardableResult
    public func scale(_ x: Double, _ y: Double, anchor: Alignment = .center) -> Effect {
        operations.append(ScaleOp(x: x, y: y, anchor: anchor)); return self
    }

    @discardableResult
    public func rotate(_ angle: Double, anchor: Alignment = .center, perspective: Double? = nil) -> Effect {
        operations.append(RotateOp(angle: angle, anchor: anchor, perspective: perspective)); return self
    }

    @discardableResult
    public func opacity(_ value: Double) -> Effect {
        operations.append(OpacityOp(value: value)); return self
    }

    @discardableResult
    public func offset(_ x: Double = 0, _ y: Double = 0, fractional: Bool = false) -> Effect {
        operations.append(OffsetOp(x: x, y: y, fractional: fractional)); return self
    }

    @discardableResult
    public func snapshot() -> Effect {
        operations.append(SnapshotOp()); return self
    }

    @discardableResult
    public func blur(_ radius: Double) -> Effect {
        operations.append(BlurOp(radius: radius)); return self
    }

    @discardableResult
    public func filter(_ process: @escaping @MainActor (CIImage) -> CIImage?) -> Effect {
        operations.append(FilterOp(process: process)); return self
    }

    @discardableResult
    public func clip(_ shape: Shape) -> Effect {
        operations.append(ClipOp(shape: shape)); return self
    }
}

// MARK: - EffectView

struct EffectView: LeafView {
    let child: any View
    let effect: Effect

    func makeRenderer() -> Renderer {
        EffectRenderer(view: self)
    }
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
        host.update(ops: view.effect.operations, childChanged: true)
        return host
    }

    func update(from newView: any View) {
        guard let ev = newView as? EffectView, let host = hostView else { return }
        view = ev

        var childChanged = false
        if let existing = host.resolver.rootNode, existing.canUpdate(to: ev.child) {
            existing.update(from: ev.child)
        } else {
            host.subviews.forEach { $0.removeFromSuperview() }
            let childPlatform = host.resolver.mount(ev.child)
            host.childPlatform = childPlatform
            host.addSubview(childPlatform)
            childChanged = true
        }
        host.update(ops: ev.effect.operations, childChanged: childChanged)
    }
}

// MARK: - EffectHostView

final class EffectHostView: UIView {
    let resolver = Resolver()
    weak var childPlatform: UIView?

    private var ops: [any EffectOp] = []
    private var filterLayer: CALayer?

    /// Cached CIImage results keyed by op index.
    /// Each image op stores its output here.
    private var imageCache: [Int: CIImage] = [:]

    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    func update(ops newOps: [any EffectOp], childChanged: Bool) {
        // Find first changed op
        let firstChange: Int
        if childChanged {
            imageCache.removeAll()
            firstChange = 0
        } else {
            var i = 0
            while i < min(ops.count, newOps.count) {
                if !ops[i].isEqual(to: newOps[i]) { break }
                i += 1
            }
            if i == ops.count && i == newOps.count { return }
            firstChange = i

            // Invalidate cached images at or above the change
            for key in imageCache.keys where key >= firstChange {
                imageCache.removeValue(forKey: key)
            }
        }

        ops = newOps
        setNeedsLayout()
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
        child.frame = bounds
        apply(to: child)
    }

    private func apply(to child: UIView) {
        // Clean up
        filterLayer?.removeFromSuperlayer()
        filterLayer = nil

        // Check if we have any image ops
        let hasImageOps = ops.contains { $0.isImageOp }

        if !hasImageOps {
            // Fast path: just layer ops on the child
            resetLayer(child.layer)
            for op in ops { op.apply(to: child) }
            return
        }

        // Image path: find the last cached image we can reuse,
        // run image ops from there, collect layer ops for the output.

        // 1. Find highest cached image below any invalidated point
        var currentImage: CIImage?
        var resumeFrom = 0

        for i in stride(from: ops.count - 1, through: 0, by: -1) {
            if let cached = imageCache[i] {
                currentImage = cached
                resumeFrom = i + 1
                break
            }
        }

        // 2. If no cache, we need a fresh snapshot.
        //    The snapshot captures the child at identity.
        if currentImage == nil {
            currentImage = captureSnapshot(of: child)
            // Find first image op and cache the snapshot there
            if let firstImageIdx = ops.indices.first(where: { ops[$0].isImageOp }) {
                imageCache[firstImageIdx] = currentImage
            }
            resumeFrom = 0
        }

        // 3. Run image ops from resumeFrom, caching each result
        for i in resumeFrom..<ops.count {
            let op = ops[i]
            guard op.isImageOp else { continue }

            if let blur = op as? BlurOp, let img = currentImage {
                currentImage = blur.process(img)
                imageCache[i] = currentImage
            } else if let filter = op as? FilterOp, let img = currentImage {
                currentImage = filter.process(img)
                imageCache[i] = currentImage
            } else if op is SnapshotOp {
                // Snapshot is already taken; cache it at this index
                imageCache[i] = currentImage
            }
        }

        // 4. Render the final image into a filter layer
        guard let finalImage = currentImage,
              let cgImage = Self.ciContext.createCGImage(finalImage, from: finalImage.extent) else {
            resetLayer(child.layer)
            return
        }

        let scale = UIScreen.main.scale
        let fl = CALayer()
        fl.contents = cgImage
        fl.contentsScale = scale
        fl.contentsGravity = .center
        fl.masksToBounds = false
        fl.frame = bounds

        // 5. Apply layer ops to the filter layer
        for op in ops where !op.isImageOp {
            op.apply(to: self) // use host as a scratch view for building transform
        }
        // Transfer accumulated state from host layer to filter layer
        fl.transform = layer.transform
        fl.anchorPoint = layer.anchorPoint
        fl.opacity = layer.opacity
        fl.mask = layer.mask

        // Reset host layer
        resetLayer(layer)

        layer.addSublayer(fl)
        filterLayer = fl
        child.layer.opacity = 0
    }

    private func captureSnapshot(of child: UIView) -> CIImage? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        let scale = UIScreen.main.scale
        let saved = disableClipping(in: child)

        let renderer = UIGraphicsImageRenderer(
            size: child.bounds.size,
            format: {
                let f = UIGraphicsImageRendererFormat()
                f.scale = scale
                return f
            }()
        )
        let image = renderer.image { ctx in
            child.layer.render(in: ctx.cgContext)
        }

        restoreClipping(saved)
        return CIImage(image: image)
    }

    private func resetLayer(_ l: CALayer) {
        l.transform = CATransform3DIdentity
        l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        l.opacity = 1
        l.mask = nil
    }

    // MARK: - Clipping helpers

    private func disableClipping(in view: UIView) -> [(UIView, Bool, CALayer?)] {
        var saved: [(UIView, Bool, CALayer?)] = []
        func walk(_ v: UIView) {
            if v.clipsToBounds || v.layer.mask != nil {
                saved.append((v, v.clipsToBounds, v.layer.mask))
                v.clipsToBounds = false
                v.layer.mask = nil
            }
            for sub in v.subviews { walk(sub) }
        }
        walk(view)
        return saved
    }

    private func restoreClipping(_ saved: [(UIView, Bool, CALayer?)]) {
        for (v, clips, mask) in saved {
            v.clipsToBounds = clips
            v.layer.mask = mask
        }
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
    func effect(_ build: (Effect) -> Effect) -> some View {
        EffectView(child: self, effect: build(Effect()))
    }
}

#endif
