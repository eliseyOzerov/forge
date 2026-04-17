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
//  Paired with RectReporter (post-layout rect of individual children)
//  for cases where you need to know exact child positions — snap
//  targets for sliders, anchors for popovers, etc.
//

#if canImport(UIKit)
import UIKit

public struct LayoutReader: LeafView {
    public let content: @MainActor (Size) -> any View

    public init(_ content: @escaping @MainActor (Size) -> any View) {
        self.content = content
    }

    public func makeRenderer() -> Renderer {
        LayoutReaderRenderer(content: content)
    }
}

final class LayoutReaderRenderer: Renderer {
    private weak var readerView: LayoutReaderView?

    var content: @MainActor (Size) -> any View {
        didSet {
            guard let readerView else { return }
            readerView.content = content
            readerView.rebuildIfSized()
        }
    }

    init(content: @escaping @MainActor (Size) -> any View) {
        self.content = content
    }

    func update(from view: any View) {
        guard let reader = view as? LayoutReader else { return }
        content = reader.content
    }

    func mount() -> PlatformView {
        let view = LayoutReaderView()
        self.readerView = view
        view.content = content
        return view
    }
}

final class LayoutReaderView: UIView {
    var content: (@MainActor (Size) -> any View)?
    private var childNode: Node?
    private var lastSize: Size = Size(0, 0)

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        // Take whatever the parent proposes; content sizes to bounds.
        size
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = Size(Double(bounds.width), Double(bounds.height))
        if size != lastSize {
            lastSize = size
            rebuild(for: size)
        }
        childNode?.platformView?.frame = bounds
    }

    /// Rebuild with the already-observed size (used on update paths
    /// where the content closure changed but bounds didn't).
    func rebuildIfSized() {
        guard lastSize.width > 0 || lastSize.height > 0 else { return }
        rebuild(for: lastSize)
    }

    private func rebuild(for size: Size) {
        guard let content else { return }
        let newView = content(size)
        if let node = childNode, node.canUpdate(to: newView) {
            node.update(from: newView)
        } else {
            childNode?.platformView?.removeFromSuperview()
            let node = Node.inflate(newView)
            childNode = node
            if let pv = node.platformView {
                addSubview(pv)
                pv.frame = bounds
            }
        }
    }
}

#endif
