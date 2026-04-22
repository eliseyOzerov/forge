/// The layout system separates **positioning** (where children sit) from
/// **rendering** (how children paint). A ``Layout`` is the algorithm that
/// measures children and assigns their rects. ``LayoutChild`` is the
/// interface the algorithm sees — measure and frame. ``LayoutParent``
/// is the callback a child uses to tell its parent "I changed size."
///
/// Three categories of layout exist:
///
/// - **Sequential** — position of child N depends on children 0…N-1
///   (Flex, Wrap, Masonry). Reads `laid` in `position`.
/// - **Independent** — each child positioned in isolation within parent
///   bounds (Box/Stack). Ignores `laid`.
/// - **Geometric** — position is a pure function of index + parameters
///   (Radial, Path, Fan). Ignores `laid`.

// MARK: - LayoutChild

/// The interface a layout algorithm sees for each child: something that
/// can be measured given a proposed size and assigned a rect.
@MainActor public protocol LayoutChild: AnyObject {
    /// Return the desired size given a proposed size from the parent.
    func measure(proposed: Size) -> Size

    /// The child's positioned rect. Set by the parent after layout.
    var rect: Rect { get set }

    /// Called by the parent after adopting this child. The child calls
    /// this closure when its intrinsic size changes (e.g. text changed,
    /// image loaded). The parent decides whether to re-run layout.
    var resize: (() -> Void)? { get set }
}

// MARK: - LayoutParent

/// The narrow interface a child holds to communicate upward. A child
/// doesn't control its parent — it can only report that its intrinsic
/// size changed, and the parent decides what to do.
@MainActor public protocol LayoutParent: AnyObject {
    func childDidResize(_ child: any LayoutChild)
}

// MARK: - LayoutSlot

/// Per-child data during a layout pass. Created by the layout engine
/// before each child is measured. The ``Layout`` algorithm writes
/// `bounds` (the proposal) and the origin of `rect` (the position).
/// The engine fills `rect.size` after measuring the child.
public struct LayoutSlot {
    /// Index in the child list.
    public let index: Int

    /// The child's layout interface (measure + rect).
    public let child: any LayoutChild

    /// Proposed size for this child, set by ``Layout/propose(_:_:)``.
    public var bounds: Size = .zero

    /// The child's rect. After `propose`, the engine measures the child
    /// and fills `size`. After `position`, the origin is set.
    public var rect: Rect = .zero

    public init(index: Int, child: any LayoutChild) {
        self.index = index
        self.child = child
    }
}

// MARK: - Layout

/// An algorithm that measures, positions, and sizes children within
/// a parent's bounds. Implementations are value types — state between
/// calls (cursors, accumulators) is stored as `mutating` properties
/// and reset in ``start(_:)``.
///
/// The engine calls methods in order:
///
/// 1. ``start(_:)`` — once, with the parent's bounds. Reset any state.
/// 2. For each child:
///    a. ``propose(_:_:)`` — set `slot.bounds` (the size proposal).
///    b. Engine measures the child: `slot.rect.size = child.measure(proposed: slot.bounds)`.
///    c. ``position(_:_:)`` — set `slot.rect.origin`.
/// 3. ``size(_:)`` — return the layout's own size.
public protocol Layout {
    /// Reset state for a new layout pass with the given parent bounds.
    mutating func start(_ bounds: Size)

    /// Set `slot.bounds` — the proposed size for this child. `laid`
    /// contains all previously laid-out slots.
    mutating func propose(_ slot: inout LayoutSlot, _ laid: [LayoutSlot])

    /// Set `slot.rect.origin` — the child's position. `slot.rect.size`
    /// has been filled by the engine after measuring. `laid` contains
    /// all previously positioned slots.
    mutating func position(_ slot: inout LayoutSlot, _ laid: [LayoutSlot])

    /// Return the layout's own size after all children are positioned.
    mutating func size(_ laid: [LayoutSlot]) -> Size
}

// MARK: - BoxLayout

/// Independent layout: all children share the same space, each aligned
/// within the padded bounds. Used by ``Box``.
public struct BoxLayout: Layout {
    public var padding: Padding
    public var alignment: Alignment
    public var frame: Frame

    private var bounds: Size = .zero
    private var inner: Size = .zero

    public init(
        padding: Padding = .zero,
        alignment: Alignment = .center,
        frame: Frame = .hug
    ) {
        self.padding = padding
        self.alignment = alignment
        self.frame = frame
    }

    public mutating func start(_ bounds: Size) {
        self.bounds = bounds
        self.inner = Size(
            max(0, bounds.width - padding.leading - padding.trailing),
            max(0, bounds.height - padding.top - padding.bottom)
        )
    }

    public mutating func propose(_ slot: inout LayoutSlot, _ laid: [LayoutSlot]) {
        slot.bounds = inner
    }

    public mutating func position(_ slot: inout LayoutSlot, _ laid: [LayoutSlot]) {
        let fx = (alignment.x + 1) / 2
        let fy = (alignment.y + 1) / 2
        let x = padding.leading + max(0, inner.width - slot.rect.width) * fx
        let y = padding.top + max(0, inner.height - slot.rect.height) * fy
        slot.rect = Rect(x: x, y: y, width: slot.rect.width, height: slot.rect.height)
    }

    public mutating func size(_ laid: [LayoutSlot]) -> Size {
        var maxW = 0.0, maxH = 0.0
        for slot in laid {
            maxW = max(maxW, slot.rect.width)
            maxH = max(maxH, slot.rect.height)
        }
        let w: Double = switch frame.width {
        case .fix(let v): v
        case .fill: bounds.width
        case .hug: maxW + padding.leading + padding.trailing
        }
        let h: Double = switch frame.height {
        case .fix(let v): v
        case .fill: bounds.height
        case .hug: maxH + padding.top + padding.bottom
        }
        return Size(w, h)
    }
}
