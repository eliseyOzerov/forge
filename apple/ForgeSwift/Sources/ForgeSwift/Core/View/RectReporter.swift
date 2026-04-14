//
//  RectReporter.swift
//  ForgeSwift
//
//  Reports the post-layout rect of its wrapped view to a callback,
//  in the immediate parent's coordinate space. Fires on change only.
//
//      RectReporter(onRect: { model.itemRects[i] = $0 }) {
//          Text(label)
//      }
//
//  Sugar via `.onRect { ... }` on any View.
//

#if canImport(UIKit)
import UIKit

public struct RectReporter: LeafView {
    public let onRect: @MainActor (Rect) -> Void
    public let content: any View

    public init(
        onRect: @escaping @MainActor (Rect) -> Void,
        @ChildBuilder content: () -> any View
    ) {
        self.onRect = onRect
        self.content = content()
    }

    public init(onRect: @escaping @MainActor (Rect) -> Void, content: any View) {
        self.onRect = onRect
        self.content = content
    }

    public func makeRenderer() -> Renderer {
        RectReporterRenderer(onRect: onRect, content: content)
    }
}

public extension View {
    /// Observe this view's post-layout rect (in the parent's coord
    /// space). Callback fires only when the rect changes.
    func onRect(_ perform: @escaping @MainActor (Rect) -> Void) -> RectReporter {
        RectReporter(onRect: perform, content: self)
    }
}

final class RectReporterRenderer: Renderer {
    var onRect: @MainActor (Rect) -> Void
    var content: any View

    init(onRect: @escaping @MainActor (Rect) -> Void, content: any View) {
        self.onRect = onRect
        self.content = content
    }

    func mount() -> PlatformView {
        let view = RectReporterView()
        view.onRect = onRect
        view.installContent(content)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? RectReporterView else { return }
        view.onRect = onRect
        view.updateContent(content)
    }
}

final class RectReporterView: UIView {
    var onRect: (@MainActor (Rect) -> Void)?
    private var childNode: Node?
    private var lastRect: Rect?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    func installContent(_ view: any View) {
        let node = Node.inflate(view)
        childNode = node
        if let pv = node.platformView { addSubview(pv) }
    }

    func updateContent(_ view: any View) {
        if let node = childNode, node.canUpdate(to: view) {
            node.update(from: view)
        } else {
            childNode?.platformView?.removeFromSuperview()
            let node = Node.inflate(view)
            childNode = node
            if let pv = node.platformView {
                addSubview(pv)
                pv.frame = bounds
            }
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        childNode?.platformView?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        childNode?.platformView?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        childNode?.platformView?.frame = bounds
        reportRect()
    }

    private func reportRect() {
        guard let superview, let onRect else { return }
        let converted = convert(bounds, to: superview)
        let rect = Rect(
            x: Double(converted.origin.x),
            y: Double(converted.origin.y),
            width: Double(converted.size.width),
            height: Double(converted.size.height)
        )
        if rect != lastRect {
            lastRect = rect
            onRect(rect)
        }
    }
}

#endif
