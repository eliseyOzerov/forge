#if canImport(UIKit)
import UIKit
/// UIView on iOS, NSView on macOS.
public typealias PlatformView = UIView
/// UIColor on iOS, NSColor on macOS.
public typealias PlatformColor = UIColor
/// UIFont on iOS, NSFont on macOS.
public typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
/// UIView on iOS, NSView on macOS.
public typealias PlatformView = NSView
/// UIColor on iOS, NSColor on macOS.
public typealias PlatformColor = NSColor
/// UIFont on iOS, NSFont on macOS.
public typealias PlatformFont = NSFont
#endif
