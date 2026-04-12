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
        frame: Frame = .hug,
        shape: Shape? = nil,
        surface: Surface? = nil,
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
        frame: Frame = .hug,
        shape: Shape? = nil,
        surface: Surface? = nil,
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
        view.boxShape = shape
        view.boxSurface = surface
        view.boxClip = clip
        view.setNeedsDisplay()
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
        if padding == .zero {
            platformView.pin(to: container)
        } else {
            platformView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                platformView.topAnchor.constraint(equalTo: container.topAnchor, constant: padding.top),
                platformView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding.leading),
                platformView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding.trailing),
                platformView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding.bottom),
            ])
        }
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

    override func layoutSubviews() {
        super.layoutSubviews()
        if boxClip, let shape = boxShape {
            let maskLayer = CAShapeLayer()
            maskLayer.path = shape.resolve(in: bounds).cgPath
            layer.mask = maskLayer
        } else {
            layer.mask = nil
        }
    }
}

#endif
