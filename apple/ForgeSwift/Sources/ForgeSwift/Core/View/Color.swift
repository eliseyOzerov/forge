import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color

public struct Color: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    public func withAlpha(_ alpha: Double) -> Color {
        Color(red, green, blue, alpha)
    }

    // MARK: Hex

    public static func hex(_ hex: UInt32, alpha: Double = 1) -> Color {
        Color(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255, alpha)
    }

    // MARK: Constants

    public static let black = Color(0, 0, 0)
    public static let white = Color(1, 1, 1)
    public static let clear = Color(0, 0, 0, 0)
    public static let red = Color(1, 0, 0)
    public static let green = Color(0, 1, 0)
    public static let blue = Color(0, 0, 1)
    public static let gray = Color(0.5, 0.5, 0.5)
    public static let orange = Color(1, 0.6, 0)
    public static let yellow = Color(1, 1, 0)
    public static let cyan = Color(0, 1, 1)
    public static let magenta = Color(1, 0, 1)
    public static let purple = Color(0.5, 0, 0.8)
    public static let pink = Color(1, 0.4, 0.6)
    public static let teal = Color(0, 0.7, 0.7)
    public static let lime = Color(0.5, 1, 0)

    #if canImport(CoreGraphics)
    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    #endif

    #if canImport(UIKit)
    public var platformColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    public init(platform: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        platform.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(Double(r), Double(g), Double(b), Double(a))
    }
    #endif
}

// MARK: - OkLab

/// Perceptually uniform color space. L = lightness (0-1),
/// a = green-red axis, b = blue-yellow axis.
public struct OkLab: Equatable {
    public var l: Double
    public var a: Double
    public var b: Double

    public init(_ l: Double, _ a: Double, _ b: Double) {
        self.l = l; self.a = a; self.b = b
    }
}

// MARK: - OkLch

/// Perceptually uniform cylindrical color space. l = lightness (0-1),
/// c = chroma (saturation), h = hue (radians).
public struct OkLch: Equatable {
    public var l: Double
    public var c: Double
    public var h: Double

    public init(_ l: Double, _ c: Double, _ h: Double) {
        self.l = l; self.c = c; self.h = h
    }
}

// MARK: - HSV

public struct HSV: Equatable {
    public var h: Double  // 0-360
    public var s: Double  // 0-1
    public var v: Double  // 0-1

    public init(_ h: Double, _ s: Double, _ v: Double) {
        self.h = h; self.s = s; self.v = v
    }
}

// MARK: - HSL

public struct HSL: Equatable {
    public var h: Double  // 0-360
    public var s: Double  // 0-1
    public var l: Double  // 0-1

    public init(_ h: Double, _ s: Double, _ l: Double) {
        self.h = h; self.s = s; self.l = l
    }
}

// MARK: - Color ↔ OkLab Conversion

public extension Color {
    var oklab: OkLab {
        let r = srgbToLinear(red)
        let g = srgbToLinear(green)
        let b = srgbToLinear(blue)

        let l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
        let m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
        let s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b

        let l_ = cbrt(l), m_ = cbrt(m), s_ = cbrt(s)

        return OkLab(
            0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
            1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
            0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
        )
    }

    init(oklab lab: OkLab, alpha: Double = 1) {
        let l_ = lab.l + 0.3963377774 * lab.a + 0.2158037573 * lab.b
        let m_ = lab.l - 0.1055613458 * lab.a - 0.0638541728 * lab.b
        let s_ = lab.l - 0.0894841775 * lab.a - 1.2914855480 * lab.b

        let l = l_ * l_ * l_
        let m = m_ * m_ * m_
        let s = s_ * s_ * s_

        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        self.init(linearToSrgb(r), linearToSrgb(g), linearToSrgb(b), alpha)
    }
}

// MARK: - Color ↔ OkLch Conversion

public extension Color {
    var oklch: OkLch {
        let lab = oklab
        let c = sqrt(lab.a * lab.a + lab.b * lab.b)
        let h = (abs(lab.a) < 1e-6 && abs(lab.b) < 1e-6) ? 0 : atan2(lab.b, lab.a)
        return OkLch(lab.l, c, h)
    }

    init(oklch lch: OkLch, alpha: Double = 1) {
        let lab = OkLab(lch.l, lch.c * cos(lch.h), lch.c * sin(lch.h))
        self.init(oklab: lab, alpha: alpha)
    }
}

// MARK: - Color ↔ HSV Conversion

public extension Color {
    var hsv: HSV {
        let cMax = max(red, green, blue)
        let cMin = min(red, green, blue)
        let delta = cMax - cMin

        var h: Double = 0
        if delta > 0 {
            if cMax == red { h = 60 * fmod((green - blue) / delta + 6, 6) }
            else if cMax == green { h = 60 * ((blue - red) / delta + 2) }
            else { h = 60 * ((red - green) / delta + 4) }
        }
        let s = cMax > 0 ? delta / cMax : 0
        return HSV(h, s, cMax)
    }

    init(hsv: HSV, alpha: Double = 1) {
        let h = hsv.h, s = hsv.s, v = hsv.v
        let c = v * s
        let x = c * (1 - abs(fmod(h / 60, 2) - 1))
        let m = v - c

        let (r, g, b): (Double, Double, Double)
        switch h {
        case 0..<60:    (r, g, b) = (c, x, 0)
        case 60..<120:  (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default:        (r, g, b) = (c, 0, x)
        }
        self.init(r + m, g + m, b + m, alpha)
    }
}

// MARK: - Color ↔ HSL Conversion

public extension Color {
    var hsl: HSL {
        let cMax = max(red, green, blue)
        let cMin = min(red, green, blue)
        let delta = cMax - cMin
        let l = (cMax + cMin) / 2

        var h: Double = 0
        if delta > 0 {
            if cMax == red { h = 60 * fmod((green - blue) / delta + 6, 6) }
            else if cMax == green { h = 60 * ((blue - red) / delta + 2) }
            else { h = 60 * ((red - green) / delta + 4) }
        }
        let s = delta > 0 ? delta / (1 - abs(2 * l - 1)) : 0
        return HSL(h, s, l)
    }

    init(hsl: HSL, alpha: Double = 1) {
        let h = hsl.h, s = hsl.s, l = hsl.l
        let c = (1 - abs(2 * l - 1)) * s
        let x = c * (1 - abs(fmod(h / 60, 2) - 1))
        let m = l - c / 2

        let (r, g, b): (Double, Double, Double)
        switch h {
        case 0..<60:    (r, g, b) = (c, x, 0)
        case 60..<120:  (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default:        (r, g, b) = (c, 0, x)
        }
        self.init(r + m, g + m, b + m, alpha)
    }
}

// MARK: - Interpolation

public extension Color {
    /// Perceptually smooth interpolation via OkLab (default).
    func lerp(to other: Color, t: Double) -> Color {
        let a = oklab, b = other.oklab
        let lab = OkLab(
            a.l + (b.l - a.l) * t,
            a.a + (b.a - a.a) * t,
            a.b + (b.b - a.b) * t
        )
        let alpha = self.alpha + (other.alpha - self.alpha) * t
        return Color(oklab: lab, alpha: alpha)
    }

    /// Interpolation in a specific color space.
    func lerp(to other: Color, t: Double, in space: ColorSpace) -> Color {
        switch space {
        case .srgb:
            return Color(
                red + (other.red - red) * t,
                green + (other.green - green) * t,
                blue + (other.blue - blue) * t,
                alpha + (other.alpha - alpha) * t
            )
        case .oklab:
            return lerp(to: other, t: t)
        case .oklch:
            let a = oklch, b = other.oklch
            let l = a.l + (b.l - a.l) * t
            let c = a.c + (b.c - a.c) * t
            let h = lerpAngle(a.h, b.h, t)
            let alpha = self.alpha + (other.alpha - self.alpha) * t
            return Color(oklch: OkLch(l, c, h), alpha: alpha)
        }
    }
}

public enum ColorSpace {
    case srgb, oklab, oklch
}

// MARK: - Manipulation (via OkLch)

public extension Color {
    /// Darken by amount (0-1). 0 = unchanged, 1 = black.
    func darker(_ amount: Double = 0.1) -> Color {
        var lch = oklch
        lch.l = max(0, lch.l * (1 - amount))
        return Color(oklch: lch, alpha: alpha)
    }

    /// Lighten by amount (0-1). 0 = unchanged, 1 = white.
    func lighter(_ amount: Double = 0.1) -> Color {
        var lch = oklch
        lch.l = min(1, lch.l + (1 - lch.l) * amount)
        return Color(oklch: lch, alpha: alpha)
    }

    /// Increase saturation by amount (0-1).
    func saturated(_ amount: Double = 0.1) -> Color {
        var lch = oklch
        lch.c = min(0.5, lch.c + amount * 0.5)
        return Color(oklch: lch, alpha: alpha)
    }

    /// Decrease saturation by amount (0-1).
    func desaturated(_ amount: Double = 0.1) -> Color {
        var lch = oklch
        lch.c = max(0, lch.c - amount * 0.5)
        return Color(oklch: lch, alpha: alpha)
    }

    /// Rotate hue by degrees.
    func rotated(_ degrees: Double) -> Color {
        var lch = oklch
        lch.h = lch.h + degrees * .pi / 180
        return Color(oklch: lch, alpha: alpha)
    }

    /// Set specific OkLch components.
    func withLightness(_ l: Double) -> Color {
        var lch = oklch; lch.l = l; return Color(oklch: lch, alpha: alpha)
    }

    func withChroma(_ c: Double) -> Color {
        var lch = oklch; lch.c = c; return Color(oklch: lch, alpha: alpha)
    }

    func withHue(_ degrees: Double) -> Color {
        var lch = oklch; lch.h = degrees * .pi / 180; return Color(oklch: lch, alpha: alpha)
    }
}

// MARK: - Harmonies

public extension Color {
    func complementary() -> Color { rotated(180) }

    func triadic() -> [Color] {
        [rotated(120), self, rotated(240)]
    }

    func tetradic() -> [Color] {
        [self, rotated(90), rotated(180), rotated(270)]
    }

    func analogous(count: Int = 3, angle: Double = 30) -> [Color] {
        let half = Double(count / 2)
        return (0..<count).map { i in
            rotated((Double(i) - half) * angle)
        }
    }

    func splitComplementary() -> [Color] {
        [rotated(150), self, rotated(210)]
    }
}

// MARK: - Palette

public extension Color {
    /// Generate darker shades.
    func shades(count: Int = 5) -> [Color] {
        (0..<count).map { i in
            darker(Double(i + 1) / Double(count + 1))
        }
    }

    /// Generate lighter tints.
    func tints(count: Int = 5) -> [Color] {
        (0..<count).map { i in
            lighter(Double(i + 1) / Double(count + 1))
        }
    }

    /// Generate a full scale from dark to light through this color.
    func scale(count: Int = 11) -> [Color] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return Color.black.lerp(to: .white, t: t, in: .oklch)
                .withChroma(oklch.c)
                .withHue(oklch.h * 180 / .pi)
        }
    }
}

// MARK: - Gamma Helpers

private func srgbToLinear(_ c: Double) -> Double {
    c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
}

private func linearToSrgb(_ c: Double) -> Double {
    let clamped = min(max(c, 0), 1)
    return clamped <= 0.0031308 ? 12.92 * clamped : 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
}

private func cbrt(_ x: Double) -> Double {
    x >= 0 ? pow(x, 1.0 / 3.0) : -pow(-x, 1.0 / 3.0)
}

/// Shortest-path angle interpolation.
private func lerpAngle(_ a: Double, _ b: Double, _ t: Double) -> Double {
    var diff = b - a
    while diff > .pi { diff -= 2 * .pi }
    while diff < -.pi { diff += 2 * .pi }
    return a + diff * t
}
