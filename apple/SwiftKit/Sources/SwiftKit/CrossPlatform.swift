#if canImport(UIKit)
import UIKit

// MARK: - UIKit Typealiases
public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
public typealias PlatformApplication = UIApplication
public typealias PlatformWindow = UIWindow
public typealias PlatformViewController = UIViewController

#elseif canImport(AppKit)
import AppKit

// MARK: - AppKit Typealiases
public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
public typealias PlatformApplication = NSApplication
public typealias PlatformWindow = NSWindow
public typealias PlatformViewController = NSViewController

#endif

// MARK: - Cross-Platform Extensions
#if canImport(UIKit)
extension UIView {
    func addSubviewWithConstraints(_ subview: UIView) {
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

#elseif canImport(AppKit)
extension NSView {
    func addSubviewWithConstraints(_ subview: NSView) {
        addSubview(subview)
        subview.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            subview.topAnchor.constraint(equalTo: topAnchor),
            subview.leadingAnchor.constraint(equalTo: leadingAnchor),
            subview.trailingAnchor.constraint(equalTo: trailingAnchor),
            subview.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
#endif
