//
//  LayoutReader.swift
//  ForgeSwift
//
//  Build-time-unknown, layout-time-known: reports the proposed size
//  of the container to a content closure, rebuilding the subtree
//  when the size changes. SwiftUI's GeometryReader analog.
//
//      LayoutReader { size in
//          Box(.fix(size.width * 0.5, size.height)) { ... }
//      }
//

#if canImport(UIKit)
import UIKit

public struct LayoutReader: ProxyView {
    public let content: @MainActor (Size) -> any View

    public init(_ content: @escaping @MainActor (Size) -> any View) {
        self.content = content
    }

    public var child: any View { content(.zero) }
    public var deferred: Bool { true }

    public func makeRenderer() -> ProxyRenderer {
        LayoutReaderRenderer(view: self)
    }
}

final class LayoutReaderRenderer: ProxyRenderer {
    weak var node: ProxyNode?
    private weak var readerView: LayoutReaderView?
    private var view: LayoutReader

    init(view: LayoutReader) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let reader = newView as? LayoutReader else { return }
        view = reader
        readerView?.setNeedsLayout()
    }

    func mount() -> PlatformView {
        let rv = LayoutReaderView()
        rv.onLayout = { [weak self] rect in self?.onRect(rect) }
        self.readerView = rv
        return rv
    }

    private func onRect(_ rect: Rect) {
        let child = view.content(rect.size)
        node?.reconcileChild(child)
    }
}

final class LayoutReaderView: UIView {
    var onLayout: ((Rect) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize { size }

    override func layoutSubviews() {
        super.layoutSubviews()
        subviews.first?.frame = bounds
        onLayout?(Rect(bounds))
    }
}

#endif
