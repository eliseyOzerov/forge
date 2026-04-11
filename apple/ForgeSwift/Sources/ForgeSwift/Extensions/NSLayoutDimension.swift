//
//  NSLayoutDimension.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 1. 8. 25.
//

import UIKit

// MARK: - Constant constraints
extension NSLayoutDimension {
    @discardableResult
    func equal(_ constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.constraint(equalToConstant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func min(_ constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualToConstant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func max(_ constant: CGFloat) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualToConstant: constant)
        constraint.isActive = true
        return constraint
    }
}

// MARK: - Dimension-to-dimension constraints
extension NSLayoutDimension {
    @discardableResult
    func equal(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: dimension, multiplier: multiplier, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func min(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: dimension, multiplier: multiplier, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func max(_ dimension: NSLayoutDimension, multiplier: CGFloat = 1.0, constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: dimension, multiplier: multiplier, constant: constant)
        constraint.isActive = true
        return constraint
    }
}

// MARK: - X anchor constraints
extension NSLayoutXAxisAnchor {
    
    @discardableResult
    func equal(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func min(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func max(_ anchor: NSLayoutXAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
}

// MARK: - Y anchor constraints
extension NSLayoutYAxisAnchor {
    @discardableResult
    func equal(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(equalTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func min(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(greaterThanOrEqualTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
    
    @discardableResult
    func max(_ anchor: NSLayoutYAxisAnchor, offset constant: CGFloat = 0) -> NSLayoutConstraint {
        let constraint = self.constraint(lessThanOrEqualTo: anchor, constant: constant)
        constraint.isActive = true
        return constraint
    }
}

