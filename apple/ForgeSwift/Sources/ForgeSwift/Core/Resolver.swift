//
//  Resolver.swift
//  SwiftKit
//
//  The reconciler. Walks a View tree, creating Nodes/Models/Builders/
//  Renderers as it goes, and wires up dirty handlers so subsequent
//  rebuilds re-run the smallest affected subtree.
//
//  v2 day 1: naive rebuild. On dirty, unmount the composite node's
//  entire child subtree and re-run its builder. Prop-diffing and
//  structural diffing come later.
//

@MainActor public final class Resolver {
    public init() {}

    public func mount(_ view: any View) -> PlatformView {
        let node = inflate(view: view, parent: nil)
        guard let platform = node.platformView else {
            fatalError("Root node produced no platform view")
        }
        return platform
    }

    private func inflate(view: any View, parent: Node?) -> Node {
        switch view {
        case let leaf as any LeafView:
            return inflateLeaf(leaf, parent: parent)
        case let composite as any CompositeView:
            return inflateComposite(composite, parent: parent)
        default:
            fatalError("View must conform to LeafView or CompositeView: \(type(of: view))")
        }
    }

    private func inflateLeaf(_ view: any LeafView, parent: Node?) -> LeafNode {
        guard let node = view.makeNode() as? LeafNode else {
            fatalError("LeafView.makeNode() must return a LeafNode")
        }
        node.parent = parent
        let renderer = view.makeRenderer()
        node.renderer = renderer
        node.platformView = renderer.mount()
        return node
    }

    private func inflateComposite(_ view: any CompositeView, parent: Node?) -> CompositeNode {
        guard let node = view.makeNode() as? CompositeNode else {
            fatalError("CompositeView.makeNode() must return a CompositeNode")
        }
        node.parent = parent
        node.view = view
        setupComposite(view, node: node)

        node.onDirty = { [weak self, weak node] in
            guard let self, let node else { return }
            self.rebuild(node)
        }

        buildSubtree(node)
        return node
    }

    private func setupComposite<V: CompositeView>(_ view: V, node: CompositeNode) {
        let model = view.makeModel(node: node)
        let builder = view.makeBuilder(model: model)
        builder.node = node
        node.model = model
        node.builder = builder
    }

    private func buildSubtree(_ node: CompositeNode) {
        guard let builder = node.builder else { return }
        node.beginBuild()
        let childView = builder.build()
        let childNode = inflate(view: childView, parent: node)
        node.children = [childNode]
        node.platformView = childNode.platformView
    }

    private func rebuild(_ node: CompositeNode) {
        let oldPlatform = node.platformView
        let superview = oldPlatform?.superview

        for child in node.children { child.unmount() }
        node.children.removeAll()

        buildSubtree(node)

        if let superview, let new = node.platformView, new !== oldPlatform {
            oldPlatform?.removeFromSuperview()
            superview.addSubview(new)
        }
    }
}
