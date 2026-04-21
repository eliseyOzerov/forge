import Foundation

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

/// RGBA color with perceptual luminance, color space conversions, palettes, and harmonies.
public struct Color: Equatable, Hashable, Sendable, Lerpable {
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

/// HSV color space (hue 0-360, saturation 0-1, value 0-1).
public struct HSV: Equatable {
    public var h: Double  // 0-360
    public var s: Double  // 0-1
    public var v: Double  // 0-1

    public init(_ h: Double, _ s: Double, _ v: Double) {
        self.h = h; self.s = s; self.v = v
    }
}

// MARK: - HSL

/// HSL color space (hue 0-360, saturation 0-1, lightness 0-1).
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

/// Canonical hue identifier. Open TokenKey — the 12 built-in hues are
/// static members; apps add their own via `extension Hue`. The token's
/// `defaultValue` is the hue angle in degrees; spacing is deliberately
/// non-uniform (30° spacing around red/orange, tighter 20° through
/// green/teal/cyan to give the teal family room, 40° from cyan to blue
/// where perceptual difference is small).
public struct Hue: TokenKey {
    public let name: String
    public let defaultValue: Double

    public init(_ name: String, _ defaultValue: Double) {
        self.name = name
        self.defaultValue = defaultValue
    }
}

public extension Hue {
    static let pink    = Hue("pink",     0)
    static let red     = Hue("red",     30)
    static let orange  = Hue("orange",  60)
    static let yellow  = Hue("yellow",  90)
    static let lime    = Hue("lime",   120)
    static let green   = Hue("green",  140)
    static let teal    = Hue("teal",   160)
    static let cyan    = Hue("cyan",   190)
    static let sky     = Hue("sky",    230)
    static let blue    = Hue("blue",   270)
    static let purple  = Hue("purple", 300)
    static let magenta = Hue("magenta", 330)

    /// The twelve canonical hues. Use wherever `Hue.allCases` used to
    /// apply — the open-struct form has no CaseIterable, but this
    /// array captures the built-in set explicitly.
    static let canonical: [Hue] = [
        .pink, .red, .orange, .yellow, .lime, .green,
        .teal, .cyan, .sky, .blue, .purple, .magenta,
    ]
}

public extension Dictionary where Key == Hue, Value == Double {
    /// Default angles for the 12 canonical hues, read from each
    /// hue's intrinsic `defaultValue`.
    static var defaultHueAngles: [Hue: Double] {
        Dictionary(uniqueKeysWithValues: Hue.canonical.map { ($0, $0.defaultValue) })
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
    /// this token is canonical (not rotated). Matched by name so
    /// user-added canonical hues return nil unless UIKit ships one
    /// under that name.
    public var system: Color? {
        #if canImport(UIKit)
        guard let canonical else { return nil }
        switch canonical.name {
        case "red":    return Color(platform: UIColor.systemRed)
        case "orange": return Color(platform: UIColor.systemOrange)
        case "yellow": return Color(platform: UIColor.systemYellow)
        case "green":  return Color(platform: UIColor.systemGreen)
        case "teal":   return Color(platform: UIColor.systemTeal)
        case "blue":   return Color(platform: UIColor.systemBlue)
        case "purple": return Color(platform: UIColor.systemPurple)
        case "pink":   return Color(platform: UIColor.systemPink)
        case "cyan":   return Color(platform: UIColor.systemCyan)
        default:       return nil
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

// MARK: - CustomColor

/// Named color outside the 12-hue grid (salmon, moss, lavender, etc.).
/// The token carries a closure that derives a Color from the palette,
/// so swapping the palette's seed automatically shifts every custom
/// color coherently. Override via the theme if a specific brand needs
/// a fixed value.
///
///     extension CustomColor {
///         static let rose = CustomColor("rose") { $0.pink.vibrant.s5 }
///     }
public struct CustomColor: NamedKey {
    public let name: String
    public let derive: @Sendable (ColorPalette) -> Color

    public init(_ name: String, _ derive: @escaping @Sendable (ColorPalette) -> Color) {
        self.name = name
        self.derive = derive
    }
}

public extension CustomColor {
    // MARK: Red family
    static let amaranth   = CustomColor("amaranth")   { $0.magenta.vibrant.s6 }
    static let burgundy   = CustomColor("burgundy")   { $0.red.muted.s10 }
    static let carmine    = CustomColor("carmine")    { $0.red.primary.s8 }
    static let claret     = CustomColor("claret")     { $0.red.muted.s7 }
    static let crimson    = CustomColor("crimson")    { $0.red.vibrant.s7 }
    static let dahlia     = CustomColor("dahlia")     { $0.red.vibrant.s8 }
    static let garnet     = CustomColor("garnet")     { $0.red.primary.s9 }
    static let maroon     = CustomColor("maroon")     { $0.red.muted.s9 }
    static let russet     = CustomColor("russet")     { $0.orange.primary.s9 }
    static let ruby       = CustomColor("ruby")       { $0.red.primary.s7 }
    static let scarlet    = CustomColor("scarlet")    { $0.red.vibrant.s5 }
    static let vermilion  = CustomColor("vermilion")  { $0.red.vibrant.s4 }

    // MARK: Pink family
    static let blush      = CustomColor("blush")      { $0.pink.muted.s2 }
    static let cerise     = CustomColor("cerise")     { $0.magenta.vibrant.s7 }
    static let coral      = CustomColor("coral")      { $0.orange.vibrant.s3 }
    static let rose       = CustomColor("rose")       { $0.pink.muted.s5 }
    static let salmon     = CustomColor("salmon")     { $0.red.muted.s3 }

    // MARK: Orange family
    static let amber      = CustomColor("amber")      { $0.orange.vibrant.s5 }
    static let apricot    = CustomColor("apricot")    { $0.orange.muted.s4 }
    static let clay       = CustomColor("clay")       { $0.orange.muted.s7 }
    static let ginger     = CustomColor("ginger")     { $0.orange.primary.s6 }
    static let peach      = CustomColor("peach")      { $0.orange.muted.s2 }
    static let rust       = CustomColor("rust")       { $0.orange.primary.s8 }

    // MARK: Yellow family
    static let arylide    = CustomColor("arylide")    { $0.yellow.muted.s5 }
    static let aureolin   = CustomColor("aureolin")   { $0.yellow.vibrant.s5 }
    static let cream      = CustomColor("cream")      { $0.yellow.muted.s1 }
    static let daffodil   = CustomColor("daffodil")   { $0.yellow.vibrant.s4 }
    static let dandelion  = CustomColor("dandelion")  { $0.yellow.primary.s4 }
    static let gold       = CustomColor("gold")       { $0.yellow.vibrant.s6 }
    static let marigold   = CustomColor("marigold")   { $0.orange.vibrant.s6 }
    static let mustard    = CustomColor("mustard")    { $0.yellow.muted.s7 }
    static let tuscany    = CustomColor("tuscany")    { $0.yellow.muted.s8 }

    // MARK: Lime family
    static let chartreuse = CustomColor("chartreuse") { $0.lime.vibrant.s4 }
    static let olive      = CustomColor("olive")      { $0.lime.muted.s8 }
    static let willow     = CustomColor("willow")     { $0.lime.muted.s3 }

    // MARK: Green family
    static let basil      = CustomColor("basil")      { $0.green.primary.s6 }
    static let beryl      = CustomColor("beryl")      { $0.teal.muted.s4 }
    static let emerald    = CustomColor("emerald")    { $0.green.vibrant.s6 }
    static let forest     = CustomColor("forest")     { $0.green.primary.s9 }
    static let jade       = CustomColor("jade")       { $0.green.primary.s7 }
    static let juniper    = CustomColor("juniper")    { $0.teal.muted.s7 }
    static let mint       = CustomColor("mint")       { $0.green.muted.s3 }
    static let moss       = CustomColor("moss")       { $0.green.muted.s7 }
    static let sage       = CustomColor("sage")       { $0.green.muted.s5 }
    static let seafoam    = CustomColor("seafoam")    { $0.teal.muted.s3 }
    static let viridian   = CustomColor("viridian")   { $0.teal.primary.s7 }

    // MARK: Cyan / Teal family
    static let turquoise  = CustomColor("turquoise")  { $0.cyan.vibrant.s4 }

    // MARK: Blue family
    static let aero       = CustomColor("aero")       { $0.sky.vibrant.s4 }
    static let alice      = CustomColor("alice")      { $0.sky.muted.s1 }
    static let azure      = CustomColor("azure")      { $0.blue.vibrant.s4 }
    static let cadet      = CustomColor("cadet")      { $0.blue.muted.s4 }
    static let cadmium    = CustomColor("cadmium")    { $0.blue.vibrant.s5 }
    static let celeste    = CustomColor("celeste")    { $0.sky.muted.s2 }
    static let cerulean   = CustomColor("cerulean")   { $0.sky.vibrant.s6 }
    static let cobalt     = CustomColor("cobalt")     { $0.blue.vibrant.s7 }
    static let indigo     = CustomColor("indigo")     { $0.blue.primary.s8 }
    static let navy       = CustomColor("navy")       { $0.blue.primary.s10 }
    static let periwinkle = CustomColor("periwinkle") { $0.blue.muted.s3 }
    static let sapphire   = CustomColor("sapphire")   { $0.blue.primary.s7 }

    // MARK: Purple / Violet family
    static let amethyst   = CustomColor("amethyst")   { $0.purple.vibrant.s7 }
    static let heather    = CustomColor("heather")    { $0.purple.muted.s6 }
    static let iris       = CustomColor("iris")       { $0.purple.primary.s6 }
    static let lavender   = CustomColor("lavender")   { $0.purple.muted.s3 }
    static let lilac      = CustomColor("lilac")      { $0.purple.muted.s4 }
    static let mauve      = CustomColor("mauve")      { $0.purple.muted.s5 }
    static let orchid     = CustomColor("orchid")     { $0.magenta.vibrant.s4 }
    static let plum       = CustomColor("plum")       { $0.purple.primary.s8 }
    static let violet     = CustomColor("violet")     { $0.purple.vibrant.s6 }

    // MARK: Magenta family
    static let fuchsia    = CustomColor("fuchsia")    { $0.magenta.vibrant.s5 }

    // MARK: Neutrals
    static let ash        = CustomColor("ash")        { $0.blue.grayscale.s4 }
    static let daisy      = CustomColor("daisy")      { $0.blue.grayscale.s0 }
    static let ebony      = CustomColor("ebony")      { $0.blue.grayscale.s10 }
    static let gray       = CustomColor("gray")       { $0.blue.grayscale.s5 }
    static let ivory      = CustomColor("ivory")      { $0.yellow.muted.s0 }
    static let pearl      = CustomColor("pearl")      { $0.blue.grayscale.s1 }
    static let raven      = CustomColor("raven")      { $0.blue.grayscale.s9 }
    static let sienna     = CustomColor("sienna")     { $0.orange.muted.s8 }
}

// MARK: - CustomColors

/// View onto a palette's custom colors. Resolves each token by
/// applying its derivation to the palette, with per-token overrides
/// for brand customization. `custom.crimson` is equivalent to
/// `custom[.crimson]`.
public struct CustomColors: Sendable {
    public let palette: ColorPalette
    public let overrides: [CustomColor: Color]

    public init(palette: ColorPalette, overrides: [CustomColor: Color] = [:]) {
        self.palette = palette
        self.overrides = overrides
    }

    public subscript(_ token: CustomColor) -> Color {
        overrides[token] ?? token.derive(palette)
    }

    // Red family
    public var amaranth:   Color { self[.amaranth] }
    public var burgundy:   Color { self[.burgundy] }
    public var carmine:    Color { self[.carmine] }
    public var claret:     Color { self[.claret] }
    public var crimson:    Color { self[.crimson] }
    public var dahlia:     Color { self[.dahlia] }
    public var garnet:     Color { self[.garnet] }
    public var maroon:     Color { self[.maroon] }
    public var russet:     Color { self[.russet] }
    public var ruby:       Color { self[.ruby] }
    public var scarlet:    Color { self[.scarlet] }
    public var vermilion:  Color { self[.vermilion] }

    // Pink family
    public var blush:      Color { self[.blush] }
    public var cerise:     Color { self[.cerise] }
    public var coral:      Color { self[.coral] }
    public var rose:       Color { self[.rose] }
    public var salmon:     Color { self[.salmon] }

    // Orange family
    public var amber:      Color { self[.amber] }
    public var apricot:    Color { self[.apricot] }
    public var clay:       Color { self[.clay] }
    public var ginger:     Color { self[.ginger] }
    public var peach:      Color { self[.peach] }
    public var rust:       Color { self[.rust] }

    // Yellow family
    public var arylide:    Color { self[.arylide] }
    public var aureolin:   Color { self[.aureolin] }
    public var cream:      Color { self[.cream] }
    public var daffodil:   Color { self[.daffodil] }
    public var dandelion:  Color { self[.dandelion] }
    public var gold:       Color { self[.gold] }
    public var marigold:   Color { self[.marigold] }
    public var mustard:    Color { self[.mustard] }
    public var tuscany:    Color { self[.tuscany] }

    // Lime family
    public var chartreuse: Color { self[.chartreuse] }
    public var olive:      Color { self[.olive] }
    public var willow:     Color { self[.willow] }

    // Green family
    public var basil:      Color { self[.basil] }
    public var beryl:      Color { self[.beryl] }
    public var emerald:    Color { self[.emerald] }
    public var forest:     Color { self[.forest] }
    public var jade:       Color { self[.jade] }
    public var juniper:    Color { self[.juniper] }
    public var mint:       Color { self[.mint] }
    public var moss:       Color { self[.moss] }
    public var sage:       Color { self[.sage] }
    public var seafoam:    Color { self[.seafoam] }
    public var viridian:   Color { self[.viridian] }

    // Cyan / Teal family
    public var turquoise:  Color { self[.turquoise] }

    // Blue family
    public var aero:       Color { self[.aero] }
    public var alice:      Color { self[.alice] }
    public var azure:      Color { self[.azure] }
    public var cadet:      Color { self[.cadet] }
    public var cadmium:    Color { self[.cadmium] }
    public var celeste:    Color { self[.celeste] }
    public var cerulean:   Color { self[.cerulean] }
    public var cobalt:     Color { self[.cobalt] }
    public var indigo:     Color { self[.indigo] }
    public var navy:       Color { self[.navy] }
    public var periwinkle: Color { self[.periwinkle] }
    public var sapphire:   Color { self[.sapphire] }

    // Purple / Violet family
    public var amethyst:   Color { self[.amethyst] }
    public var heather:    Color { self[.heather] }
    public var iris:       Color { self[.iris] }
    public var lavender:   Color { self[.lavender] }
    public var lilac:      Color { self[.lilac] }
    public var mauve:      Color { self[.mauve] }
    public var orchid:     Color { self[.orchid] }
    public var plum:       Color { self[.plum] }
    public var violet:     Color { self[.violet] }

    // Magenta family
    public var fuchsia:    Color { self[.fuchsia] }

    // Neutrals
    public var ash:        Color { self[.ash] }
    public var daisy:      Color { self[.daisy] }
    public var ebony:      Color { self[.ebony] }
    public var gray:       Color { self[.gray] }
    public var ivory:      Color { self[.ivory] }
    public var pearl:      Color { self[.pearl] }
    public var raven:      Color { self[.raven] }
    public var sienna:     Color { self[.sienna] }
}

// MARK: - ColorPalette

/// The generative color substrate. Twelve hue tokens plus a
/// `custom` namespace. Build via `.generate()` (default angles),
/// `.generate(hueAngles:)` (custom angles), or `.generate(seed:)`
/// (rotate all angles so the nearest canonical hue lands exactly
/// at the seed color's hue — coherent palettes around a brand color).
public struct ColorPalette: Sendable, Copyable {
    /// Hue tokens keyed by Hue. Canonical hues are populated by the
    /// `.generate(...)` factories; user-added hues live here too.
    public var tokens: [Hue: HueToken]

    /// Per-token overrides for custom-color derivations. By default
    /// every `CustomColor` falls back to its palette-derived value;
    /// set an entry here to pin a specific custom color to a fixed
    /// Color regardless of palette.
    public var customOverrides: [CustomColor: Color]

    public init(tokens: [Hue: HueToken], customOverrides: [CustomColor: Color] = [:]) {
        self.tokens = tokens
        self.customOverrides = customOverrides
    }

    /// Subscript access by Hue. Unknown hues are generated on demand
    /// from the hue's intrinsic angle — lazy fallback, not cached.
    public subscript(hue: Hue) -> HueToken {
        if let token = tokens[hue] { return token }
        return HueToken.generate(canonical: nil, angle: hue.defaultValue)
    }

    // Dot-accessors for the 12 canonical hues.
    public var pink:    HueToken { self[.pink] }
    public var red:     HueToken { self[.red] }
    public var orange:  HueToken { self[.orange] }
    public var yellow:  HueToken { self[.yellow] }
    public var lime:    HueToken { self[.lime] }
    public var green:   HueToken { self[.green] }
    public var teal:    HueToken { self[.teal] }
    public var cyan:    HueToken { self[.cyan] }
    public var sky:     HueToken { self[.sky] }
    public var blue:    HueToken { self[.blue] }
    public var purple:  HueToken { self[.purple] }
    public var magenta: HueToken { self[.magenta] }

    /// App-defined custom named colors. Derives from `self` so
    /// swapping palettes propagates through; `customOverrides`
    /// pins specific entries to fixed colors.
    public var custom: CustomColors {
        CustomColors(palette: self, overrides: customOverrides)
    }

    /// Build a palette from the 12 canonical hue angles (or a custom
    /// override map). All scales are generated via the default
    /// scale curves.
    public static func generate(hueAngles: [Hue: Double] = .defaultHueAngles) -> ColorPalette {
        var tokens: [Hue: HueToken] = [:]
        for hue in Hue.canonical {
            let angle = hueAngles[hue] ?? hue.defaultValue
            tokens[hue] = HueToken.generate(canonical: hue, angle: angle)
        }
        return ColorPalette(tokens: tokens)
    }

    /// Build a palette coherent with a brand color. The seed's hue
    /// (in OkLch) is compared against the 12 canonical angles; the
    /// nearest canonical Hue is rotated to land exactly on the seed,
    /// and all other hues rotate by the same offset. Non-uniform
    /// default spacing is preserved — this is a rigid rotation, not
    /// a remapping.
    public static func generate(seed: Color) -> ColorPalette {
        let seedDeg = normalizedDegrees(seed.oklch.h * 180 / .pi)

        var nearestHue: Hue = .red
        var nearestDist = Double.infinity
        for hue in Hue.canonical {
            let d = angularDistance(hue.defaultValue, seedDeg)
            if d < nearestDist {
                nearestDist = d
                nearestHue = hue
            }
        }
        let offset = seedDeg - nearestHue.defaultValue

        var angles: [Hue: Double] = [:]
        for hue in Hue.canonical {
            angles[hue] = normalizedDegrees(hue.defaultValue + offset)
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

// MARK: - ColorRole

/// Semantic color roles — `surface`, `fill`, `label`, `brand`. Open
/// NamedKey so apps can add their own roles (e.g. `.outline`).
public struct ColorRole: NamedKey {
    public let name: String
    public init(_ name: String) { self.name = name }
}

public extension ColorRole {
    static let surface = ColorRole("surface")
    static let fill    = ColorRole("fill")
    static let label   = ColorRole("label")
    static let brand   = ColorRole("brand")
}

// MARK: - ColorTheme

/// Application color theme. Compose via `.light(brand:)` or
/// `.dark(brand:)` factories and customize via `.copy { ... }`.
///
///     let theme = ColorTheme.light(brand: .hex(0x4A90E2))
///     let customized = theme.copy {
///         $0.roles[.surface] = PriorityTokens(primary: .white)
///         $0.roles[.brand]   = PriorityTokens(primary: .hex(0xFF6B6B).withInverse(.white))
///     }
///
/// Inject into the view tree via `Provided(theme) { ... }` and read
/// with `ctx.theme(.color).label.primary`.
public struct ColorTheme: Sendable, Copyable {
    /// Role-keyed priority stacks. Custom roles live here too.
    public var roles: [ColorRole: PriorityTokens<Color>]
    public var status: StatusTokens<PriorityTokens<Color>>
    public var palette: ColorPalette

    public init(
        roles: [ColorRole: PriorityTokens<Color>],
        status: StatusTokens<PriorityTokens<Color>>,
        palette: ColorPalette
    ) {
        self.roles = roles
        self.status = status
        self.palette = palette
    }

    /// Lookup with a safe fallback — unknown roles resolve to a single
    /// neutral primary (palette's mid-gray). Keeps call sites crash-
    /// free for user-added roles that might not be populated yet.
    public subscript(_ role: ColorRole) -> PriorityTokens<Color> {
        roles[role] ?? PriorityTokens(primary: palette.blue.grayscale.s5)
    }

    public var surface: PriorityTokens<Color> { self[.surface] }
    public var fill:    PriorityTokens<Color> { self[.fill] }
    public var label:   PriorityTokens<Color> { self[.label] }
    public var brand:   PriorityTokens<Color> { self[.brand] }
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
            roles: [
                .surface: PriorityTokens(primary: neutral.s0, secondary: neutral.s1, tertiary: neutral.s2),
                .fill:    PriorityTokens(primary: neutral.s1, secondary: neutral.s2, tertiary: neutral.s3),
                .label:   PriorityTokens(
                    primary:    neutral.s10,
                    secondary:  neutral.s8,
                    tertiary:   neutral.s6,
                    quaternary: neutral.s5
                ),
                .brand:   PriorityTokens(primary: brandColor),
            ],
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
            roles: [
                .surface: PriorityTokens(primary: neutral.s10, secondary: neutral.s9, tertiary: neutral.s8),
                .fill:    PriorityTokens(primary: neutral.s9,  secondary: neutral.s8, tertiary: neutral.s7),
                .label:   PriorityTokens(
                    primary:    neutral.s0,
                    secondary:  neutral.s2,
                    tertiary:   neutral.s4,
                    quaternary: neutral.s5
                ),
                .brand:   PriorityTokens(primary: brandColor),
            ],
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
            palette: palette
        )
    }
}

// MARK: - CoreGraphics Bridge

#if canImport(CoreGraphics)
import CoreGraphics

extension Color {
    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
#endif

// MARK: - UIKit Bridge

#if canImport(UIKit)
import UIKit

extension Color {
    public var platformColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }
    public init(platform: UIColor) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        platform.getRed(&r, green: &g, blue: &b, alpha: &a)
        self.init(Double(r), Double(g), Double(b), Double(a))
    }
}
#endif
