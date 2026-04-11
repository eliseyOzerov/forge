//
//  UIButton.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 2. 8. 25.
//

import UIKit

nonisolated(unsafe) private var actionKey: UInt8 = 0


// MARK: - Handlers

extension UIButton {
    
    /// Make sure you're not retaining self in the closure. Better yet, use a viewModel.doStuff pattern, so you don't mention self at all.
    @discardableResult
    func onTap(_ action: @escaping () -> Void) -> Self {
        // Store the closure using associated objects
        objc_setAssociatedObject(self, &actionKey, action, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Remove any existing targets and add our handler
        removeTarget(nil, action: nil, for: .touchUpInside)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
        
        return self
    }
    
    @objc private func handleTap() {
        // Retrieve and execute the stored closure
        if let action = objc_getAssociatedObject(self, &actionKey) as? () -> Void {
            action()
        }
    }
}

extension UIButton {
    
    @discardableResult
    func configuration(_ config: UIButton.Configuration) -> Self {
        configuration = config
        return self
    }
    
    @discardableResult
    func title(_ title: String?, for state: UIControl.State = .normal) -> Self {
        setTitle(title, for: state)
        return self
    }
    
    @discardableResult
    func attributedTitle(_ title: NSAttributedString?, for state: UIControl.State = .normal) -> Self {
        setAttributedTitle(title, for: state)
        return self
    }
    
    @discardableResult
    func titleColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
        setTitleColor(color, for: state)
        return self
    }
    
    @discardableResult
    func titleShadowColor(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
        setTitleShadowColor(color, for: state)
        return self
    }
    
    @discardableResult
    func image(_ image: UIImage?, for state: UIControl.State = .normal) -> Self {
        setImage(image, for: state)
        return self
    }
    
    @discardableResult
    func background(_ image: UIImage?, for state: UIControl.State = .normal) -> Self {
//        configurationUpdateHandler = { button in
//            switch button.state {
//            case .normal:
//
//            }
//        }
        return self
    }
    
    @discardableResult
    func background(_ color: UIColor?, for state: UIControl.State = .normal) -> Self {
        configuration?.background.backgroundColor = color
        return self
    }
    
    @discardableResult
    func radius(_ color: CGFloat, for state: UIControl.State = .normal) -> Self {
        configuration?.background.cornerRadius = color
        return self
    }
    
    @discardableResult
    func font(_ font: UIFont) -> Self {
        titleLabel?.font = font
        return self
    }
    
    @discardableResult
    func contentAlignment(_ horizontal: UIControl.ContentHorizontalAlignment = .center, _ vertical: UIControl.ContentVerticalAlignment = .center) -> Self {
        contentHorizontalAlignment = horizontal
        contentVerticalAlignment = vertical
        return self
    }
    
    @discardableResult
    func lineBreakMode(_ mode: NSLineBreakMode) -> Self {
        titleLabel?.lineBreakMode = mode
        return self
    }
    
    @discardableResult
    func enabled(_ enabled: Bool) -> Self {
        isEnabled = enabled
        return self
    }
    
    @discardableResult
    func selected(_ selected: Bool) -> Self {
        isSelected = selected
        return self
    }
    
    @discardableResult
    func highlighted(_ highlighted: Bool) -> Self {
        isHighlighted = highlighted
        return self
    }
}
