import Foundation

/// Edge insets (spacing around content).
@Init @Copy @Lerp
public struct Padding: Equatable, Hashable, Sendable {
    public var top: Double = 0
    public var bottom: Double = 0
    public var leading: Double = 0
    public var trailing: Double = 0
}

// MARK: - Convenience Initializers

public extension Padding {
    init(all: Double) {
        self.init(top: all, bottom: all, leading: all, trailing: all)
    }

    init(horizontal: Double = 0, vertical: Double = 0) {
        self.init(top: vertical, bottom: vertical, leading: horizontal, trailing: horizontal)
    }
}

// MARK: - Factories & Computed

public extension Padding {
    static let zero = Padding()

    static func all(_ value: Double) -> Padding { Padding(all: value) }
    static func horizontal(_ value: Double) -> Padding { Padding(horizontal: value) }
    static func vertical(_ value: Double) -> Padding { Padding(vertical: value) }

    var horizontal: Double { leading + trailing }
    var vertical: Double { top + bottom }
}
