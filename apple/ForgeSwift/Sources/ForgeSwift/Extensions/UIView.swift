import UIKit

// MARK: - Constraint Helpers

extension UIView {
    @discardableResult
    func constrain(_ block: () -> Void) -> Self {
        translatesAutoresizingMaskIntoConstraints = false
        block()
        return self
    }

    @discardableResult
    func constrain(_ constrain: Bool = true) -> Self {
        translatesAutoresizingMaskIntoConstraints = !constrain
        return self
    }
}

// MARK: - Pin & Center

extension UIView {
    @discardableResult
    func pin(_ edges: Edge.Set = .all, to view: UIView, offset: CGFloat = 0) -> UIView {
        return constrain {
            if edges.contains(.top) { topAnchor.equal(view.topAnchor, offset: offset) }
            if edges.contains(.leading) { leadingAnchor.equal(view.leadingAnchor, offset: offset) }
            if edges.contains(.trailing) { trailingAnchor.equal(view.trailingAnchor, offset: -offset) }
            if edges.contains(.bottom) { bottomAnchor.equal(view.bottomAnchor, offset: -offset) }
        }
    }

    @discardableResult
    func center(x: Bool = true, y: Bool = true, in view: UIView) -> UIView {
        return constrain {
            if x { centerXAnchor.equal(view.centerXAnchor) }
            if y { centerYAnchor.equal(view.centerYAnchor) }
        }
    }
}
