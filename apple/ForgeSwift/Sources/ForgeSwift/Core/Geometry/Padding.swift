import Foundation

/// Edge insets (spacing around content).
public struct Padding: Equatable, Hashable, Sendable, Lerpable {
    public var top: Double
    public var bottom: Double
    public var leading: Double
    public var trailing: Double

    public init(top: Double = 0, bottom: Double = 0, leading: Double = 0, trailing: Double = 0) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    public init(all: Double) {
        self.top = all; self.bottom = all; self.leading = all; self.trailing = all
    }

    public init(horizontal: Double = 0, vertical: Double = 0) {
        self.leading = horizontal; self.trailing = horizontal
        self.top = vertical; self.bottom = vertical
    }

    public static let zero = Padding()
    
    public static func all(_ value: Double) -> Padding { Padding(all: value) }
    
    public static func horizontal(_ value: Double) -> Padding { Padding(horizontal: value) }
    public static func vertical(_ value: Double) -> Padding { Padding(vertical: value) }
    
    public static func top(_ value: Double) -> Padding { Padding(top: value) }
    public static func bottom(_ value: Double) -> Padding { Padding(bottom: value) }
    public static func leading(_ value: Double) -> Padding { Padding(leading: value) }
    public static func trailing(_ value: Double) -> Padding { Padding(trailing: value) }

    public var horizontal: Double { leading + trailing }
    public var vertical: Double { top + bottom }
    
    public func copy(top: Double? = nil, bottom: Double? = nil, leading: Double? = nil, trailing: Double? = nil) -> Padding {
        Padding(
            top: top ?? self.top,
            bottom: bottom ?? self.bottom,
            leading: leading ?? self.leading,
            trailing: trailing ?? self.trailing,
        )
    }
    
    public func top(_ value: Double) -> Padding { copy(top: value) }
    public func bottom(_ value: Double) -> Padding { copy(bottom: value) }
    public func leading(_ value: Double) -> Padding { copy(leading: value) }
    public func trailing(_ value: Double) -> Padding { copy(trailing: value) }

    public func lerp(to other: Padding, t: Double) -> Padding {
        Padding(top: top.lerp(to: other.top, t: t),
                bottom: bottom.lerp(to: other.bottom, t: t),
                leading: leading.lerp(to: other.leading, t: t),
                trailing: trailing.lerp(to: other.trailing, t: t))
    }
}
