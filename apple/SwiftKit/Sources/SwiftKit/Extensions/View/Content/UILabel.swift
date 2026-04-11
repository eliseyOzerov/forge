//
//  UILabel.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 2. 8. 25.
//

import UIKit
import Combine

//typealias Text = UILabel

extension UILabel {
    // MARK: - Initializers
    convenience init(_ text: String) {
        self.init()
        self.text = text
    }
    
    convenience init(_ text: NSAttributedString) {
        self.init()
        self.attributedText = text
    }
    
    convenience init(_ text: some Publisher<String?, Never>) {
        self.init()
        bind(text.eraseToAnyPublisher(), to: \UILabel.text)
    }
    
    @discardableResult
    func text(_ text: String?) -> Self {
        self.text = text
        return self
    }
    
    @discardableResult
    func text(_ text: some Publisher<String?, Never>) -> Self {
        bind(text.eraseToAnyPublisher(), to: \UILabel.text)
        return self
    }
    
    @discardableResult
    func attributedText(_ attributedText: NSAttributedString?) -> Self {
        self.attributedText = attributedText
        return self
    }
    
    @discardableResult
    func attributedText(_ value: some Publisher<NSAttributedString?, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.attributedText)
        return self
    }
    
    @discardableResult
    func font(_ font: UIFont) -> Self {
        self.font = font
        return self
    }
    
    @discardableResult
    func font(_ value: some Publisher<UIFont?, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.font)
        return self
    }
    
    @discardableResult
    func textColor(_ color: UIColor) -> Self {
        self.textColor = color
        return self
    }
    
    @discardableResult
    func textColor(_ value: some Publisher<UIColor, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.textColor)
        return self
    }
    
    @discardableResult
    func textAlignment(_ alignment: NSTextAlignment) -> Self {
        self.textAlignment = alignment
        return self
    }
    
    @discardableResult
    func textAlignment(_ value: some Publisher<NSTextAlignment, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.textAlignment)
        return self
    }
    
    @discardableResult
    func lineBreakMode(_ mode: NSLineBreakMode) -> Self {
        self.lineBreakMode = mode
        return self
    }
    
    @discardableResult
    func lineBreakMode(_ value: some Publisher<NSLineBreakMode, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.lineBreakMode)
        return self
    }
    
    @discardableResult
    func lineBreakStrategy(_ strategy: NSParagraphStyle.LineBreakStrategy) -> Self {
        self.lineBreakStrategy = strategy
        return self
    }
    
    @discardableResult
    func lineBreakStrategy(_ value: some Publisher<NSParagraphStyle.LineBreakStrategy, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.lineBreakStrategy)
        return self
    }
    
    @discardableResult
    func enabled(_ enabled: Bool) -> Self {
        self.isEnabled = enabled
        return self
    }
    
    @discardableResult
    func enabled(_ value: some Publisher<Bool, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.isEnabled)
        return self
    }
    
    @discardableResult
    func numberOfLines(_ lines: Int) -> Self {
        self.numberOfLines = lines
        return self
    }
    
    @discardableResult
    func numberOfLines(_ value: some Publisher<Int, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.numberOfLines)
        return self
    }
    
    /// Adjusts font size to fit width
    @discardableResult
    func adjustableSize(_ adjusts: Bool) -> Self {
        self.adjustsFontSizeToFitWidth = adjusts
        return self
    }
    
    @discardableResult
    func adjustableSize(_ value: some Publisher<Bool, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.adjustsFontSizeToFitWidth)
        return self
    }
    
    @discardableResult
    func baselineAdjustment(_ adjustment: UIBaselineAdjustment) -> Self {
        self.baselineAdjustment = adjustment
        return self
    }
    
    @discardableResult
    func baselineAdjustment(_ value: some Publisher<UIBaselineAdjustment, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.baselineAdjustment)
        return self
    }
    
    @discardableResult
    func minimumScaleFactor(_ factor: CGFloat) -> Self {
        self.minimumScaleFactor = factor
        return self
    }
    
    @discardableResult
    func minimumScaleFactor(_ value: some Publisher<CGFloat, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.minimumScaleFactor)
        return self
    }
    
    @discardableResult
    func allowsDefaultTighteningForTruncation(_ allows: Bool) -> Self {
        self.allowsDefaultTighteningForTruncation = allows
        return self
    }
    
    @discardableResult
    func allowsDefaultTighteningForTruncation(_ value: some Publisher<Bool, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.allowsDefaultTighteningForTruncation)
        return self
    }
    
    @discardableResult
    func preferredMaxLayoutWidth(_ width: CGFloat) -> Self {
        self.preferredMaxLayoutWidth = width
        return self
    }
    
    @discardableResult
    func preferredMaxLayoutWidth(_ value: some Publisher<CGFloat, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.preferredMaxLayoutWidth)
        return self
    }
    
    @discardableResult
    func highlighted(_ highlighted: Bool) -> Self {
        self.isHighlighted = highlighted
        return self
    }
    
    @discardableResult
    func highlighted(_ value: some Publisher<Bool, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.isHighlighted)
        return self
    }
    
    @discardableResult
    func highlightedTextColor(_ color: UIColor?) -> Self {
        self.highlightedTextColor = color
        return self
    }
    
    @discardableResult
    func highlightedTextColor(_ value: some Publisher<UIColor?, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.highlightedTextColor)
        return self
    }
    
    @discardableResult
    func shadowColor(_ color: UIColor?) -> Self {
        self.shadowColor = color
        return self
    }
    
    @discardableResult
    func shadowColor(_ value: some Publisher<UIColor?, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.shadowColor)
        return self
    }
    
    @discardableResult
    func shadowOffset(_ offset: CGSize) -> Self {
        self.shadowOffset = offset
        return self
    }
    
    @discardableResult
    func shadowOffset(_ value: some Publisher<CGSize, Never>) -> Self {
        bind(value.eraseToAnyPublisher(), to: \UILabel.shadowOffset)
        return self
    }
}
