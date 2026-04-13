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

// MARK: - Constant constraints
extension NSLayoutDimension {
    @discardableResult
    func equal(_ constant: CGFloat, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(equalToConstant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func min(_ constant: CGFloat, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualToConstant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func max(_ constant: CGFloat, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualToConstant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }
}

// MARK: - Dimension-to-dimension constraints
extension NSLayoutDimension {
    @discardableResult
    func equal(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: dimension, multiplier: multiplier, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func min(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: dimension, multiplier: multiplier, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func max(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: dimension, multiplier: multiplier, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }
}

// MARK: - X anchor constraints
extension NSLayoutXAxisAnchor {
    @discardableResult
    func equal(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func min(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func max(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }
}

// MARK: - Y anchor constraints
extension NSLayoutYAxisAnchor {
    @discardableResult
    func equal(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func min(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }

    @discardableResult
    func max(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0, priority: UILayoutPriority = .required) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: anchor, constant: constant)
        constraint.priority = priority
        constraint.isActive = true
        return constraint
    }
}
