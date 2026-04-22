/// Layout design notes — to be implemented.
///
/// Three categories of layout:
///
/// - **Sequential** — position of child N depends on children 0…N-1
///   (Flex, Wrap, Masonry).
/// - **Independent** — each child positioned in isolation within parent
///   bounds (Box/Stack).
/// - **Geometric** — position is a pure function of index + parameters
///   (Radial, Path, Fan).
///
/// Every layout takes a parent's bounds and previously laid out
/// children to determine where the next child should go. We should
/// be able to write a generic layout delegate.
///
/// Key protocols (planned):
/// - Measurable — `measure(proposed:) -> Size`
/// - Bound — `rect: Rect { get set }`
/// - LayoutChild — Measurable + Bound + delegate for resize
/// - LayoutChildDelegate — `didChildResize(_:)`
/// - Layout — Measurable + start/layout, holds slots
