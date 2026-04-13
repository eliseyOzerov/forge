#if canImport(UIKit)
import UIKit

// MARK: - Spread

public enum Spread: Sendable {
    case packed
    case between
    case around
    case even
}

// MARK: - Column & Row

public struct Column: ContainerView {
    public let spacing: Double
    public let lineSpacing: Double
    public let alignment: Alignment
    public let spread: Spread
    public let wrap: Bool
    public let children: [any View]

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, children: [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = children
    }

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        FlexRenderer(axis: .vertical, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap)
    }
}

public struct Row: ContainerView {
    public let spacing: Double
    public let lineSpacing: Double
    public let alignment: Alignment
    public let spread: Spread
    public let wrap: Bool
    public let children: [any View]

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, children: [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = children
    }

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        FlexRenderer(axis: .horizontal, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap)
    }
}

// MARK: - Renderer

final class FlexRenderer: ContainerRenderer {
    let axis: NSLayoutConstraint.Axis
    let spacing: Double
    let lineSpacing: Double
    let alignment: Alignment
    let spread: Spread
    let wrap: Bool

    init(axis: NSLayoutConstraint.Axis, spacing: Double, lineSpacing: Double, alignment: Alignment, spread: Spread, wrap: Bool) {
        self.axis = axis; self.spacing = spacing; self.lineSpacing = lineSpacing
        self.alignment = alignment; self.spread = spread; self.wrap = wrap
    }

    func mount() -> PlatformView {
        let view = FlexView()
        apply(to: view)
        return view
    }

    func update(_ platformView: PlatformView) {
        guard let view = platformView as? FlexView else { return }
        apply(to: view)
    }

    private func apply(to view: FlexView) {
        view.flexAxis = axis
        view.flexSpacing = spacing
        view.flexLineSpacing = lineSpacing
        view.flexAlignment = alignment
        view.flexSpread = spread
        view.flexWrap = wrap
        view.setNeedsLayout()
    }

    func insert(_ platformView: PlatformView, at index: Int, into container: PlatformView) {
        container.insertSubview(platformView, at: index)
    }

    func remove(_ platformView: PlatformView, from container: PlatformView) {
        platformView.removeFromSuperview()
    }

    func move(_ platformView: PlatformView, to index: Int, in container: PlatformView) {
        platformView.removeFromSuperview()
        container.insertSubview(platformView, at: index)
    }

    func index(of platformView: PlatformView, in container: PlatformView) -> Int? {
        container.subviews.firstIndex(of: platformView)
    }
}

// MARK: - FlexSlot

/// Per-child data computed during layout. Holds the child's intrinsic
/// measurement and its resolved position/size after flex distribution.
struct FlexSlot {
    let view: UIView
    /// Natural size of the child, ignoring fill extents.
    let intrinsicSize: CGSize
    /// The child's extent on the main axis (fill/fix/hug), read from BoxView.
    let mainExtent: Extent?
    /// Final size after fill distribution. Starts as intrinsicSize.
    var resolvedSize: CGSize
    /// Final position within the FlexView's coordinate space.
    var origin: CGPoint = .zero

    /// Returns the flex weight if this child has a fill extent, nil otherwise.
    var mainFlex: Double? {
        if case .fill(let flex, _, _) = mainExtent { return flex }
        return nil
    }
}

// MARK: - FlexLine

/// A single row (or column) of slots in a wrapped flex layout.
struct FlexLine {
    var slots: [FlexSlot]
    /// Height of this line on the cross axis (tallest child).
    var crossSize: CGFloat = 0
}

// MARK: - FlexView

/// Custom layout view for Column/Row. Distributes children along a
/// main axis with spacing, spread modes, flex fill, alignment, and
/// optional wrapping.
///
/// Layout pipeline:
///   1. measureChildren  — get intrinsic size of each child
///   2. splitIntoLines   — break into lines if wrapping
///   3. resolveFills     — distribute remaining space to fill children per line
///   4. positionLine     — position each child on main + cross axis within its line
///   5. stackLines       — offset lines along the cross axis
final class FlexView: UIView {
    var flexAxis: NSLayoutConstraint.Axis = .vertical
    var flexSpacing: Double = 0
    var flexLineSpacing: Double = 0
    var flexAlignment: Alignment = .center
    var flexSpread: Spread = .packed
    var flexWrap: Bool = false

    /// True when main axis is horizontal (Row), false when vertical (Column).
    private var isH: Bool { flexAxis == .horizontal }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let children = subviews
        guard !children.isEmpty else { return }

        let mainExtent = main(of: bounds.size)
        let crossExtent = cross(of: bounds.size)

        // 1. Measure all children given available space.
        let slots = measureChildren(children, proposing: bounds.size)

        // 2. Group into lines. Without wrap, everything is one line.
        var lines = splitIntoLines(slots: slots, mainExtent: mainExtent)

        // 3+4. Per line: give fill children their share, then position everyone.
        for i in 0..<lines.count {
            resolveFills(&lines[i], mainExtent: mainExtent, crossExtent: crossExtent)
            positionLine(&lines[i], mainExtent: mainExtent)
        }

        // 5. Stack lines along the cross axis (only matters when wrapped).
        stackLines(&lines, crossExtent: crossExtent)

        // Apply computed frames to actual views.
        for line in lines {
            for slot in line.slots {
                slot.view.frame = CGRect(origin: slot.origin, size: slot.resolvedSize)
            }
        }
    }

    // MARK: - Step 1: Measure

    /// Ask each child for its intrinsic size given the available space.
    /// Fill children report their content size (not the full proposed
    /// size) so line splitting works correctly — fill expansion happens
    /// later in resolveFills.
    private func measureChildren(_ children: [UIView], proposing: CGSize) -> [FlexSlot] {
        children.map { child in
            let childFrame = (child as? BoxView)?.sizing
            let extent = isH ? childFrame?.width : childFrame?.height
            let size = child.sizeThatFits(proposing)
            return FlexSlot(view: child, intrinsicSize: size, mainExtent: extent, resolvedSize: size)
        }
    }

    // MARK: - Step 2: Split into lines

    /// Group slots into lines based on intrinsic sizes. When a child
    /// would overflow the main axis, start a new line. Without wrap,
    /// returns a single line containing all slots.
    private func splitIntoLines(slots: [FlexSlot], mainExtent: CGFloat) -> [FlexLine] {
        guard flexWrap else { return [FlexLine(slots: slots)] }

        var lines: [FlexLine] = []
        var currentSlots: [FlexSlot] = []
        var currentMain: CGFloat = 0

        for slot in slots {
            let childMain = main(of: slot.intrinsicSize)
            let spacingBefore = currentSlots.isEmpty ? 0 : flexSpacing

            // Would this child overflow? If so, flush the current line.
            if !currentSlots.isEmpty && currentMain + spacingBefore + childMain > mainExtent {
                lines.append(FlexLine(slots: currentSlots))
                currentSlots = [slot]
                currentMain = childMain
            } else {
                currentMain += spacingBefore + childMain
                currentSlots.append(slot)
            }
        }
        if !currentSlots.isEmpty { lines.append(FlexLine(slots: currentSlots)) }
        return lines
    }

    // MARK: - Step 3: Resolve fill sizes

    /// Distribute remaining main-axis space among fill children in this
    /// line. Each fill child gets a share proportional to its flex weight.
    /// Flex is normalized against max(1, totalFlex) so flex=0.5 means
    /// "half the space" even when it's the only fill child.
    /// Also computes the line's cross size (tallest child).
    private func resolveFills(_ line: inout FlexLine, mainExtent: CGFloat, crossExtent: CGFloat) {
        // Sum up fixed children's main size and total flex weight.
        var totalFixed: CGFloat = 0
        var totalFlex: Double = 0
        for slot in line.slots {
            if let flex = slot.mainFlex { totalFlex += flex }
            else { totalFixed += main(of: slot.intrinsicSize) }
        }

        // Remaining space after fixed children and spacing.
        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(line.slots.count - 1) : 0
        let freeSpace = max(0, mainExtent - totalFixed - spacingTotal)

        // Assign each fill child its proportional share.
        for i in 0..<line.slots.count {
            if let flex = line.slots[i].mainFlex {
                let normalizedFlex = max(1.0, totalFlex)
                let share = freeSpace * flex / normalizedFlex
                // Re-measure cross size now that we know the main size.
                let crossSize = isH
                    ? line.slots[i].view.sizeThatFits(CGSize(width: share, height: crossExtent)).height
                    : line.slots[i].view.sizeThatFits(CGSize(width: crossExtent, height: share)).width
                line.slots[i].resolvedSize = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
            }
        }

        // Line cross size = tallest child in this line.
        line.crossSize = line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.resolvedSize)) }
    }

    // MARK: - Step 4: Position slots within a line

    /// Position children sequentially along the main axis with spacing
    /// determined by the spread mode, and align on the cross axis within
    /// the line's cross size.
    private func positionLine(_ line: inout FlexLine, mainExtent: CGFloat) {
        let count = line.slots.count
        let totalChildrenMain = line.slots.reduce(CGFloat(0)) { $0 + main(of: $1.resolvedSize) }
        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(count - 1) : 0
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        // Alignment factors: 0 = start, 0.5 = center, 1 = end.
        let mainAlignFactor = isH ? (flexAlignment.x + 1) / 2 : (flexAlignment.y + 1) / 2
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2

        // Starting offset on main axis — packed uses alignment, spread uses spaceBefore.
        var mainOffset: CGFloat
        if flexSpread == .packed {
            let groupSize = totalChildrenMain + spacingTotal
            mainOffset = (mainExtent - groupSize) * mainAlignFactor
        } else {
            mainOffset = spaceBefore
        }

        for i in 0..<line.slots.count {
            // Align this child within the line's cross extent.
            let childCross = cross(of: line.slots[i].resolvedSize)
            let crossOffset = (line.crossSize - childCross) * crossAlignFactor

            line.slots[i].origin = isH
                ? CGPoint(x: mainOffset, y: crossOffset)
                : CGPoint(x: crossOffset, y: mainOffset)

            mainOffset += main(of: line.slots[i].resolvedSize) + spaceBetween
        }
    }

    // MARK: - Step 5: Stack lines along cross axis

    /// Shift each line's children along the cross axis so lines are
    /// stacked sequentially with line spacing. Uses cross alignment
    /// to position the group of lines within the available cross extent.
    private func stackLines(_ lines: inout [FlexLine], crossExtent: CGFloat) {
        guard lines.count > 1 else { return }

        let totalLineCross = lines.reduce(CGFloat(0)) { $0 + $1.crossSize }
        let totalLineSpacing = flexLineSpacing * CGFloat(lines.count - 1)
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2
        let freeLineCross = crossExtent - totalLineCross - totalLineSpacing
        var lineCrossOffset = freeLineCross * crossAlignFactor

        for lineIdx in 0..<lines.count {
            for i in 0..<lines[lineIdx].slots.count {
                if isH {
                    lines[lineIdx].slots[i].origin.y += lineCrossOffset
                } else {
                    lines[lineIdx].slots[i].origin.x += lineCrossOffset
                }
            }
            lineCrossOffset += lines[lineIdx].crossSize + flexLineSpacing
        }
    }

    // MARK: - Size That Fits

    /// Report preferred size. Delegates to wrappedSize or linearSize
    /// depending on wrap mode.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard !children.isEmpty else { return .zero }

        let slots = measureChildren(children, proposing: size)
        let proposedMain = main(of: size)

        if flexWrap {
            return wrappedSize(slots: slots, proposedMain: proposedMain)
        }
        return linearSize(slots: slots, proposedMain: proposedMain)
    }

    /// Wrapped: split into lines, sum cross sizes + line spacing.
    /// Main axis takes the proposed size (wrapping fills the width).
    private func wrappedSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        let lines = splitIntoLines(slots: slots, mainExtent: proposedMain)
        let totalCross = lines.reduce(CGFloat(0)) { total, line in
            total + line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.intrinsicSize)) }
        } + flexLineSpacing * CGFloat(max(0, lines.count - 1))

        return isH
            ? CGSize(width: proposedMain, height: totalCross)
            : CGSize(width: totalCross, height: proposedMain)
    }

    /// Linear (no wrap): sum all children on main axis.
    /// If any child has fill or spread != packed, take full proposed main.
    /// Otherwise hug content.
    private func linearSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0
        var hasFillChild = false

        for slot in slots {
            if slot.mainFlex != nil {
                hasFillChild = true
            } else {
                mainTotal += main(of: slot.intrinsicSize)
            }
            crossMax = max(crossMax, cross(of: slot.intrinsicSize))
        }

        mainTotal += flexSpacing * CGFloat(slots.count - 1)
        let mainResult = (flexSpread != .packed || hasFillChild) ? proposedMain : mainTotal

        return isH ? CGSize(width: mainResult, height: crossMax) : CGSize(width: crossMax, height: mainResult)
    }

    // MARK: - Helpers

    /// Extract main-axis dimension from a CGSize.
    private func main(of size: CGSize) -> CGFloat { isH ? size.width : size.height }
    /// Extract cross-axis dimension from a CGSize.
    private func cross(of size: CGSize) -> CGFloat { isH ? size.height : size.width }

    /// Compute spacing before first child and between children based on spread mode.
    private func resolveSpacing(freeSpace: CGFloat, count: Int) -> (before: CGFloat, between: CGFloat) {
        switch flexSpread {
        case .packed: return (0, flexSpacing)
        case .between: return count <= 1 ? (0, 0) : (0, freeSpace / CGFloat(count - 1))
        case .around: let s = freeSpace / CGFloat(count); return (s / 2, s)
        case .even: let s = freeSpace / CGFloat(count + 1); return (s, s)
        }
    }
}

#endif
