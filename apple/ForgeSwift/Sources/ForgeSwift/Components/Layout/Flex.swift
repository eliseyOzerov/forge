// MARK: - Spread

/// Item distribution mode within a flex container.
/// If this is set, the container will expand in its main axis.
/// No spread means flex will shrink around its content
public enum Spread: Sendable {
    case packed
    case between
    case around
    case even
}

// MARK: - Flex

/// Flex container arranging children along an axis with optional wrapping.
///
/// Use `Column` or `Row` convenience functions to create vertical or
/// horizontal flex containers. Configure layout via `FlexStyle`.
public struct Flex: ContainerView {
    public var style: FlexStyle
    public var children: [any View]

    public init(_ style: FlexStyle, children: [any View]) {
        self.style = style; self.children = children
    }

    public init(_ style: FlexStyle, @ChildrenBuilder content: () -> [any View]) {
        self.style = style; self.children = content()
    }

    /// Configure style. The callback receives the current style for modification.
    public func style(_ build: (FlexStyle) -> FlexStyle) -> Flex {
        var copy = self
        copy.style = build(style)
        return copy
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        FlexRenderer(style: style)
        #else
        fatalError("Flex not yet implemented for this platform")
        #endif
    }
}

// MARK: - FlexStyle

/// Layout configuration for a flex container (axis, spacing, alignment, spread, wrapping).
@Init @Copy @Merge
public struct FlexStyle: Sendable {
    public var axis: Axis = .horizontal
    public var spacing: Double = 8
    public var lineSpacing: Double = 8
    public var alignment: Alignment = .center
    public var spread: Spread? = nil
    public var wrap: Bool = false
    public var crossFill: CrossFill = .sibling
}

// MARK: - Column & Row

/// Creates a vertical flex container arranging children top-to-bottom.
@MainActor public func Column(spacing: Double = 8, alignment: Alignment = .topLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, @ChildrenBuilder content: () -> [any View]) -> Flex {
    Flex(FlexStyle(axis: .vertical, spacing: spacing, alignment: alignment, spread: spread, crossFill: crossFill), content: content)
}

/// Creates a vertical flex container arranging children top-to-bottom.
@MainActor public func Column(spacing: Double = 8, alignment: Alignment = .topLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, children: [any View]) -> Flex {
    Flex(FlexStyle(axis: .vertical, spacing: spacing, alignment: alignment, spread: spread, crossFill: crossFill), children: children)
}

/// Creates a horizontal flex container arranging children left-to-right.
@MainActor public func Row(spacing: Double = 8, alignment: Alignment = .centerLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, @ChildrenBuilder content: () -> [any View]) -> Flex {
    Flex(FlexStyle(axis: .horizontal, spacing: spacing, alignment: alignment, spread: spread, crossFill: crossFill), content: content)
}

/// Creates a horizontal flex container arranging children left-to-right.
@MainActor public func Row(spacing: Double = 8, alignment: Alignment = .centerLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, children: [any View]) -> Flex {
    Flex(FlexStyle(axis: .horizontal, spacing: spacing, alignment: alignment, spread: spread, crossFill: crossFill), children: children)
}

/// Creates a horizontal flex container arranging children left-to-right.
@MainActor public func Wrap(axis: Axis = .horizontal, spacing: Double = 8, lineSpacing: Double = 8, alignment: Alignment = .centerLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, @ChildrenBuilder content: () -> [any View]) -> Flex {
    Flex(FlexStyle(axis: axis, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: true, crossFill: crossFill), content: content)
}

/// Creates a horizontal flex container arranging children left-to-right.
@MainActor public func Wrap(axis: Axis = .horizontal, spacing: Double = 8, lineSpacing: Double = 8, alignment: Alignment = .centerLeft, spread: Spread? = nil, crossFill: CrossFill = .sibling, children: [any View]) -> Flex {
    Flex(FlexStyle(axis: axis, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: true, crossFill: crossFill), children: children)
}

/// Flex child metadata. Tells a `Flex` container how to distribute
/// remaining space to this child. Has no effect outside flex layouts.
public struct FlexData: Sendable {
    public var flex: Double

    public init(flex: Double = 1) {
        self.flex = flex
    }
}

// MARK: - View Extension

public extension View {
    /// Mark this view as a flexible child within a `Flex` container.
    func flex(_ weight: Double = 1) -> ParentData<FlexData> {
        ParentData(FlexData(flex: weight)) { self }
    }
    
    func trailing(_ axis: Axis = .horizontal, spacing: Double = 8, alignment: Alignment = .center, content: any View) -> some View {
        if axis == .horizontal {
            Row(spacing: spacing, alignment: alignment) { self ; content }
        } else {
            Column(spacing: spacing, alignment: alignment) { self ; content }
        }
    }
    
    func leading(_ axis: Axis = .horizontal, spacing: Double = 8, alignment: Alignment = .center, content: any View) -> some View {
        if axis == .horizontal {
            Row(spacing: spacing, alignment: alignment) { content ; self }
        } else {
            Column(spacing: spacing, alignment: alignment) { content ; self }
        }
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class FlexRenderer: ContainerRenderer {
    private weak var flexView: FlexView?
    private var style: FlexStyle

    init(style: FlexStyle) {
        self.style = style
    }

    func update(from view: any View) {
        guard let flex = view as? Flex else { return }
        let newStyle = flex.style
        guard let flexView else { style = newStyle; return }

        let needsParentLayout = newStyle.axis != style.axis
        style = newStyle
        flexView.style = newStyle
        flexView.setNeedsLayout()
        if needsParentLayout { flexView.superview?.setNeedsLayout() }
    }

    func mount() -> PlatformView {
        let view = FlexView()
        self.flexView = view
        view.style = style
        return view
    }
}

// MARK: - FlexSlot

/// A measured child and its resolved position within a flex line.
struct FlexSlot {
    let index: Int
    let view: UIView
    var measured: Size = .zero
    var resolved: Size = .zero
    var origin: Point = .zero
    var main: Extent = .fit()
    var cross: Extent = .fit()
}

struct FlexLine {
    var slots: [FlexSlot] = []
    var bounds: Size = .zero
}

// MARK: - FlexView

final class FlexView: UIView {
    var style: FlexStyle = FlexStyle()
    
    var isPacked: Bool { style.spread == .packed || style.spread == nil }
    var spacing: Double { isPacked ? style.spacing : 0 }
    
    /// Key for caching the resolved size and flex slots
    var proposedSizeCache: Size?
    /// Result of the last measurement for the cached proposal
    var measuredSizeCache: Size?
    /// Resolved flex slots from the last proposal
    var lines: [FlexLine] = []
    
    var main: Axis { style.axis }
    var cross: Axis { style.axis.cross }
    
    override func setNeedsLayout() {
        super.setNeedsLayout()
        proposedSizeCache = nil
        measuredSizeCache = nil
    }
    
    // MARK: - Sizing
    
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let size = Size(size)
        /// if we already have a size computed for the given proposal, we just return that
        if let proposed = proposedSizeCache, proposed == size { return measuredSizeCache!.cgSize }
        /// if not, we measure all children - this is only expensive in the first run if children cache their sizes as well
        var slots = buildSlots()
        return measure(&slots, size: size).cgSize
    }
    
    func measure(_ slots: inout [FlexSlot], size: Size) -> Size {
        /// measure non-flex first to get input for measuring remaining space later
        measureNonFlex(&slots, size: size)
        /// once we have non-flex children measured, if there's wrapping, we split the list into lines first
        /// if we don't, we won't have any flexible space to distribute
        lines = buildLines(slots, size: size)
        /// now we need to distribute the flexible space - without that we can't know how large of a cross-axis each line wants to have
        measureFlexible(&lines, size: size)
        /// now we compute the bounding box of all children - positioning the children and lines can wait until layout
        measuredSizeCache = boundingBox(lines, size: size)
        proposedSizeCache = size
        return measuredSizeCache!
    }
    
    func buildSlots() -> [FlexSlot] {
        subviews.enumerated().map { index, view in
            var slot = FlexSlot(index: index, view: view)
            if let frame = childFrame(from: view) {
                slot.main = frame.on(main)
                slot.cross = frame.on(cross)
            }
            return slot
        }
    }
    
    func measureNonFlex(_ slots: inout [FlexSlot], size: Size) {
        for i in slots.indices where !slots[i].main.isFlex {
            let mainProposal = size.on(main)
            let crossProposal: Double
            switch slots[i].cross {
            case .fit, .fix:
                crossProposal = size.on(cross)
            case .fill, .flex:
                crossProposal = style.crossFill == .parent ? size.on(cross) : 0
            }
            let proposal = Size.on(main, main: mainProposal, cross: crossProposal)
            slots[i].measured = Size(slots[i].view.sizeThatFits(proposal.cgSize))
        }
    }
    
    func buildLines(_ slots: [FlexSlot], size: Size) -> [FlexLine] {
        /// flexes are non-wrapping by default, which is why this is the first case
        if !style.wrap {
            [FlexLine(
                slots: slots,
                bounds: lineBounds(slots, size: size),
            )]
        } else {
            splitLines(slots: slots, size: size)
        }
    }
    
    func measureFlexible(_ lines: inout [FlexLine], size: Size) {
        for i in lines.indices {
            /// get all the indices and flexes of flex slots
            let flexSlots = lines[i].slots.indices.compactMap { j in
                lines[i].slots[j].main.flex.map { (index: j, flex: $0) }
            }

            let totalFlex = flexSlots.reduce(0.0) { $0 + $1.flex }

            guard totalFlex > 0 else { continue }

            let flexibleSpace = size.on(main) - lines[i].bounds.on(main)

            for (j, flex) in flexSlots {
                let mainProposal = flexibleSpace * flex / totalFlex
                let crossProposal: Double

                switch lines[i].slots[j].cross {
                case .fit, .fix:
                    crossProposal = size.on(cross)
                case .fill, .flex:
                    crossProposal = style.crossFill == .parent ? size.on(cross) : 0
                }

                let proposal = Size.on(main, main: mainProposal, cross: crossProposal).cgSize
                let measured = lines[i].slots[j].view.sizeThatFits(proposal)
                lines[i].slots[j].measured = Size(measured)
            }

            lines[i].bounds = lineBounds(lines[i].slots, size: size)
        }
    }
    
    func splitLines(slots: [FlexSlot], size: Size) -> [FlexLine] {
        guard !slots.isEmpty else { return [] }
        var lines: [FlexLine] = []
        var current: FlexLine = FlexLine()
        slots.forEach { slot in
            /// finalize the current line only if its not empty and is would become larger than available space if appended a new slot
            if !current.slots.isEmpty && current.bounds.on(main) + spacing + slot.measured.on(main) > size.on(main) {
                current.bounds = lineBounds(current.slots, size: size)
                lines.append(current)
                current = FlexLine(slots: [slot], bounds: slot.measured)
            } else {
                current.slots.append(slot)
                current.bounds = lineBounds(current.slots, size: size)
            }
        }
        /// append the last line if its not empty, because we might hit the last slot on the first branch
        if !current.slots.isEmpty { lines.append(current) }
        return lines
    }

    /// Compute the intrinsic size of a list of slots (sum on main axis, max on cross axis).
    func lineBounds(_ slots: [FlexSlot], size: Size) -> Size {
        let mainSize = slots.reduce(0.0) { $0 + $1.measured.on(main) } + spacing * Double(max(0, slots.count - 1))
        let crossSize = slots.reduce(0.0) { max($0, $1.measured.on(cross)) }
        return Size.on(main, main: mainSize, cross: crossSize)
    }
    
    func boundingBox(_ lines: [FlexLine], size: Size) -> Size {
        let mainSize: Double
        if style.spread != nil {
            mainSize = size.on(main)
        } else {
            mainSize = lines.reduce(0.0) { max($0, $1.bounds.on(main)) }
        }
        let crossSize = lines.reduce(0.0) { $0 + $1.bounds.on(cross) }
        let spacing = style.lineSpacing * Double(max(0, lines.count - 1))
        let res = Size(mainSize, crossSize + spacing)
        return main.isHorizontal ? res : res.flipped
    }

    // MARK: - Layout
    
    /// Objective: determine the frame of every child
    /// 1) determine the intrinsic size of all children
    /// 2) stack the children sequentially along the main axis
    /// 3) if wrap is true, split the children into lines by taking only as many children as will fit into the main axis
    /// 4) distribute flexible space on the main axis
    /// 5) get the largest child on the cross-axis for each row - that's the cross-axis size
    /// 6) distribute the space on the cross-axis
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !subviews.isEmpty else { return }
        let s = Size(bounds.size)
        if proposedSizeCache != s {
            var slots = buildSlots()
            _ = measure(&slots, size: s)
        }
        arrangeSlots(&lines, size: s)
        applyFrames(&lines)
    }
    
    /// Here we need to position each slot in the whole container
    /// We split the approach into line-by-line
    /// We need to determine the main axis position and cross axis position
    /// The starting point is the currentCross pointer which determines row offset from the origin
    /// Next we know the intrinsic size of the line on main axis, we need to determine the spacing for each child based on spread and flexibility
    /// Two possible approaches - flexible children take all available space regardless of spread or each child takes as much spacing as alotted by the spread
    /// I think the first approach makes more sense.
    func arrangeSlots(_ lines: inout [FlexLine], size: Size) {
        guard let measured = measuredSizeCache else { return }
        let mainExtent = measured.on(main)
        let crossAlign = ((main.isHorizontal ? style.alignment.y : style.alignment.x) + 1) / 2
        var currentCross = 0.0

        for i in lines.indices {
            let lineCross = lines[i].bounds.on(cross)
            let hasFlex = lines[i].slots.contains { $0.main.isFlex }
            let intrinsic = lines[i].bounds.on(main)
            let remaining = max(0, mainExtent - intrinsic)
            let (start, gap) = resolveMainSpacing(remaining: remaining, count: lines[i].slots.count, hasFlex: hasFlex)

            var currentMain = start
            for j in lines[i].slots.indices {
                let slot = lines[i].slots[j]

                // Remeasure fill/flex cross children deferred from measurement
                if (slot.cross.isFill || slot.cross.isFlex) && style.crossFill == .sibling {
                    let proposal = Size.on(main, main: slot.measured.on(main), cross: lineCross)
                    lines[i].slots[j].measured = Size(slot.view.sizeThatFits(proposal.cgSize))
                }

                // Main: flex children use their measured size (already allocated by measureFlexible)
                let slotMain = slot.measured.on(main)

                // Cross: fill children scale to line cross, others align within it
                let slotCross: Double
                let crossOffset: Double
                if let fill = slot.cross.fill {
                    slotCross = lineCross * fill
                    crossOffset = currentCross
                } else {
                    slotCross = slot.measured.on(cross)
                    crossOffset = currentCross + (lineCross - slotCross) * crossAlign
                }

                let resolved = Size(slotMain, slotCross)
                let origin = Point(currentMain, crossOffset)
                lines[i].slots[j].resolved = main.isHorizontal ? resolved : resolved.flipped
                lines[i].slots[j].origin = main.isHorizontal ? origin : origin.flipped

                currentMain += slotMain + gap
            }

            currentCross += lineCross + style.lineSpacing
        }
    }
    
    /// Resolve the start offset and gap between slots on the main axis.
    func resolveMainSpacing(remaining: Double, count: Int, hasFlex: Bool) -> (start: Double, gap: Double) {
        if hasFlex { return (0, style.spacing) }
        return switch style.spread {
        case nil, .packed:
            (remaining * (style.alignment.on(main) + 1) / 2, style.spacing)
        case .between:
            (0, count > 1 ? remaining / Double(count - 1) : 0)
        case .around:
            (remaining / Double(count) / 2, remaining / Double(count))
        case .even:
            (remaining / Double(count + 1), remaining / Double(count + 1))
        }
    }

    /// Write resolved origins and sizes to each child's frame.
    func applyFrames(_ lines: inout [FlexLine]) {
        for line in lines {
            for slot in line.slots {
                slot.view.frame = CGRect(origin: slot.origin.cgPoint, size: slot.resolved.cgSize)
            }
        }
    }
}

#endif
