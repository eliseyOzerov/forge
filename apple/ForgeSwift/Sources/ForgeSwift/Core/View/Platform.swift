#if canImport(UIKit)
import UIKit
public typealias PlatformView = UIView
public typealias PlatformColor = UIColor
public typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
public typealias PlatformView = NSView
public typealias PlatformColor = NSColor
public typealias PlatformFont = NSFont
#endif
