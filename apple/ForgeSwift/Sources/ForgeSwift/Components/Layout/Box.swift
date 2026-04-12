#if canImport(UIKit)
import UIKit

/// The fundamental layout primitive. A container that paints a Surface,
/// clips to a Shape, and overlays its children (each aligned independently).
///
/// Single child = styled container. Multiple children = overlay (ZStack).
///
/// ```swift
/// Box(
///     frame: .fixed(200, 200),
///     shape: .roundedRect(radius: 12),
///     surface: Surface { $0.color(.white).shadow(blur: 8) },
///     padding: Padding(all: 16)
/// ) {
///     Text("Hello")
/// }
/// ```
public struct Box: ContainerView {
    public let frame: Frame
    public let shape: Shape?
    public let surface: Surface?
    public let padding: Padding
    public let alignment: Alignment
    public let clip: Bool
    public let children: [any View]

    public init(
        _ frame: Frame = .hug,
        _ surface: Surface? = nil,
        _ shape: Shape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        children: [any View] = []
    ) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.children = children
    }

    public init(
        _ frame: Frame = .hug,
        _ surface: Surface? = nil,
        _ shape: Shape? = nil,
        padding: Padding = .zero,
        alignment: Alignment = .center,
        clip: Bool = true,
        @ChildrenBuilder content: () -> [any View]
    ) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
        self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        BoxRenderer(
            frame: frame,
            shape: shape,
            surface: surface,
            padding: padding,
            alignment: alignment,
            clip: clip
        )
    }
}

// MARK: - Renderer

final class BoxRenderer: ContainerRenderer {
    let frame: Frame
    let shape: Shape?
    let surface: Surface?
    let padding: Padding
    let alignment: Alignment
    let clip: Bool

    init(frame: Frame, shape: Shape?, surface: Surface?, padding: Padding, alignment: Alignment, clip: Bool) {
        self.frame = frame
        self.shape = shape
        self.surface = surface
        self.padding = padding
        self.alignment = alignment
        self.clip = clip
    }

    func mount() -> PlatformView {
        let view = BoxView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? BoxView else { return }
        apply(to: view)
    }

    private func apply(to view: BoxView) {
        view.boxFrame = frame
        view.boxShape = shape
        view.boxSurface = surface
        view.boxClip = clip
        view.boxPadding = padding
        view.boxAlignment = alignment
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - BoxView

final class BoxView: UIView {
    var boxShape: Shape?
    var boxSurface: Surface?
    var boxClip: Bool = true
    var boxFrame: Frame = .hug
    var boxPadding: Padding = .zero
    var boxAlignment: Alignment = .center

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let surface = boxSurface, let ctx = UIGraphicsGetCurrentContext() else { return }
        let resolvedShape = boxShape ?? .rect()
        let renderer = SurfaceRenderer(surface: surface, shape: resolvedShape, bounds: bounds)
        renderer.render(in: ctx)
    }

    override var intrinsicContentSize: CGSize {
        let w: CGFloat = switch boxFrame.width {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        let h: CGFloat = switch boxFrame.height {
        case .fix(let v): v
        default: UIView.noIntrinsicMetric
        }
        return CGSize(width: w, height: h)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let w: CGFloat = switch boxFrame.width {
        case .fix(let v): v
        case .fill: size.width
        case .hug: childrenSize(proposing: size).width + boxPadding.leading + boxPadding.trailing
        }
        let h: CGFloat = switch boxFrame.height {
        case .fix(let v): v
        case .fill: size.height
        case .hug: childrenSize(proposing: size).height + boxPadding.top + boxPadding.bottom
        }
        return CGSize(width: w, height: h)
    }

    private func childrenSize(proposing size: CGSize) -> CGSize {
        var maxW: CGFloat = 0, maxH: CGFloat = 0
        for child in subviews {
            let s = child.sizeThatFits(size)
            maxW = max(maxW, s.width)
            maxH = max(maxH, s.height)
        }
        return CGSize(width: maxW, height: maxH)
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        applyFrameConstraints(in: superview)
    }

    private func applyFrameConstraints(in parent: UIView) {
        constrain {
            switch boxFrame.width {
            case .fix(let w): widthAnchor.equal(w)
            case .fill: leadingAnchor.equal(parent.leadingAnchor); trailingAnchor.equal(parent.trailingAnchor)
            case .hug: break
            }

            switch boxFrame.height {
            case .fix(let h): heightAnchor.equal(h)
            case .fill: topAnchor.equal(parent.topAnchor); bottomAnchor.equal(parent.bottomAnchor)
            case .hug: break
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Position children based on alignment
        let inset = CGRect(
            x: boxPadding.leading,
            y: boxPadding.top,
            width: bounds.width - boxPadding.leading - boxPadding.trailing,
            height: bounds.height - boxPadding.top - boxPadding.bottom
        )

        for child in subviews {
            let childSize = child.sizeThatFits(inset.size)
            let fx = (boxAlignment.x + 1) / 2  // 0...1
            let fy = (boxAlignment.y + 1) / 2  // 0...1
            let x = inset.minX + (inset.width - childSize.width) * fx
            let y = inset.minY + (inset.height - childSize.height) * fy
            child.frame = CGRect(x: x, y: y, width: childSize.width, height: childSize.height)
        }

        // Clip to shape
        if boxClip, let shape = boxShape {
            let maskLayer = CAShapeLayer()
            maskLayer.path = shape.resolve(in: bounds).cgPath
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }
}

// MARK: - View Extensions

public extension View {
    func centered() -> Box {
        Box(.fill, alignment: .center, children: [self])
    }

    func padded(_ padding: Padding) -> Box {
        Box(.fill, padding: padding, alignment: .topLeft, children: [self])
    }

    func padded(_ all: Double) -> Box {
        Box(.fill, padding: Padding(all: all), alignment: .topLeft, children: [self])
    }

    func debug(_ color: UIColor = .red) -> Box {
        let c = Color(platform: color)
        return Box(.hug, .color(c.withAlpha(0.1)).border(c, width: 1), children: [self])
    }
}

#endif
