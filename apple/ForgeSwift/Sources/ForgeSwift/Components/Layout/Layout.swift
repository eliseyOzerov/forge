/// The layout system separates **positioning** (where children sit) from
/// **rendering** (how children paint).
///
/// Three categories of layout exist:
///
/// - **Sequential** — position of child N depends on children 0…N-1
///   (Flex, Wrap, Masonry).
/// - **Independent** — each child positioned in isolation within parent
///   bounds (Box/Stack).
/// - **Geometric** — position is a pure function of index + parameters
///   (Radial, Path, Fan).

// MARK: - Measurable

/// Something that can report its desired size given a proposed size.
@MainActor public protocol Measurable {
    func measure(proposed: Size) -> Size
}

// MARK: - Sized

/// Something that has a settable size.
@MainActor public protocol Sized {
    var size: Size { get set }
}

// MARK: - Positioned

/// Something that has a settable position.
@MainActor public protocol Positioned {
    var position: Vec2 { get set }
}

// MARK: - LayoutChild

/// A child in the layout tree. Combines measurement, sizing, and
/// positioning into a single interface. Also carries a resize closure
/// so the child can notify its parent when its intrinsic size changes.
@MainActor public protocol LayoutChild: Measurable, Sized, Positioned {
    /// Set by the parent. The child calls this when its intrinsic size
    /// changes (e.g. text changed, image loaded). The parent decides
    /// whether to re-run layout.
    var resize: (() -> Void)? { get set }
}

// MARK: - LayoutSlot

/// Per-child data during a layout pass. Reference type so the delegate
/// can mutate it through existentials.
@MainActor public final class LayoutSlot {
    /// Index in the child list.
    public let index: Int

    /// The child's layout interface.
    public let child: any LayoutChild

    /// The child's assigned rect (position + size). Written by the
    /// delegate during measure (size) and layout (position).
    public var rect: Rect = .zero

    public init(index: Int, child: any LayoutChild) {
        self.index = index
        self.child = child
    }
}

// MARK: - LayoutChildDelegate

/// Delegate that drives child layout. The parent implements this to
/// define how its children are measured, positioned, and how the
/// parent's own size is determined.
///
/// The pipeline (driven by the parent's ``Measurable/measure(proposed:)``
/// and ``layout()``):
///
/// 1. **measure(proposed:)** on the parent (LayoutChild conformance):
///    a. Check own frame — if fixed or fill, short-circuit.
///    b. If hug, run the measurement pass:
///       - Call ``start(_:)`` with the proposed bounds.
///       - For each child: call ``measure(_:_:)`` to propose a size
///         and record the child's measured response.
///    c. Compute own size from measured children + frame + overflow.
///    d. Cache the result.
///
/// 2. **layout()** on the parent:
///    - Call ``start(_:)`` with the resolved bounds.
///    - For each child: call ``layout(_:_:)`` to assign position.
///    - Set each child's position and size.
@MainActor public protocol LayoutChildDelegate {
    /// Reset state for a new layout pass with the given parent bounds.
    mutating func start(_ bounds: Size)

    /// Propose a size to the child, measure it, and record the result
    /// in `slot.rect.size`. `measured` contains all previously measured
    /// slots.
    mutating func measure(_ slot: LayoutSlot, _ measured: [LayoutSlot])

    /// Assign `slot.rect.origin` — the child's position. `laid`
    /// contains all previously laid-out slots.
    mutating func layout(_ slot: LayoutSlot, _ laid: [LayoutSlot])
}

// MARK: - BoxLayout

/// Independent layout: all children share the same space, each aligned
/// within the padded bounds.
///
/// ## Measurement (how the box responds to `measure(proposed:)`)
///
/// The box first checks its own frame:
/// - **Fixed extent** — return the fixed size immediately. Children are
///   not measured (their sizes don't affect the box's size).
/// - **Fill extent** — return the proposed size immediately.
/// - **Hug extent** — measure all children against the inner bounds
///   (proposed minus padding). The box's size is the largest child on
///   each axis, plus padding. Min/max on the extent clamp the result.
///
/// For hug, each child is proposed the inner bounds. The child's
/// response depends on its own frame:
/// - A fixed child returns its fixed size.
/// - A fill child returns the proposed size (100% of available).
/// - A hug child asks its own children recursively.
///
/// If a child's measured size exceeds the inner bounds, the overflow
/// mode determines behavior:
/// - **clip** — child keeps its natural size; visually clipped.
/// - **visible** — child keeps its natural size; overflows visually.
/// - **scroll** — child is proposed unlimited size on the scroll axis;
///   the box's own size is clamped to the proposed bounds.
/// - **fit** — child's size is clamped to the inner bounds.
///
/// The measured size is cached. The cache is invalidated when:
/// - The proposed size changes.
/// - A child calls `resize` (intrinsic size changed).
/// - Layout parameters change (padding, alignment, frame, overflow).
///
/// ## Layout (how the box assigns positions)
///
/// Each child is positioned independently within the padded bounds
/// using alignment. The alignment factor maps [-1, 1] to [0, 1]:
///
///     fx = (alignment.x + 1) / 2
///     origin.x = padding.leading + (innerWidth - childWidth) * fx
///
/// Children that are larger than the inner bounds get clamped to the
/// padding edge (no negative offset).
public struct BoxLayout: LayoutChildDelegate {
    public var padding: Padding
    public var alignment: Alignment
    public var frame: Frame
    public var overflow: Overflow

    private var bounds: Size = .zero
    private var inner: Size = .zero

    public init(
        padding: Padding = .zero,
        alignment: Alignment = .center,
        frame: Frame = .hug,
        overflow: Overflow = .clip
    ) {
        self.padding = padding
        self.alignment = alignment
        self.frame = frame
        self.overflow = overflow
    }

    public mutating func start(_ bounds: Size) {
        self.bounds = bounds
        self.inner = Size(
            max(0, bounds.width - padding.leading - padding.trailing),
            max(0, bounds.height - padding.top - padding.bottom)
        )
    }

    public mutating func measure(_ slot: LayoutSlot, _ measured: [LayoutSlot]) {
        var proposed = inner

        // Scroll overflow: propose unlimited size on the scroll axis
        // so the child can measure its full content extent.
        if case .scroll(let config) = overflow {
            if config.axis != .vertical { proposed.width = .infinity }
            if config.axis != .horizontal { proposed.height = .infinity }
        }

        let childSize = slot.child.measure(proposed: proposed)
        slot.rect = Rect(x: 0, y: 0, width: childSize.width, height: childSize.height)
    }

    public mutating func layout(_ slot: LayoutSlot, _ laid: [LayoutSlot]) {
        let fx = (alignment.x + 1) / 2
        let fy = (alignment.y + 1) / 2
        let x = padding.leading + max(0, inner.width - slot.rect.width) * fx
        let y = padding.top + max(0, inner.height - slot.rect.height) * fy
        slot.rect = Rect(x: x, y: y, width: slot.rect.width, height: slot.rect.height)
    }

    /// Compute the box's own size from measured children.
    public func size(_ slots: [LayoutSlot]) -> Size {
        var maxW = 0.0, maxH = 0.0
        for slot in slots {
            maxW = max(maxW, slot.rect.width)
            maxH = max(maxH, slot.rect.height)
        }

        func resolve(_ extent: Extent, content: Double, proposed: Double) -> Double {
            switch extent {
            case .fix(let v):
                return v
            case .fill:
                return proposed
            case .hug(let min, let max):
                var v = content
                if let min { v = Swift.max(v, min) }
                if let max { v = Swift.min(v, max) }
                return v
            }
        }

        return Size(
            resolve(frame.width,
                    content: maxW + padding.leading + padding.trailing,
                    proposed: bounds.width),
            resolve(frame.height,
                    content: maxH + padding.top + padding.bottom,
                    proposed: bounds.height)
        )
    }
}
