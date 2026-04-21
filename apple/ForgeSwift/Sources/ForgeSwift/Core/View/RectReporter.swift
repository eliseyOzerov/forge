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

/// ProxyView that reports its post-layout rect in the parent's coordinate space.
public struct RectReporter: ProxyView {
    public let onRect: @MainActor (Rect) -> Void
    public let child: any View

    public init(
        onRect: @escaping @MainActor (Rect) -> Void,
        @ChildBuilder content: () -> any View
    ) {
        self.onRect = onRect
        self.child = content()
    }

    public init(onRect: @escaping @MainActor (Rect) -> Void, content: any View) {
        self.onRect = onRect
        self.child = content
    }

    public func makeRenderer() -> ProxyRenderer {
        RectReporterRenderer(view: self)
    }
}

public extension View {
    func onRect(_ perform: @escaping @MainActor (Rect) -> Void) -> RectReporter {
        RectReporter(onRect: perform, content: self)
    }
}

final class RectReporterRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var reporterView: RectReporterView?
    private var view: RectReporter

    init(view: RectReporter) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let reporter = newView as? RectReporter, let reporterView else { return }
        view = reporter
        reporterView.onRect = reporter.onRect
    }

    func mount() -> PlatformView {
        let rv = RectReporterView()
        self.reporterView = rv
        rv.onRect = view.onRect
        return rv
    }
}

final class RectReporterView: UIView {
    var onRect: (@MainActor (Rect) -> Void)?
    private var lastRect: Rect?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        subviews.first?.sizeThatFits(size) ?? .zero
    }

    override var intrinsicContentSize: CGSize {
        subviews.first?.intrinsicContentSize
            ?? CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds
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
