//
//  UIView.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 1. 8. 25.
//

import Foundation
import UIKit
import Combine

//typealias View = UIView

// MARK: - Reactivity

nonisolated(unsafe) private var cancellablesKey: UInt8 = 0

extension UIView {
    @discardableResult
    // Helper that handles all the boilerplate
    func bind<K, T>(_ publisher: AnyPublisher<T, Never>, to keyPath: ReferenceWritableKeyPath<K, T>) -> Self where K: UIView {
        publisher
            .receive(on: DispatchQueue.main)
            .assign(to: keyPath, on: self as! K)
            .store(in: &cancellables)
        return self
    }
    
    @discardableResult
    // Helper that handles all the boilerplate
    func sink<T>(_ publisher: AnyPublisher<T, Never>, _ transform: @escaping (T) -> Void) -> Self {
        publisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: transform)
            .store(in: &cancellables)
        return self
    }
    
    // Store cancellables using associated objects
    private var cancellables: Set<AnyCancellable> {
        get {
            return objc_getAssociatedObject(self, &cancellablesKey) as? Set<AnyCancellable> ?? Set<AnyCancellable>()
        }
        set {
            objc_setAssociatedObject(self, &cancellablesKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

// MARK: - Debugging

extension UIView {
    var memoryAddress: String {
        return String(describing: ObjectIdentifier(self))
    }
    
    // Or if you want the hex format specifically:
    var memoryAddressHex: String {
        let identifier = ObjectIdentifier(self)
        return String(format: "0x%016llx", unsafeBitCast(identifier, to: UInt64.self))
    }
    
    var debugIdentifier: String {
        let className = String(describing: type(of: self))
        let identifier = accessibilityIdentifier ?? "tag:\(tag)"
        let address = memoryAddress
        return "\(className)(\(identifier)) @\(address)"
    }
}

// MARK: - General

extension UIView {
    /// By adding a block here, we can call
    /// return constrain { ... add constraints here }
    ///
    /// Without it, we'd have to call
    /// constrain()
    /// .. add constraints
    /// return self
    ///
    /// which is lame :)
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
    
    @discardableResult
    func stored<T>(in variable: inout T?) -> Self {
        variable = self as? T
        return self
    }
}

// MARK: - Frame

extension UIView {
    enum DimensionConstraint {
        case fixed(CGFloat)
        case range(min: CGFloat?, max: CGFloat?)
        case min(CGFloat)
        case max(CGFloat)
        
        // Convenience static methods
        static func atLeast(_ value: CGFloat) -> DimensionConstraint {
            return .min(value)
        }
        
        static func atMost(_ value: CGFloat) -> DimensionConstraint {
            return .max(value)
        }
        
        static func between(min: CGFloat, max: CGFloat) -> DimensionConstraint {
            return .range(min: min, max: max)
        }
    }
    
    private func applyDimensionConstraint(_ constraint: DimensionConstraint, to anchor: NSLayoutDimension) {
        switch constraint {
        case .fixed(let value):
            anchor.equal(value)
            
        case .range(let min, let max):
            if let min = min {
                anchor.min(min)
            }
            if let max = max {
                anchor.max(max)
            }
            
        case .min(let value):
            anchor.min(value)
            
        case .max(let value):
            anchor.max(value)
        }
    }
    
    @discardableResult
    func frame(width: DimensionConstraint? = nil, height: DimensionConstraint? = nil) -> Self {
        return constrain {
            // Apply width constraint
            if let widthConstraint = width {
                applyDimensionConstraint(widthConstraint, to: widthAnchor)
            }
            
            // Apply height constraint
            if let heightConstraint = height {
                applyDimensionConstraint(heightConstraint, to: heightAnchor)
            }
        }
    }
    
    @discardableResult
    func frame(size: DimensionConstraint) -> Self {
        return constrain {
            applyDimensionConstraint(size, to: widthAnchor)
            applyDimensionConstraint(size, to: heightAnchor)
        }
    }
    
    func frame(width: CGFloat? = nil, height: CGFloat? = nil) -> UIView {
        return constrain {
            if width != nil { widthAnchor.equal(width!) }
            if height != nil { heightAnchor.equal(height!) }
        }
    }
    
    /// Sets the width and height constraints for this view to the given size, as a square
    func frame(_ size: CGFloat) -> UIView {
        return constrain {
            widthAnchor.equal(size)
            heightAnchor.equal(size)
        }
    }
}

// MARK: - Positioning within parent

class PinningView: UIView {
    private let edges: Edge.Set
    private let offset: CGFloat
    private let child: UIView

    init(_ child: UIView, edges: Edge.Set = .all, offset: CGFloat = 0) {
        self.child = child
        self.edges = edges
        self.offset = offset
        super.init(frame: .zero)
        addSubview(child)
        child.pin(to: self) // <-- pin child to this view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let view = superview {
            pin(edges, to: view, offset: offset)
        }
    }
}

class CenteringView: UIView {
    private let x: Bool
    private let y: Bool

    init(_ child: UIView, x: Bool = true, y: Bool = true) {
        self.x = x
        self.y = y
        super.init(frame: .zero)
        addSubview(child)
        child.pin(to: self) // <-- pin child to this view
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let view = superview {
            center(x: x, y: y, in: view)
        }
    }
}

extension UIView {
    /// Pins the edges of this view to the edges of the given view less the offset
    /// This method is only relevant AFTER we've added the view to a superview OR when we pass a "to" view argument.
    /// Use `pinned` for automatic constraint setup
    @discardableResult // <-- this allows us to use the function without using its result (no compiler warnings)
    func pin(_ edges: Edge.Set = .all, to view: UIView, offset: CGFloat = 0) -> UIView {
        return constrain {
            if edges.contains(.top) { topAnchor.equal(view.topAnchor, offset: offset) }
            if edges.contains(.leading) { leadingAnchor.equal(view.leadingAnchor, offset: offset) }
            if edges.contains(.trailing) { trailingAnchor.equal(view.trailingAnchor, offset: -offset) }
            if edges.contains(.bottom) { bottomAnchor.equal(view.bottomAnchor, offset: -offset) }
        }
    }
    
    @discardableResult // <-- this allows us to use the function without using its result (no compiler warnings)
    func pinned(_ edges: Edge.Set = .all, offset: CGFloat = 0) -> UIView {
        return PinningView(self, edges: edges, offset: offset)
    }
    
    @discardableResult
    func center(x: Bool = true, y: Bool = true, in view: UIView) -> UIView {
        return constrain {
            if x { centerXAnchor.equal(view.centerXAnchor) }
            if y { centerYAnchor.equal(view.centerYAnchor) }
        }
    }
    
    @discardableResult
    func centered(x: Bool = true, y: Bool = true) -> UIView {
        return CenteringView(self, x: x, y: y)
    }
    
    /// Adds a view atop this view, pins this view's edges to that view minus padding and returns that view
    /// This means this method should be called at the end of styling the inside the padding
    func padding(_ edges: Edge.Set = .all, _ padding: CGFloat? = nil) -> UIView {
        let container = UIView()
        container.addSubview(self)
        return container.constrain {
            pin(edges, to: container, offset: padding ?? 20)
        }
    }
    
    func padding(_ padding: CGFloat) -> UIView {
        let container = UIView()
        container.addSubview(self)
        return container.constrain {
            pin(.all, to: container, offset: padding)
        }
    }
}

// MARK: - Layout priority

extension UIView {
    /// Sets the priority for how much the view will try to keep its intrinsic size
    func hugging(_ priority: UILayoutPriority = .defaultHigh, for axis: NSLayoutConstraint.Axis = .horizontal) -> UIView {
        setContentHuggingPriority(priority, for: axis)
        return self
    }
    
    /// Sets the priority for how hard the view will resist being compressed
    func expansion(_ priority: UILayoutPriority = .defaultLow, for axis: NSLayoutConstraint.Axis = .horizontal) -> UIView {
        setContentCompressionResistancePriority(priority, for: axis)
        return self
    }
}

// MARK: - Fluent API

extension UIView {
    
    // MARK: - Visual Styling
    @discardableResult
    func background(_ color: UIColor) -> Self {
        backgroundColor = color
        return self
    }
    
    @discardableResult
    func alpha(_ value: CGFloat) -> Self {
        alpha = value
        return self
    }
    
    @discardableResult
    func hidden(_ hidden: Bool) -> Self {
        isHidden = hidden
        return self
    }
    
    @discardableResult
    func tint(_ color: UIColor) -> Self {
        tintColor = color
        return self
    }
    
    @discardableResult
    func tag(_ value: Int) -> Self {
        tag = value
        return self
    }
    
    @discardableResult
    func accessibilityIdentifier(_ identifier: String) -> Self {
        accessibilityIdentifier = identifier
        return self
    }
    
    // MARK: - Layer Styling
    @discardableResult
    func background(_ image: UIImage, contentMode: CALayerContentsGravity = .resizeAspectFill) -> Self {
        layer.contents = image.cgImage
        layer.contentsGravity = contentMode
        return self
    }
    
    @discardableResult
    func background(_ blur: CGFloat) -> Self {
        if let filter = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: blur]) {
            layer.backgroundFilters = [filter]
        }
        return self
    }
    
    @discardableResult
    func background(colors: [UIColor], startPoint: CGPoint? = nil, endPoint: CGPoint? = nil, type: CAGradientLayerType = .axial) -> Self {
        let grLayer = CAGradientLayer()
        grLayer.type = type
        grLayer.colors = colors
        grLayer.frame = bounds
        grLayer.startPoint = startPoint ?? grLayer.startPoint
        grLayer.endPoint = endPoint ?? grLayer.endPoint
        layer.insertSublayer(grLayer, at: 0)
        return self
    }
    
    @discardableResult
    func radius(_ radius: CGFloat, curve: CALayerCornerCurve = .continuous) -> Self {
        layer.cornerRadius = radius
        layer.cornerCurve = curve
        return self
    }
    
    @discardableResult
    func border(width: CGFloat = 1.0, color: UIColor = .black) -> Self {
        layer.borderWidth = width
        layer.borderColor = color.cgColor
        return self
    }
    
    @discardableResult
    func opacity(_ opacity: Float) -> Self {
        layer.opacity = opacity
        return self
    }
    
    @discardableResult
    func shadow(color: UIColor = .black, opacity: Float = 0.5, offset: CGSize = CGSize(width: 0, height: 2), radius: CGFloat = 4) -> Self {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowOffset = offset
        layer.shadowRadius = radius
        return self
    }
    
    @discardableResult
    func clip(_ clips: Bool = true) -> Self {
        clipsToBounds = clips
        return self
    }
    
    @discardableResult
    func mask(_ masks: Bool = true) -> Self {
        layer.masksToBounds = masks
        return self
    }
    
    // MARK: - Transform & Animation
    @discardableResult
    func scale(_ scale: CGFloat) -> Self {
        transform = CGAffineTransform(scaleX: scale, y: scale)
        return self
    }
    
    @discardableResult
    func scale(x: CGFloat, y: CGFloat) -> Self {
        transform = CGAffineTransform(scaleX: x, y: y)
        return self
    }
    
    @discardableResult
    func rotation(_ angle: CGFloat) -> Self {
        transform = CGAffineTransform(rotationAngle: angle)
        return self
    }
    
    @discardableResult
    func translation(x: CGFloat = 0, y: CGFloat = 0) -> Self {
        transform = CGAffineTransform(translationX: x, y: y)
        return self
    }
    
    // MARK: - User Interaction
    @discardableResult
    func interactionEnabled(_ enabled: Bool) -> Self {
        isUserInteractionEnabled = enabled
        return self
    }
    
    @discardableResult
    func multitouchEnabled(_ enabled: Bool) -> Self {
        isMultipleTouchEnabled = enabled
        return self
    }
    
    @discardableResult
    func contentMode(_ mode: UIView.ContentMode) -> Self {
        contentMode = mode
        return self
    }
    
    // MARK: - Layout
    @discardableResult
    func intrinsicContentSize(_ size: CGSize) -> Self {
        invalidateIntrinsicContentSize()
        return self
    }
    
    @discardableResult
    func semanticContentAttribute(_ attribute: UISemanticContentAttribute) -> Self {
        semanticContentAttribute = attribute
        return self
    }
    
    @discardableResult
    func autoresizingMask(_ mask: UIView.AutoresizingMask) -> Self {
        autoresizingMask = mask
        return self
    }
    
    @discardableResult
    func translatesAutoresizingMaskIntoConstraints(_ translates: Bool) -> Self {
        translatesAutoresizingMaskIntoConstraints = translates
        return self
    }
}
