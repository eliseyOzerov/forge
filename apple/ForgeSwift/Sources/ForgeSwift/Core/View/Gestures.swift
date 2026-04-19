import Foundation

// MARK: - GestureEvent

/// Base for all gesture events. Provides focal position in both
/// local (relative to the gesture view) and global coordinates.
public struct GesturePosition {
    public let local: Vec2
    public let global: Vec2

    public init(local: Vec2, global: Vec2) {
        self.local = local
        self.global = global
    }
}

// MARK: - Tap Events

public struct TapStart {
    public let position: GesturePosition
}

public struct TapUpdate {
    public let position: GesturePosition
}

public struct TapEnd {
    public let position: GesturePosition
}

// MARK: - Double Tap Events

public struct DoubleTapStart {
    public let position: GesturePosition
}

public struct DoubleTapUpdate {
    public let position: GesturePosition
}

public struct DoubleTapEnd {
    public let position: GesturePosition
    public let firstTapPosition: GesturePosition
}

// MARK: - Long Press Events (shared by Press + Hold)

public struct LongPressStart {
    public let position: GesturePosition
}

public struct LongPressUpdate {
    public let position: GesturePosition
    public let delta: Vec2
    public let totalDelta: Vec2
    public let elapsed: Double
}

public struct LongPressEnd {
    public let position: GesturePosition
    public let totalDelta: Vec2
    public let elapsed: Double
}

// MARK: - Drag Events

public struct DragStart {
    public let position: GesturePosition
    public let initialPosition: GesturePosition
}

public struct DragUpdate {
    public let position: GesturePosition
    public let delta: Vec2
    public let totalDelta: Vec2
}

public struct DragEnd {
    public let position: GesturePosition
    public let totalDelta: Vec2
    public let velocity: Vec2
}

// MARK: - Pan Events (multi-pointer)

public struct PanStart {
    public let position: GesturePosition
    public let pointerCount: Int
}

public struct PanUpdate {
    public let position: GesturePosition
    public let focalDelta: Vec2
    public let totalFocalDelta: Vec2
    public let scale: Double
    public let scaleDelta: Double
    public let rotation: Double
    public let rotationDelta: Double
    public let pointerCount: Int
}

public struct PanEnd {
    public let position: GesturePosition
    public let totalFocalDelta: Vec2
    public let scale: Double
    public let rotation: Double
    public let velocity: Vec2
    public let pointerCount: Int
}

// MARK: - Gesture Configs

public struct TapConfig {
    public var maxDuration: Double
    public var slop: Double
    public var onStart: (@MainActor (TapStart) -> Void)?
    public var onUpdate: (@MainActor (TapUpdate) -> Void)?
    public var onEnd: (@MainActor (TapEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        maxDuration: Double = 0.3,
        slop: Double = 10,
        onStart: (@MainActor (TapStart) -> Void)? = nil,
        onUpdate: (@MainActor (TapUpdate) -> Void)? = nil,
        onEnd: (@MainActor (TapEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.maxDuration = maxDuration; self.slop = slop
        self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
    }
}

public struct DoubleTapConfig {
    public var maxTapDuration: Double
    public var betweenTapsDuration: Double
    public var slop: Double
    public var onStart: (@MainActor (DoubleTapStart) -> Void)?
    public var onUpdate: (@MainActor (DoubleTapUpdate) -> Void)?
    public var onEnd: (@MainActor (DoubleTapEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        maxTapDuration: Double = 0.3,
        betweenTapsDuration: Double = 0.3,
        slop: Double = 100,
        onStart: (@MainActor (DoubleTapStart) -> Void)? = nil,
        onUpdate: (@MainActor (DoubleTapUpdate) -> Void)? = nil,
        onEnd: (@MainActor (DoubleTapEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.maxTapDuration = maxTapDuration; self.betweenTapsDuration = betweenTapsDuration
        self.slop = slop; self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
    }
}

public struct PressConfig {
    public var pressDuration: Double
    public var slop: Double
    public var onStart: (@MainActor (LongPressStart) -> Void)?
    public var onUpdate: (@MainActor (LongPressUpdate) -> Void)?
    public var onEnd: (@MainActor (LongPressEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        pressDuration: Double = 0.5,
        slop: Double = 10,
        onStart: (@MainActor (LongPressStart) -> Void)? = nil,
        onUpdate: (@MainActor (LongPressUpdate) -> Void)? = nil,
        onEnd: (@MainActor (LongPressEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.pressDuration = pressDuration; self.slop = slop
        self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
    }
}

public struct HoldConfig {
    public var holdThreshold: Double
    public var slop: Double
    public var onStart: (@MainActor (LongPressStart) -> Void)?
    public var onUpdate: (@MainActor (LongPressUpdate) -> Void)?
    public var onEnd: (@MainActor (LongPressEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        holdThreshold: Double = 0.8,
        slop: Double = 10,
        onStart: (@MainActor (LongPressStart) -> Void)? = nil,
        onUpdate: (@MainActor (LongPressUpdate) -> Void)? = nil,
        onEnd: (@MainActor (LongPressEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.holdThreshold = holdThreshold; self.slop = slop
        self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
    }
}

public struct DragConfig {
    public var slop: Double
    public var onStart: (@MainActor (DragStart) -> Void)?
    public var onUpdate: (@MainActor (DragUpdate) -> Void)?
    public var onEnd: (@MainActor (DragEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        slop: Double = 10,
        onStart: (@MainActor (DragStart) -> Void)? = nil,
        onUpdate: (@MainActor (DragUpdate) -> Void)? = nil,
        onEnd: (@MainActor (DragEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.slop = slop; self.onStart = onStart
        self.onUpdate = onUpdate; self.onEnd = onEnd; self.onCancel = onCancel
    }
}

public struct PanConfig {
    public var minPointers: Int
    public var slop: Double
    public var onStart: (@MainActor (PanStart) -> Void)?
    public var onUpdate: (@MainActor (PanUpdate) -> Void)?
    public var onEnd: (@MainActor (PanEnd) -> Void)?
    public var onCancel: (@MainActor () -> Void)?

    public init(
        minPointers: Int = 2,
        slop: Double = 20,
        onStart: (@MainActor (PanStart) -> Void)? = nil,
        onUpdate: (@MainActor (PanUpdate) -> Void)? = nil,
        onEnd: (@MainActor (PanEnd) -> Void)? = nil,
        onCancel: (@MainActor () -> Void)? = nil
    ) {
        self.minPointers = minPointers; self.slop = slop
        self.onStart = onStart; self.onUpdate = onUpdate
        self.onEnd = onEnd; self.onCancel = onCancel
    }
}
