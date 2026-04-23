/// Debug visualization overlay showing layout boundaries.
///
/// Wraps a view with a colored border, tinted background, and a
/// small info label displaying position and size.
///
/// ```swift
/// myView.debug(.blue, label: "card")
/// ```
public struct DebugOverlay: ContainerView {
    public let child: any View
    public let color: Color
    public let label: String?
    public let children: [any View]

    init(child: any View, color: Color, label: String?) {
        self.child = child
        self.color = color
        self.label = label
        self.children = [child]
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        DebugOverlayRenderer(view: self)
        #else
        fatalError("DebugOverlay not yet implemented for this platform")
        #endif
    }
}

// MARK: - View Extension

public extension View {
    func debug(_ color: Color = .red, label: String? = nil) -> DebugOverlay {
        DebugOverlay(child: self, color: Color(platform: color.platformColor), label: label)
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class DebugOverlayRenderer: ContainerRenderer {
    private weak var overlayView: DebugOverlayView?
    private var view: DebugOverlay

    init(view: DebugOverlay) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let overlay = newView as? DebugOverlay, let overlayView else { return }
        let old = view
        view = overlay

        if old.color != overlay.color {
            overlayView.debugColor = overlay.color
            overlayView.setNeedsDisplay()
        }
        if old.label != overlay.label {
            overlayView.debugLabel = overlay.label
            overlayView.setNeedsDisplay()
        }
    }

    func mount() -> PlatformView {
        let ov = DebugOverlayView()
        self.overlayView = ov
        ov.debugColor = view.color
        ov.debugLabel = view.label
        return ov
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

/// Backing UIView for DebugOverlay. Draws a colored border,
/// tinted background, and an info label below the view.
final class DebugOverlayView: UIView {
    var debugColor: Color = .red
    var debugLabel: String?
    private let infoLabel = UILabel()
    private let borderLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        clipsToBounds = false

        borderLayer.fillColor = nil
        borderLayer.lineWidth = 1
        layer.addSublayer(borderLayer)

        infoLabel.font = .systemFont(ofSize: 9, weight: .medium)
        addSubview(infoLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // First content child (not the info label)
        contentChild?.sizeThatFits(size) ?? .zero
    }

    private var contentChild: UIView? {
        subviews.first { $0 !== infoLabel }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentChild?.frame = bounds

        let uiColor = debugColor.platformColor

        // Border
        borderLayer.path = UIBezierPath(rect: bounds.insetBy(dx: 0.5, dy: 0.5)).cgPath
        borderLayer.strokeColor = uiColor.withAlphaComponent(0.5).cgColor

        // Background
        backgroundColor = uiColor.withAlphaComponent(0.05)

        // Info label below bounds
        let hash = String(format: "%04x", abs(hashValue) % 0xFFFF)
        let name = debugLabel ?? hash
        infoLabel.text = "\(name) (\(Int(frame.origin.x)),\(Int(frame.origin.y))) w:\(Int(bounds.width))/h:\(Int(bounds.height))"
        infoLabel.textColor = uiColor
        infoLabel.sizeToFit()
        infoLabel.frame.origin = CGPoint(x: 2, y: bounds.height + 2)
    }
}

#endif
