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

// MARK: - Bound

/// Something that occupies a rect (position + size).
@MainActor public protocol Bound {
    var rect: Rect { get set }
}

// MARK: - LayoutChildDelegate

/// The narrow interface a child holds to its parent. The parent sets
/// itself as the child's delegate. The child calls
/// ``didChildResize(_:)`` when its intrinsic size changes. The parent
/// decides whether to re-run layout.
@MainActor public protocol LayoutChildDelegate {
    func didChildResize(_ child: any LayoutChild)
}

// MARK: - LayoutChild

/// A child in the layout tree. Can be measured, has a rect, and holds
/// a reference to its parent delegate for resize notification.
@MainActor public protocol LayoutChild: Measurable, Bound {
    /// Set by the parent when adopting this child. The child calls
    /// `delegate?.didChildResize(self)` when its intrinsic size changes.
    var delegate: (any LayoutChildDelegate)? { get set }
}

// MARK: - LayoutSlot

/// Per-child data during a layout pass. Reference type so the layout
/// can mutate it through collections.
@MainActor public final class LayoutSlot {
    /// Index in the child list.
    public let index: Int

    /// The child's layout interface.
    public let child: any LayoutChild

    /// The child's assigned rect (position + size). Written by the
    /// layout during measure (size) and layout (position).
    public var rect: Rect = .zero

    public init(index: Int, child: any LayoutChild) {
        self.index = index
        self.child = child
    }
}

// MARK: - Layout

/// An algorithm that measures, positions, and sizes children within
/// a parent's bounds. Holds its slots (children) and drives the
/// measure → layout pipeline.
///
/// The pipeline:
///
/// 1. **measure(proposed:)** — the parent asks the layout for its size:
///    a. Check own frame — if fixed or fill, short-circuit.
///    b. If hug, measure each child via the slots.
///    c. Compute own size from measured children + frame + overflow.
///    d. Cache the result.
///
/// 2. **layout()** — assign positions to all children:
///    - For each slot: assign position based on the algorithm.
///    - Write back to each child's rect.
@MainActor public protocol Layout: Measurable {
    /// The children this layout manages.
    var slots: [LayoutSlot] { get }

    func start(_ bounds: Size)
    func layout()
}
