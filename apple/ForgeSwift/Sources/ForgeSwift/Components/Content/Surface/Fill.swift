#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// What to fill a shape with.
public enum Fill {
    case color(Color)
    case gradient(Gradient)
    case image(ImageSource, fit: ContentFit = .cover)
    case shader(Shader)
}

// MARK: - Color

public struct Color: Equatable, Hashable, Sendable {
    public var red: CGFloat
    public var green: CGFloat
    public var blue: CGFloat
    public var alpha: CGFloat

    public init(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public func withAlpha(_ alpha: CGFloat) -> Color {
        Color(red, green, blue, alpha)
    }

    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public func lerp(to other: Color, t: CGFloat) -> Color {
        Color(red + (other.red - red) * t, green + (other.green - green) * t,
              blue + (other.blue - blue) * t, alpha + (other.alpha - alpha) * t)
    }

    public static func hex(_ hex: UInt32, alpha: CGFloat = 1) -> Color {
        Color(CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha)
    }

    public static let black = Color(0, 0, 0)
    public static let white = Color(1, 1, 1)
    public static let clear = Color(0, 0, 0, 0)
    public static let red = Color(1, 0, 0)
    public static let green = Color(0, 1, 0)
    public static let blue = Color(0, 0, 1)

    #if canImport(UIKit)
    public var platformColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    public init(platform: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        platform.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(r, g, b, a)
    }
    #endif
}

// MARK: - Gradient

public enum Gradient {
    case linear(LinearGradient)
    case radial(RadialGradient)
    case angular(AngularGradient)
}

public struct GradientStop: Sendable {
    public var color: Color
    public var location: CGFloat
    public init(_ color: Color, at location: CGFloat) { self.color = color; self.location = location }
}

public struct LinearGradient: Sendable {
    public var stops: [GradientStop]
    public var start: Vec2
    public var end: Vec2
    public init(stops: [GradientStop], start: Vec2 = Vec2(0.5, 0), end: Vec2 = Vec2(0.5, 1)) {
        self.stops = stops; self.start = start; self.end = end
    }
    public init(colors: [Color], start: Vec2 = Vec2(0.5, 0), end: Vec2 = Vec2(0.5, 1)) {
        let n = colors.count
        self.stops = colors.enumerated().map { GradientStop($1, at: n > 1 ? CGFloat($0) / CGFloat(n - 1) : 0) }
        self.start = start; self.end = end
    }
}

public struct RadialGradient: Sendable {
    public var stops: [GradientStop]
    public var center: Vec2
    public var radius: CGFloat
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), radius: CGFloat = 0.5) {
        self.stops = stops; self.center = center; self.radius = radius
    }
}

public struct AngularGradient: Sendable {
    public var stops: [GradientStop]
    public var center: Vec2
    public var startAngle: CGFloat
    public var endAngle: CGFloat
    public init(stops: [GradientStop], center: Vec2 = Vec2(0.5, 0.5), startAngle: CGFloat = 0, endAngle: CGFloat = .pi * 2) {
        self.stops = stops; self.center = center; self.startAngle = startAngle; self.endAngle = endAngle
    }
}

// MARK: - ImageSource

public struct ImageSource {
    #if canImport(UIKit)
    public let platformImage: UIImage
    public init(_ platformImage: UIImage) { self.platformImage = platformImage }
    #elseif canImport(AppKit)
    public let platformImage: NSImage
    public init(_ platformImage: NSImage) { self.platformImage = platformImage }
    #endif
}

// MARK: - ContentFit

public enum ContentFit: Sendable { case fill, contain, cover, scaleDown, none }

// MARK: - Shader

public struct Shader { public init() {} }

// MARK: - Paint

public struct Paint {
    public var fill: Fill
    public var blendMode: BlendMode
    public var opacity: CGFloat

    public init(_ fill: Fill, blendMode: BlendMode = .normal, opacity: CGFloat = 1) {
        self.fill = fill; self.blendMode = blendMode; self.opacity = opacity
    }

    public static func color(_ color: Color) -> Paint { Paint(.color(color)) }
    public static func gradient(_ gradient: Gradient) -> Paint { Paint(.gradient(gradient)) }
}

// MARK: - BlendMode

public enum BlendMode: Sendable {
    case normal, multiply, screen, overlay
    case darken, lighten, colorDodge, colorBurn
    case softLight, hardLight, difference, exclusion
    case hue, saturation, color, luminosity
    case clear, copy
    case sourceIn, sourceOut, sourceAtop
    case destinationOver, destinationIn, destinationOut, destinationAtop
    case xor

    #if canImport(CoreGraphics)
    public var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: .normal; case .multiply: .multiply; case .screen: .screen; case .overlay: .overlay
        case .darken: .darken; case .lighten: .lighten; case .colorDodge: .colorDodge; case .colorBurn: .colorBurn
        case .softLight: .softLight; case .hardLight: .hardLight; case .difference: .difference; case .exclusion: .exclusion
        case .hue: .hue; case .saturation: .saturation; case .color: .color; case .luminosity: .luminosity
        case .clear: .clear; case .copy: .copy
        case .sourceIn: .sourceIn; case .sourceOut: .sourceOut; case .sourceAtop: .sourceAtop
        case .destinationOver: .destinationOver; case .destinationIn: .destinationIn; case .destinationOut: .destinationOut; case .destinationAtop: .destinationAtop
        case .xor: .xor
        }
    }
    #endif
}

// MARK: - Stroke

public struct Stroke: Sendable {
    public var width: CGFloat
    public var cap: StrokeCap
    public var join: StrokeJoin
    public var alignment: CGFloat
    public var miterLimit: CGFloat
    public var dash: Dash?

    public init(width: CGFloat = 1, cap: StrokeCap = .round, join: StrokeJoin = .round, alignment: CGFloat = 0.5, miterLimit: CGFloat = 10, dash: Dash? = nil) {
        self.width = width; self.cap = cap; self.join = join; self.alignment = alignment; self.miterLimit = miterLimit; self.dash = dash
    }
}

public enum StrokeCap: Sendable {
    case butt, round, square
    #if canImport(CoreGraphics)
    public var cgLineCap: CGLineCap { switch self { case .butt: .butt; case .round: .round; case .square: .square } }
    #endif
}

public enum StrokeJoin: Sendable {
    case miter, round, bevel
    #if canImport(CoreGraphics)
    public var cgLineJoin: CGLineJoin { switch self { case .miter: .miter; case .round: .round; case .bevel: .bevel } }
    #endif
}

public struct Dash: Sendable {
    public var pattern: [CGFloat]
    public var phase: CGFloat
    public init(_ pattern: [CGFloat], phase: CGFloat = 0) { self.pattern = pattern; self.phase = phase }
    public static func even(_ length: CGFloat) -> Dash { Dash([length, length]) }
}

// MARK: - Filter

#if canImport(CoreImage)
import CoreImage
#endif

public struct Filter {
    #if canImport(CoreImage)
    public let ciFilter: CIFilter
    public init(_ ciFilter: CIFilter) { self.ciFilter = ciFilter }
    public static func gaussianBlur(radius: CGFloat) -> Filter {
        let f = CIFilter(name: "CIGaussianBlur")!
        f.setValue(radius, forKey: kCIInputRadiusKey)
        return Filter(f)
    }
    #endif
}

// MARK: - Transform2D

public struct Transform2D: Sendable {
    public var a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat

    public init(a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }

    public static let identity = Transform2D()

    public func concatenating(_ other: Transform2D) -> Transform2D {
        Transform2D(
            a: a * other.a + b * other.c, b: a * other.b + b * other.d,
            c: c * other.a + d * other.c, d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx, ty: tx * other.b + ty * other.d + other.ty
        )
    }

    #if canImport(CoreGraphics)
    public var cgAffineTransform: CGAffineTransform { CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty) }
    public init(_ cg: CGAffineTransform) { self.a = cg.a; self.b = cg.b; self.c = cg.c; self.d = cg.d; self.tx = cg.tx; self.ty = cg.ty }
    #endif
}

public enum RotationAxis: Sendable { case x, y, z }
public enum FillRule: Sendable { case winding, evenOdd }
