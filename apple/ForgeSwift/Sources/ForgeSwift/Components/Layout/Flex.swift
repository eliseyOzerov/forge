// MARK: - Spread

/// Item distribution mode within a flex container.
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
public struct FlexStyle: Sendable {
    public var axis: Axis
    public var spacing: Double
    public var lineSpacing: Double
    public var alignment: Alignment
    public var spread: Spread
    public var wrap: Bool

    public init(axis: Axis = .vertical, spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false) {
        self.axis = axis; self.spacing = spacing; self.lineSpacing = lineSpacing
        self.alignment = alignment; self.spread = spread; self.wrap = wrap
    }
}

// MARK: - Column & Row

/// Creates a vertical flex container arranging children top-to-bottom.
@MainActor public func Column(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) -> Flex {
    Flex(FlexStyle(axis: .vertical, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap), content: content)
}

/// Creates a horizontal flex container arranging children left-to-right.
@MainActor public func Row(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) -> Flex {
    Flex(FlexStyle(axis: .horizontal, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap), content: content)
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
    let view: UIView
    let intrinsicSize: CGSize
    var resolvedSize: CGSize
    var origin: CGPoint = .zero
}

// MARK: - FlexLine

/// A single row or column of slots produced by flex wrapping.
struct FlexLine {
    var slots: [FlexSlot]
    var crossSize: CGFloat = 0
}

// MARK: - FlexView

final class FlexView: UIView {
    var style = FlexStyle()

    private var isH: Bool { style.axis == .horizontal }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let children = subviews
        guard !children.isEmpty else { return }

        let mainExtent = main(of: bounds.size)
        let crossExtent = cross(of: bounds.size)

        let slots = measureChildren(children, proposing: bounds.size)
        var lines = splitIntoLines(slots: slots, mainExtent: mainExtent)

        for i in 0..<lines.count {
            resolveFills(&lines[i], mainExtent: mainExtent, crossExtent: crossExtent)
            // Single-line: cross size = container so within-line alignment
            // works against the full container. Multi-line: natural cross size.
            if lines.count == 1 { lines[i].crossSize = crossExtent }
            positionLine(&lines[i], mainExtent: mainExtent)
        }

        stackLines(&lines)

        for line in lines {
            for slot in line.slots {
                slot.view.frame = CGRect(origin: slot.origin, size: slot.resolvedSize)
            }
        }
    }

    // MARK: - Step 1: Measure

    private func measureChildren(_ children: [UIView], proposing: CGSize) -> [FlexSlot] {
        let count = CGFloat(children.count)
        let perChildMain = count > 0 ? main(of: proposing) / count : main(of: proposing)
        let perChildProposal = isH
            ? CGSize(width: perChildMain, height: proposing.height)
            : CGSize(width: proposing.width, height: perChildMain)

        return children.map { child in
            let size = child.sizeThatFits(perChildProposal)
            return FlexSlot(view: child, intrinsicSize: size, resolvedSize: size)
        }
    }

    // MARK: - Step 2: Split into lines

    private func splitIntoLines(slots: [FlexSlot], mainExtent: CGFloat) -> [FlexLine] {
        guard style.wrap else { return [FlexLine(slots: slots)] }

        var lines: [FlexLine] = []
        var currentSlots: [FlexSlot] = []
        var currentMain: CGFloat = 0

        for slot in slots {
            let childMain = main(of: slot.intrinsicSize)
            let spacingBefore = currentSlots.isEmpty ? 0 : style.spacing

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

    /// Describes how a child participates in flex distribution.
    private enum FlexChildKind {
        case fixed
        case fill(fraction: Double, min: Double?, max: Double?)
        case flexible(weight: Int, min: Double?, max: Double?)
    }

    private func childKind(of view: UIView) -> FlexChildKind {
        // Check for Flexible wrapper first
        if let host = view as? FlexibleHostView {
            return .flexible(weight: host.weight, min: host.flexMin, max: host.flexMax)
        }
        // Unwrap PassthroughView to find FlexibleHostView
        if let proxy = view as? PassthroughView,
           let host = proxy.subviews.first as? FlexibleHostView {
            return .flexible(weight: host.weight, min: host.flexMin, max: host.flexMax)
        }
        // Check for fill extent on BoxView
        let sizing: Frame?
        if let box = view as? BoxView { sizing = box.sizing }
        else if let proxy = view as? PassthroughView { sizing = proxy.innerSizing }
        else { return .fixed }
        guard let s = sizing else { return .fixed }
        let extent = isH ? s.width : s.height
        if case .fill(let f, let min, let max) = extent {
            return .fill(fraction: f, min: min, max: max)
        }
        return .fixed
    }

    private func resolveFills(_ line: inout FlexLine, mainExtent: CGFloat, crossExtent: CGFloat) {
        var totalFixed: CGFloat = 0
        var totalFlexWeight: Double = 0
        var totalFillFraction: Double = 0
        for slot in line.slots {
            switch childKind(of: slot.view) {
            case .fixed: totalFixed += main(of: slot.intrinsicSize)
            case .flexible(let weight, _, _): totalFlexWeight += Double(weight)
            case .fill(let fraction, _, _): totalFillFraction += fraction
            }
        }

        let spacingTotal = style.spread == .packed ? style.spacing * Double(line.slots.count - 1) : 0

        // Fill children take their fraction of the full main extent first.
        let fillConsumed = mainExtent * min(1.0, totalFillFraction)
        // Flex children split the remaining space by weight.
        let freeSpace = max(0, mainExtent - totalFixed - fillConsumed - spacingTotal)

        for i in 0..<line.slots.count {
            let share: CGFloat
            switch childKind(of: line.slots[i].view) {
            case .fixed: continue
            case .fill(let fraction, let minVal, let maxVal):
                share = (mainExtent * fraction).clamped(min: minVal, max: maxVal)
            case .flexible(let weight, let minVal, let maxVal):
                let normalizedFlex = max(1.0, totalFlexWeight)
                share = (freeSpace * Double(weight) / normalizedFlex).clamped(min: minVal, max: maxVal)
            }
            let crossSize = isH
                ? line.slots[i].view.sizeThatFits(CGSize(width: share, height: crossExtent)).height
                : line.slots[i].view.sizeThatFits(CGSize(width: crossExtent, height: share)).width
            line.slots[i].resolvedSize = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
        }

        line.crossSize = line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.resolvedSize)) }
    }

    // MARK: - Step 4: Position slots within a line

    private func positionLine(_ line: inout FlexLine, mainExtent: CGFloat) {
        let count = line.slots.count
        let totalChildrenMain = line.slots.reduce(CGFloat(0)) { $0 + main(of: $1.resolvedSize) }
        let spacingTotal = style.spread == .packed ? style.spacing * Double(count - 1) : 0
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        let mainAlignFactor = isH ? (style.alignment.x + 1) / 2 : (style.alignment.y + 1) / 2
        let crossAlignFactor = isH ? (style.alignment.y + 1) / 2 : (style.alignment.x + 1) / 2

        var mainOffset: CGFloat
        if style.spread == .packed {
            let groupSize = totalChildrenMain + spacingTotal
            mainOffset = (mainExtent - groupSize) * mainAlignFactor
        } else {
            mainOffset = spaceBefore
        }

        for i in 0..<line.slots.count {
            let childCross = cross(of: line.slots[i].resolvedSize)
            let crossOffset = (line.crossSize - childCross) * crossAlignFactor

            line.slots[i].origin = isH
                ? CGPoint(x: mainOffset, y: crossOffset)
                : CGPoint(x: crossOffset, y: mainOffset)

            mainOffset += main(of: line.slots[i].resolvedSize) + spaceBetween
        }
    }

    // MARK: - Step 5: Stack lines along cross axis

    private func stackLines(_ lines: inout [FlexLine]) {
        var lineCrossOffset: CGFloat = 0
        for lineIdx in 0..<lines.count {
            for i in 0..<lines[lineIdx].slots.count {
                if isH {
                    lines[lineIdx].slots[i].origin.y += lineCrossOffset
                } else {
                    lines[lineIdx].slots[i].origin.x += lineCrossOffset
                }
            }
            lineCrossOffset += lines[lineIdx].crossSize + style.lineSpacing
        }
    }

    // MARK: - Size That Fits

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard !children.isEmpty else { return .zero }

        let slots = measureChildren(children, proposing: size)
        let proposedMain = main(of: size)

        if style.wrap {
            return wrappedSize(slots: slots, proposedMain: proposedMain)
        }
        return linearSize(slots: slots, proposedMain: proposedMain)
    }

    private func wrappedSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        let lines = splitIntoLines(slots: slots, mainExtent: proposedMain)
        let totalCross = lines.reduce(CGFloat(0)) { total, line in
            total + line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.intrinsicSize)) }
        } + style.lineSpacing * CGFloat(max(0, lines.count - 1))

        return isH
            ? CGSize(width: proposedMain, height: totalCross)
            : CGSize(width: totalCross, height: proposedMain)
    }

    private func linearSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0
        var hasFillChild = false

        for slot in slots {
            switch childKind(of: slot.view) {
            case .fixed:
                mainTotal += main(of: slot.intrinsicSize)
            case .fill, .flexible:
                hasFillChild = true
            }
            crossMax = max(crossMax, cross(of: slot.intrinsicSize))
        }

        mainTotal += style.spacing * CGFloat(slots.count - 1)
        let mainResult = (style.spread != .packed || hasFillChild) ? proposedMain : mainTotal

        return isH ? CGSize(width: mainResult, height: crossMax) : CGSize(width: crossMax, height: mainResult)
    }

    // MARK: - Helpers

    private func main(of size: CGSize) -> CGFloat { isH ? size.width : size.height }
    private func cross(of size: CGSize) -> CGFloat { isH ? size.height : size.width }

    private func resolveSpacing(freeSpace: CGFloat, count: Int) -> (before: CGFloat, between: CGFloat) {
        switch style.spread {
        case .packed: return (0, style.spacing)
        case .between: return count <= 1 ? (0, 0) : (0, freeSpace / CGFloat(count - 1))
        case .around: let s = freeSpace / CGFloat(count); return (s / 2, s)
        case .even: let s = freeSpace / CGFloat(count + 1); return (s, s)
        }
    }
}

#endif
