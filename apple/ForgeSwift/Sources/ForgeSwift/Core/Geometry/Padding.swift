import CoreGraphics

/// Edge insets (spacing around content).
public struct Padding: Equatable, Hashable, Sendable {
    public var top: CGFloat
    public var bottom: CGFloat
    public var leading: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat = 0, bottom: CGFloat = 0, leading: CGFloat = 0, trailing: CGFloat = 0) {
        self.top = top
        self.bottom = bottom
        self.leading = leading
        self.trailing = trailing
    }

    public init(all: CGFloat) {
        self.top = all; self.bottom = all; self.leading = all; self.trailing = all
    }

    public init(horizontal: CGFloat = 0, vertical: CGFloat = 0) {
        self.leading = horizontal; self.trailing = horizontal
        self.top = vertical; self.bottom = vertical
    }

    public static let zero = Padding()

    public var horizontal: CGFloat { leading + trailing }
    public var vertical: CGFloat { top + bottom }
}
