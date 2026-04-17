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
        RectReporterRenderer(view: self)
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
    private weak var reporterView: RectReporterView?
    private var view: RectReporter

    init(view: RectReporter) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let reporter = newView as? RectReporter, let reporterView else { return }
        view = reporter

        reporterView.onRect = reporter.onRect
        reporterView.updateContent(reporter.content)
    }

    func mount() -> PlatformView {
        let rv = RectReporterView()
        self.reporterView = rv
        rv.onRect = view.onRect
        rv.installContent(view.content)
        return rv
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
