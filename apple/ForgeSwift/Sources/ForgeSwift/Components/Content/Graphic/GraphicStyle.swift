#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct GraphicStyle {
    public var size: CGSize?
    public var color: PlatformColor?
    public var strokeWidth: CGFloat?
    public var strokeCap: CGLineCap?
    public var strokeJoin: CGLineJoin?
    public var elementOverrides: [String: GraphicElementOverride]

    public init(
        size: CGSize? = nil,
        color: PlatformColor? = nil,
        strokeWidth: CGFloat? = nil,
        strokeCap: CGLineCap? = nil,
        strokeJoin: CGLineJoin? = nil,
        elementOverrides: [String: GraphicElementOverride] = [:]
    ) {
        self.size = size
        self.color = color
        self.strokeWidth = strokeWidth
        self.strokeCap = strokeCap
        self.strokeJoin = strokeJoin
        self.elementOverrides = elementOverrides
    }
}

public struct GraphicElementOverride {
    public var fill: PlatformColor?
    public var stroke: PlatformColor?
    public var strokeWidth: CGFloat?
    public var opacity: CGFloat?
    public var isHidden: Bool
    public var transform: CGAffineTransform?

    public init(
        fill: PlatformColor? = nil,
        stroke: PlatformColor? = nil,
        strokeWidth: CGFloat? = nil,
        opacity: CGFloat? = nil,
        isHidden: Bool = false,
        transform: CGAffineTransform? = nil
    ) {
        self.fill = fill
        self.stroke = stroke
        self.strokeWidth = strokeWidth
        self.opacity = opacity
        self.isHidden = isHidden
        self.transform = transform
    }
}
