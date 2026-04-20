import Foundation

/// Edge insets (spacing around content).
@Init @Copy @Lerp
public struct Padding: Equatable, Hashable, Sendable {
    public var top: Double = 0
    public var bottom: Double = 0
    public var leading: Double = 0
    public var trailing: Double = 0

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

    public var horizontal: Double { leading + trailing }
    public var vertical: Double { top + bottom }
}
