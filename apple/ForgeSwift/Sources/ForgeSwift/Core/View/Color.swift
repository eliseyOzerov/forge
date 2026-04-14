import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color

/// Immutable reference box so a Color value can carry an optional
/// inverse Color without the struct recursively containing itself.
/// Final + let-only + Sendable so it's safe to share across actors.
public final class _ColorInverseBox: @unchecked Sendable, Hashable {
    public let color: Color
    public init(_ color: Color) { self.color = color }
    public static func == (lhs: _ColorInverseBox, rhs: _ColorInverseBox) -> Bool {
        lhs === rhs || lhs.color == rhs.color
    }
    public func hash(into hasher: inout Hasher) { color.hash(into: &hasher) }
}

public struct Color: Equatable, Hashable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    /// Optional companion color for text/icons placed *on top of* this
    /// one. Populated for themed tokens (brand, status, accent) so
    /// `color.inverse` gives the designer's explicit contrast color.
    /// When nil, `inverse` falls back to auto black/white by luminance.
    private var _inverseBox: _ColorInverseBox?

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
        self._inverseBox = nil
    }

    public func withAlpha(_ alpha: Double) -> Color {
        var copy = self
        copy.alpha = alpha
        return copy
    }

    /// Attach an explicit contrast color. Use on themed tokens so
    /// `color.inverse` returns the designer's choice rather than the
    /// luminance-based fallback.
    public func withInverse(_ color: Color) -> Color {
        var copy = self
        copy._inverseBox = _ColorInverseBox(color)
        return copy
    }

    /// Contrast color for content placed on top of this one. Returns
    /// the explicit inverse set via `withInverse(_:)` if present;
    /// otherwise picks black or white based on perceptual luminance
    /// (OkLab L). Always non-nil — consumers don't need to fallback.
    public var inverse: Color {
        if let box = _inverseBox { return box.color }
        return luminance > 0.5 ? .black : .white
    }

    /// Perceptual luminance (OkLab L channel, 0…1). Better choice
    /// than sRGB-weighted luminance for contrast decisions because
    /// it maps closer to how humans perceive brightness.
    public var luminance: Double { oklab.l }

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

// MARK: - Hue

/// Canonical hue names. Twelve slots spanning the color wheel; the
/// enum is closed (hardcoded) so palette access is autocompletable.
/// Custom named colors live under `palette.custom`.
public enum Hue: String, CaseIterable, Sendable, Hashable {
    case red, orange, yellow, lime, green, teal, cyan, sky, blue, purple, magenta, pink
}

public extension Dictionary where Key == Hue, Value == Double {
    /// Wave-derived default hue angles (degrees, 0-360). Spacing is
    /// deliberately non-uniform: 30° between most hues, tighter
    /// 20° spacing around green/teal/cyan to give the teal family
    /// more room, and wider 40° spacing from cyan through sky to
    /// blue where perceptual difference is small.
    static var defaultHueAngles: [Hue: Double] {
        [
            .pink: 0,
            .red: 30,
            .orange: 60,
            .yellow: 90,
            .lime: 120,
            .green: 140,
            .teal: 160,
            .cyan: 190,
            .sky: 230,
            .blue: 270,
            .purple: 300,
            .magenta: 330,
        ]
    }
}

// MARK: - HueScale

/// Eleven colors at ascending "depth" (s0 brightest, s10 darkest).
/// Generated by sampling two 2D cubic beziers ("mirror bezier" below)
/// per OkLch component, so lightness and chroma each follow a smooth
/// curve through the cusp whose tangent there is parallel to the line
/// from start to end.
public struct HueScale: Equatable, Hashable, Sendable, Copyable {
    public var s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10: Color

    public init(
        s0: Color, s1: Color, s2: Color, s3: Color, s4: Color, s5: Color,
        s6: Color, s7: Color, s8: Color, s9: Color, s10: Color
    ) {
        self.s0 = s0; self.s1 = s1; self.s2 = s2; self.s3 = s3
        self.s4 = s4; self.s5 = s5; self.s6 = s6; self.s7 = s7
        self.s8 = s8; self.s9 = s9; self.s10 = s10
    }

    /// Index-based access (0…10). Returns s5 on out-of-range input —
    /// easier than crashing, and the middle step is the most neutral
    /// fallback.
    public subscript(step: Int) -> Color {
        switch step {
        case 0: return s0
        case 1: return s1
        case 2: return s2
        case 3: return s3
        case 4: return s4
        case 5: return s5
        case 6: return s6
        case 7: return s7
        case 8: return s8
        case 9: return s9
        case 10: return s10
        default: return s5
        }
    }

    public var steps: [Color] {
        [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10]
    }
}

// MARK: - Mirror Bezier (per-component)

/// Sample a "mirror bezier" — two cubic-bezier segments through
/// (start, cusp, end) with handles only at the cusp, the cusp tangent
/// parallel to the line from start to end. Each segment is normalized
/// to a CSS-style (0,0)-(1,1) bezier and evaluated via `Curve.bezier`.
///
/// `alpha` ∈ [0, 0.5] controls handle magnitude. 0 collapses to
/// piecewise linear; 0.5 stretches the cusp tangent back to the
/// endpoint's x position (maximum bend).
private func mirrorBezierSample(
    start: Double,
    cusp: Double,
    end: Double,
    alpha: Double,
    progress: Double
) -> Double {
    let a = max(0, min(0.5, alpha))
    let slope = end - start
    if progress <= 0.5 {
        let span = cusp - start
        if abs(span) < 1e-9 { return start }
        // Normalize segment 1 to (0,0)-(1,1):
        //   x ranges over [0, 0.5], y over [start, cusp].
        //   Cusp control point P2 is (0.5 - a, cusp - a·slope).
        //   Normalized: x2 = 1 - 2a, y2 = 1 - a·slope/span.
        let curve = Curve.bezier(0, 0, 1 - 2 * a, 1 - a * slope / span)
        return start + span * curve(progress / 0.5)
    } else {
        let span = end - cusp
        if abs(span) < 1e-9 { return end }
        // Normalize segment 2 to (0,0)-(1,1):
        //   x ranges over [0.5, 1], y over [cusp, end].
        //   Cusp control point P1 is (0.5 + a, cusp + a·slope).
        //   Normalized: x1 = 2a, y1 = a·slope/span.
        let curve = Curve.bezier(2 * a, a * slope / span, 1, 1)
        return cusp + span * curve((progress - 0.5) / 0.5)
    }
}

// MARK: - ScaleCurve

/// Parametrization for a HueScale in OkLch space. Three anchors
/// (start, cusp, end) provide lightness + chroma at s0/s5/s10;
/// `handleMagnitude` shapes the curve between them via a mirror
/// bezier whose cusp tangent is parallel to the start→end line.
///
/// At generation time, `hue` (degrees) is supplied and combined with
/// the anchors to produce 11 Colors via `apply(hueDegrees:)`.
///
/// Four default presets (`.primary`, `.vibrant`, `.muted`, `.grayscale`)
/// ship below.
public struct ScaleCurve: Sendable {
    /// Lightness + chroma at the bright end (s0).
    public var start: (l: Double, c: Double)
    /// Lightness + chroma at the cusp (s5 — the "canonical" step).
    public var cusp: (l: Double, c: Double)
    /// Lightness + chroma at the dark end (s10).
    public var end: (l: Double, c: Double)
    /// Cusp-tangent handle magnitude, in [0, 0.5]. 0 = piecewise
    /// linear; 0.5 = maximum bend (handles reach the segment ends).
    /// Default 0.33 gives a balanced S-curve.
    public var handleMagnitude: Double

    public init(
        start: (l: Double, c: Double),
        cusp: (l: Double, c: Double),
        end: (l: Double, c: Double),
        handleMagnitude: Double = 0.33
    ) {
        self.start = start
        self.cusp = cusp
        self.end = end
        self.handleMagnitude = handleMagnitude
    }

    /// Apply this curve at a given hue (degrees) to produce 11 Colors.
    /// Lightness and chroma are sampled independently along the mirror
    /// bezier; hue is constant across the scale.
    public func apply(hueDegrees: Double) -> HueScale {
        let h = hueDegrees * .pi / 180
        func step(_ progress: Double) -> Color {
            let l = mirrorBezierSample(
                start: start.l, cusp: cusp.l, end: end.l,
                alpha: handleMagnitude, progress: progress
            )
            let c = mirrorBezierSample(
                start: start.c, cusp: cusp.c, end: end.c,
                alpha: handleMagnitude, progress: progress
            )
            return Color(oklch: OkLch(l, c, h))
        }
        return HueScale(
            s0:  step(0.0), s1:  step(0.1), s2:  step(0.2), s3:  step(0.3),
            s4:  step(0.4), s5:  step(0.5), s6:  step(0.6), s7:  step(0.7),
            s8:  step(0.8), s9:  step(0.9), s10: step(1.0)
        )
    }

    // MARK: Default curves

    /// The "canonical" scale. Cusp sits near perceptual mid-lightness
    /// with moderate chroma — the step most readers would call "red"
    /// or "blue" at that hue.
    public static let primary = ScaleCurve(
        start: (l: 0.96, c: 0.02),
        cusp:  (l: 0.60, c: 0.18),
        end:   (l: 0.25, c: 0.12)
    )

    /// Maximum saturation without leaving the sRGB gamut too badly.
    /// Cusp is higher chroma than `.primary`.
    public static let vibrant = ScaleCurve(
        start: (l: 0.96, c: 0.02),
        cusp:  (l: 0.70, c: 0.26),
        end:   (l: 0.25, c: 0.14)
    )

    /// Low-chroma version of `.primary`. Good for tinted backgrounds
    /// and soft accents.
    public static let muted = ScaleCurve(
        start: (l: 0.96, c: 0.02),
        cusp:  (l: 0.65, c: 0.06),
        end:   (l: 0.25, c: 0.04)
    )

    /// Near-zero chroma — a tonal gray with a subtle hue bias.
    /// Linear-ish (handle magnitude small) since neutral scales
    /// don't benefit from the cusp emphasis.
    public static let grayscale = ScaleCurve(
        start: (l: 0.98, c: 0.002),
        cusp:  (l: 0.70, c: 0.002),
        end:   (l: 0.10, c: 0.002),
        handleMagnitude: 0.1
    )
}

// MARK: - HueToken

/// A single hue's full scale family. Consumers use:
///   - `.standard`  → the canonical Color at this hue (shortcut for primary.s5)
///   - `.system`    → the platform-native tint if one exists (nil for rotated tokens)
///   - `.primary` / `.vibrant` / `.muted` / `.grayscale` → HueScale
///   - `.rotate(_:)` → a fresh HueToken at a shifted hue
public struct HueToken: Equatable, Hashable, Sendable, Copyable {
    /// Canonical Hue this token represents, if any. Rotated tokens
    /// have `canonical == nil` (which also disables `.system`).
    public var canonical: Hue?
    public var angle: Double

    public var primary: HueScale
    public var vibrant: HueScale
    public var muted: HueScale
    public var grayscale: HueScale

    public init(
        canonical: Hue?,
        angle: Double,
        primary: HueScale,
        vibrant: HueScale,
        muted: HueScale,
        grayscale: HueScale
    ) {
        self.canonical = canonical
        self.angle = angle
        self.primary = primary
        self.vibrant = vibrant
        self.muted = muted
        self.grayscale = grayscale
    }

    /// The one-word default color for this hue: s5 of the primary
    /// scale. Use when you just want "the green" (not a specific
    /// weight of green).
    public var standard: Color { primary.s5 }

    /// Platform-native system tint for this hue, if one exists and
    /// this token is canonical (not rotated).
    public var system: Color? {
        guard let canonical else { return nil }
        #if canImport(UIKit)
        switch canonical {
        case .red:     return Color(platform: UIColor.systemRed)
        case .orange:  return Color(platform: UIColor.systemOrange)
        case .yellow:  return Color(platform: UIColor.systemYellow)
        case .green:   return Color(platform: UIColor.systemGreen)
        case .teal:    return Color(platform: UIColor.systemTeal)
        case .blue:    return Color(platform: UIColor.systemBlue)
        case .purple:  return Color(platform: UIColor.systemPurple)
        case .pink:    return Color(platform: UIColor.systemPink)
        case .cyan:    return Color(platform: UIColor.systemCyan)
        case .lime, .magenta, .sky:
            return nil
        }
        #else
        return nil
        #endif
    }

    /// Build a HueToken from a hue angle using the default scale
    /// curves. Used internally by palette generation.
    public static func generate(
        canonical: Hue?,
        angle: Double,
        primaryCurve: ScaleCurve = .primary,
        vibrantCurve: ScaleCurve = .vibrant,
        mutedCurve: ScaleCurve = .muted,
        grayscaleCurve: ScaleCurve = .grayscale
    ) -> HueToken {
        HueToken(
            canonical: canonical,
            angle: angle,
            primary: primaryCurve.apply(hueDegrees: angle),
            vibrant: vibrantCurve.apply(hueDegrees: angle),
            muted: mutedCurve.apply(hueDegrees: angle),
            grayscale: grayscaleCurve.apply(hueDegrees: angle)
        )
    }

    /// Return a fresh HueToken at a hue shifted by `degrees`. The
    /// rotated token's `canonical` is nil (so `.system` is nil),
    /// since rotation breaks the link to the canonical name.
    public func rotate(_ degrees: Double) -> HueToken {
        Self.generate(canonical: nil, angle: angle + degrees)
    }
}

// MARK: - CustomColors

/// App-extendable namespace for named colors that don't fit the
/// 12-hue grid (salmon, moss, lavender, etc.). Ships with a few
/// defaults derived from the palette's own positions so swapping
/// palettes also swaps the custom derivatives. Apps extend this
/// struct with more computed properties.
///
///     extension CustomColors {
///         var lavender: Color { palette.purple.muted.s3 }
///     }
public struct CustomColors: Sendable {
    /// Back-reference to the owning palette so custom colors can
    /// derive from it (e.g. `palette.red.muted.s3`).
    public let palette: ColorPalette

    public init(palette: ColorPalette) {
        self.palette = palette
    }

    // Default custom colors (sorted by hue).
    public var crimson: Color { palette.red.vibrant.s7 }
    public var salmon:  Color { palette.red.muted.s3 }
    public var peach:   Color { palette.orange.muted.s2 }
    public var moss:    Color { palette.green.muted.s7 }
    public var mint:    Color { palette.green.muted.s3 }
    public var azure:   Color { palette.blue.vibrant.s4 }
    public var indigo:  Color { palette.blue.primary.s8 }
    public var lavender: Color { palette.purple.muted.s3 }
}

// MARK: - ColorPalette

/// The generative color substrate. Twelve hue tokens plus a
/// `custom` namespace. Build via `.generate()` (default angles),
/// `.generate(hueAngles:)` (custom angles), or `.generate(seed:)`
/// (rotate all angles so the nearest canonical hue lands exactly
/// at the seed color's hue — coherent palettes around a brand color).
public struct ColorPalette: Sendable, Copyable {
    public var red: HueToken
    public var orange: HueToken
    public var yellow: HueToken
    public var lime: HueToken
    public var green: HueToken
    public var teal: HueToken
    public var cyan: HueToken
    public var sky: HueToken
    public var blue: HueToken
    public var purple: HueToken
    public var magenta: HueToken
    public var pink: HueToken

    public init(
        red: HueToken, orange: HueToken, yellow: HueToken, lime: HueToken,
        green: HueToken, teal: HueToken, cyan: HueToken, sky: HueToken,
        blue: HueToken, purple: HueToken, magenta: HueToken, pink: HueToken
    ) {
        self.red = red; self.orange = orange; self.yellow = yellow; self.lime = lime
        self.green = green; self.teal = teal; self.cyan = cyan; self.sky = sky
        self.blue = blue; self.purple = purple; self.magenta = magenta; self.pink = pink
    }

    /// Subscript access by Hue — useful for iterating or doing
    /// dict-driven customization.
    public subscript(hue: Hue) -> HueToken {
        switch hue {
        case .red: return red
        case .orange: return orange
        case .yellow: return yellow
        case .lime: return lime
        case .green: return green
        case .teal: return teal
        case .cyan: return cyan
        case .sky: return sky
        case .blue: return blue
        case .purple: return purple
        case .magenta: return magenta
        case .pink: return pink
        }
    }

    /// App-defined custom named colors. Derives from `self` so
    /// swapping palettes propagates through.
    public var custom: CustomColors {
        CustomColors(palette: self)
    }

    /// Build a palette from the 12 default hue angles (or a custom
    /// override map). All scales are generated via the default
    /// scale curves.
    public static func generate(hueAngles: [Hue: Double] = .defaultHueAngles) -> ColorPalette {
        let defaults: [Hue: Double] = .defaultHueAngles
        func tok(_ hue: Hue) -> HueToken {
            HueToken.generate(canonical: hue, angle: hueAngles[hue] ?? defaults[hue]!)
        }
        return ColorPalette(
            red: tok(.red), orange: tok(.orange), yellow: tok(.yellow), lime: tok(.lime),
            green: tok(.green), teal: tok(.teal), cyan: tok(.cyan), sky: tok(.sky),
            blue: tok(.blue), purple: tok(.purple), magenta: tok(.magenta), pink: tok(.pink)
        )
    }

    /// Build a palette coherent with a brand color. The seed's hue
    /// (in OkLch) is compared against the 12 canonical angles; the
    /// nearest canonical Hue is rotated to land exactly on the seed,
    /// and all other hues rotate by the same offset. Non-uniform
    /// default spacing is preserved — this is a rigid rotation, not
    /// a remapping.
    public static func generate(seed: Color) -> ColorPalette {
        let seedDegRaw = seed.oklch.h * 180 / .pi
        let seedDeg = normalizedDegrees(seedDegRaw)

        let defaults: [Hue: Double] = .defaultHueAngles

        // Find the canonical Hue whose default angle is nearest the
        // seed hue. That hue will be rotated to seedDeg exactly;
        // others rotate by the same offset.
        var nearestHue: Hue = .red
        var nearestDist = Double.infinity
        for hue in Hue.allCases {
            let d = angularDistance(defaults[hue]!, seedDeg)
            if d < nearestDist {
                nearestDist = d
                nearestHue = hue
            }
        }
        let offset = seedDeg - defaults[nearestHue]!

        var angles: [Hue: Double] = [:]
        for hue in Hue.allCases {
            angles[hue] = normalizedDegrees(defaults[hue]! + offset)
        }
        return generate(hueAngles: angles)
    }
}

/// Shortest angular distance between two degree values, in [0, 180].
private func angularDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

/// Normalize a degree value to [0, 360).
private func normalizedDegrees(_ deg: Double) -> Double {
    let m = deg.truncatingRemainder(dividingBy: 360)
    return m < 0 ? m + 360 : m
}

// MARK: - PriorityTokens

/// Four-level priority stack: primary (required) plus three optional
/// levels that fall back to the previous defined level. Ensures every
/// accessor always returns a valid Color, so consumers don't need
/// nil-checks.
public struct PriorityTokens: Sendable, Copyable {
    public var primary: Color
    private var _secondary: Color?
    private var _tertiary: Color?
    private var _quaternary: Color?

    public init(
        primary: Color,
        secondary: Color? = nil,
        tertiary: Color? = nil,
        quaternary: Color? = nil
    ) {
        self.primary = primary
        self._secondary = secondary
        self._tertiary = tertiary
        self._quaternary = quaternary
    }

    /// Falls back to primary when unset.
    public var secondary: Color { _secondary ?? primary }

    /// Falls back to secondary-or-primary.
    public var tertiary: Color { _tertiary ?? _secondary ?? primary }

    /// Falls back to tertiary-or-secondary-or-primary.
    public var quaternary: Color { _quaternary ?? _tertiary ?? _secondary ?? primary }

    // Mutable override accessors for the Copyable pattern.
    public var secondaryOverride: Color? {
        get { _secondary }
        set { _secondary = newValue }
    }
    public var tertiaryOverride: Color? {
        get { _tertiary }
        set { _tertiary = newValue }
    }
    public var quaternaryOverride: Color? {
        get { _quaternary }
        set { _quaternary = newValue }
    }
}

// MARK: - StatusTokens

/// Four semantic statuses, each with its own priority stack. Status
/// "primary" is typically the strong color (filled button bg, solid
/// icon); "secondary" the soft tint (banner background).
public struct StatusTokens: Sendable, Copyable {
    public var success: PriorityTokens
    public var warning: PriorityTokens
    public var error: PriorityTokens
    public var info: PriorityTokens

    public init(
        success: PriorityTokens,
        warning: PriorityTokens,
        error: PriorityTokens,
        info: PriorityTokens
    ) {
        self.success = success
        self.warning = warning
        self.error = error
        self.info = info
    }
}

// MARK: - ColorTheme

/// Application color theme. Compose via `.light(brand:)` or
/// `.dark(brand:)` factories and customize via `.copy { ... }`.
///
///     let theme = ColorTheme.light(brand: .hex(0x4A90E2))
///     let customized = theme.copy {
///         $0.surface.primary = .white
///         $0.brand.primary = .hex(0xFF6B6B).withInverse(.white)
///     }
///
/// Inject into the view tree via `Provided(theme) { ... }` and read
/// with `ctx.read(ColorTheme.self).label.primary`.
public struct ColorTheme: Sendable, Copyable {
    public var surface: PriorityTokens
    public var fill: PriorityTokens
    public var label: PriorityTokens
    public var status: StatusTokens
    public var brand: PriorityTokens
    public var palette: ColorPalette

    public init(
        surface: PriorityTokens,
        fill: PriorityTokens,
        label: PriorityTokens,
        status: StatusTokens,
        brand: PriorityTokens,
        palette: ColorPalette
    ) {
        self.surface = surface
        self.fill = fill
        self.label = label
        self.status = status
        self.brand = brand
        self.palette = palette
    }
}

// MARK: - ColorTheme factories

public extension ColorTheme {
    /// Light-mode theme. If `brand` is provided, the palette is
    /// generated coherently around it (via `.generate(seed:)`);
    /// otherwise the default 12-hue palette is used. Surfaces pull
    /// from the bright end of the grayscale; labels from the dark
    /// end; status tokens use their canonical hues' primary scales.
    static func light(brand: Color? = nil) -> ColorTheme {
        let palette = brand.map(ColorPalette.generate(seed:)) ?? .generate()
        let neutral = palette.blue.grayscale
        let brandColor = (brand ?? palette.blue.standard).withInverse(.white)

        return ColorTheme(
            surface: PriorityTokens(
                primary:    neutral.s0,
                secondary:  neutral.s1,
                tertiary:   neutral.s2
            ),
            fill: PriorityTokens(
                primary:    neutral.s1,
                secondary:  neutral.s2,
                tertiary:   neutral.s3
            ),
            label: PriorityTokens(
                primary:    neutral.s10,
                secondary:  neutral.s8,
                tertiary:   neutral.s6,
                quaternary: neutral.s5
            ),
            status: StatusTokens(
                success: PriorityTokens(
                    primary:   palette.green.primary.s6.withInverse(.white),
                    secondary: palette.green.muted.s1
                ),
                warning: PriorityTokens(
                    primary:   palette.orange.primary.s6.withInverse(.white),
                    secondary: palette.orange.muted.s1
                ),
                error: PriorityTokens(
                    primary:   palette.red.primary.s6.withInverse(.white),
                    secondary: palette.red.muted.s1
                ),
                info: PriorityTokens(
                    primary:   palette.blue.primary.s6.withInverse(.white),
                    secondary: palette.blue.muted.s1
                )
            ),
            brand: PriorityTokens(primary: brandColor),
            palette: palette
        )
    }

    /// Dark-mode theme. Mirrors `.light` with inverse positions:
    /// surfaces pull from dark end, labels from bright end. Status
    /// primaries use a slightly lighter step so they read clearly
    /// against dark backgrounds.
    static func dark(brand: Color? = nil) -> ColorTheme {
        let palette = brand.map(ColorPalette.generate(seed:)) ?? .generate()
        let neutral = palette.blue.grayscale
        let brandColor = (brand ?? palette.blue.standard).withInverse(.white)

        return ColorTheme(
            surface: PriorityTokens(
                primary:    neutral.s10,
                secondary:  neutral.s9,
                tertiary:   neutral.s8
            ),
            fill: PriorityTokens(
                primary:    neutral.s9,
                secondary:  neutral.s8,
                tertiary:   neutral.s7
            ),
            label: PriorityTokens(
                primary:    neutral.s0,
                secondary:  neutral.s2,
                tertiary:   neutral.s4,
                quaternary: neutral.s5
            ),
            status: StatusTokens(
                success: PriorityTokens(
                    primary:   palette.green.primary.s5.withInverse(.black),
                    secondary: palette.green.muted.s8
                ),
                warning: PriorityTokens(
                    primary:   palette.orange.primary.s5.withInverse(.black),
                    secondary: palette.orange.muted.s8
                ),
                error: PriorityTokens(
                    primary:   palette.red.primary.s5.withInverse(.white),
                    secondary: palette.red.muted.s8
                ),
                info: PriorityTokens(
                    primary:   palette.blue.primary.s5.withInverse(.white),
                    secondary: palette.blue.muted.s8
                )
            ),
            brand: PriorityTokens(primary: brandColor),
            palette: palette
        )
    }
}
