import Foundation

/// Edge insets (spacing around content).
public struct Padding: Equatable, Hashable, Sendable {
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

    public var horizontal: Double { leading + trailing }
    public var vertical: Double { top + bottom }
}
