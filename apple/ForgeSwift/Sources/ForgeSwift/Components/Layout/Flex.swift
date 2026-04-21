// MARK: - Spread

/// Item distribution mode within a flex container.
public enum Spread: Sendable {
    case packed
    case between
    case around
    case even
}

// MARK: - Column & Row

/// Vertical flex container arranging children top-to-bottom.
public struct Column: ContainerView {
    public var spacing: Double
    public var lineSpacing: Double
    public var alignment: Alignment
    public var spread: Spread
    public var wrap: Bool
    public var children: [any View]

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, children: [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = children
    }

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        FlexRenderer(axis: .vertical, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap)
        #else
        fatalError("Column not yet implemented for this platform")
        #endif
    }
}

/// Horizontal flex container arranging children left-to-right.
public struct Row: ContainerView {
    public var spacing: Double
    public var lineSpacing: Double
    public var alignment: Alignment
    public var spread: Spread
    public var wrap: Bool
    public var children: [any View]

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, children: [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = children
    }

    public init(spacing: Double = 0, lineSpacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, wrap: Bool = false, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.lineSpacing = lineSpacing; self.alignment = alignment; self.spread = spread; self.wrap = wrap; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        FlexRenderer(axis: .horizontal, spacing: spacing, lineSpacing: lineSpacing, alignment: alignment, spread: spread, wrap: wrap)
        #else
        fatalError("Row not yet implemented for this platform")
        #endif
    }
}

// MARK: - UIKit Renderer

#if canImport(UIKit)
import UIKit

final class FlexRenderer: ContainerRenderer {
    private weak var flexView: FlexView?

    var axis: NSLayoutConstraint.Axis {
        didSet {
            guard axis != oldValue, let flexView else { return }
            flexView.flexAxis = axis
            flexView.setNeedsLayout()
            flexView.superview?.setNeedsLayout()
        }
    }

    var spacing: Double {
        didSet {
            guard spacing != oldValue, let flexView else { return }
            flexView.flexSpacing = spacing
            flexView.setNeedsLayout()
        }
    }

    var lineSpacing: Double {
        didSet {
            guard lineSpacing != oldValue, let flexView else { return }
            flexView.flexLineSpacing = lineSpacing
            flexView.setNeedsLayout()
        }
    }

    var alignment: Alignment {
        didSet {
            guard alignment != oldValue, let flexView else { return }
            flexView.flexAlignment = alignment
            flexView.setNeedsLayout()
        }
    }

    var spread: Spread {
        didSet {
            guard spread != oldValue, let flexView else { return }
            flexView.flexSpread = spread
            flexView.setNeedsLayout()
        }
    }

    var wrap: Bool {
        didSet {
            guard wrap != oldValue, let flexView else { return }
            flexView.flexWrap = wrap
            flexView.setNeedsLayout()
        }
    }

    init(axis: NSLayoutConstraint.Axis, spacing: Double, lineSpacing: Double, alignment: Alignment, spread: Spread, wrap: Bool) {
        self.axis = axis; self.spacing = spacing; self.lineSpacing = lineSpacing
        self.alignment = alignment; self.spread = spread; self.wrap = wrap
    }

    func update(from view: any View) {
        if let column = view as? Column {
            axis = .vertical
            spacing = column.spacing
            lineSpacing = column.lineSpacing
            alignment = column.alignment
            spread = column.spread
            wrap = column.wrap
        } else if let row = view as? Row {
            axis = .horizontal
            spacing = row.spacing
            lineSpacing = row.lineSpacing
            alignment = row.alignment
            spread = row.spread
            wrap = row.wrap
        }
    }

    func mount() -> PlatformView {
        let view = FlexView()
        self.flexView = view
        view.flexAxis = axis
        view.flexSpacing = spacing
        view.flexLineSpacing = lineSpacing
        view.flexAlignment = alignment
        view.flexSpread = spread
        view.flexWrap = wrap
        return view
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
    var flexAxis: NSLayoutConstraint.Axis = .vertical
    var flexSpacing: Double = 0
    var flexLineSpacing: Double = 0
    var flexAlignment: Alignment = .center
    var flexSpread: Spread = .packed
    var flexWrap: Bool = false

    private var isH: Bool { flexAxis == .horizontal }

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
        guard flexWrap else { return [FlexLine(slots: slots)] }

        var lines: [FlexLine] = []
        var currentSlots: [FlexSlot] = []
        var currentMain: CGFloat = 0

        for slot in slots {
            let childMain = main(of: slot.intrinsicSize)
            let spacingBefore = currentSlots.isEmpty ? 0 : flexSpacing

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

    private func fillExtent(of view: UIView) -> Extent? {
        let sizing: Frame?
        if let box = view as? BoxView { sizing = box.sizing }
        else if let proxy = view as? PassthroughView { sizing = proxy.innerSizing }
        else { return nil }
        guard let s = sizing else { return nil }
        let extent = isH ? s.width : s.height
        if case .fill = extent { return extent }
        return nil
    }

    private func resolveFills(_ line: inout FlexLine, mainExtent: CGFloat, crossExtent: CGFloat) {
        var totalFixed: CGFloat = 0
        var totalFlex: Double = 0
        for slot in line.slots {
            if let ext = fillExtent(of: slot.view), case .fill(let flex, _, _) = ext { totalFlex += flex }
            else { totalFixed += main(of: slot.intrinsicSize) }
        }

        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(line.slots.count - 1) : 0
        let freeSpace = max(0, mainExtent - totalFixed - spacingTotal)

        for i in 0..<line.slots.count {
            if let ext = fillExtent(of: line.slots[i].view), case .fill(let flex, let minVal, let maxVal) = ext {
                let normalizedFlex = max(1.0, totalFlex)
                var share = freeSpace * flex / normalizedFlex
                if let lo = minVal { share = max(share, lo) }
                if let hi = maxVal { share = min(share, hi) }
                let crossSize = isH
                    ? line.slots[i].view.sizeThatFits(CGSize(width: share, height: crossExtent)).height
                    : line.slots[i].view.sizeThatFits(CGSize(width: crossExtent, height: share)).width
                line.slots[i].resolvedSize = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
            }
        }

        line.crossSize = line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.resolvedSize)) }
    }

    // MARK: - Step 4: Position slots within a line

    private func positionLine(_ line: inout FlexLine, mainExtent: CGFloat) {
        let count = line.slots.count
        let totalChildrenMain = line.slots.reduce(CGFloat(0)) { $0 + main(of: $1.resolvedSize) }
        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(count - 1) : 0
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        let mainAlignFactor = isH ? (flexAlignment.x + 1) / 2 : (flexAlignment.y + 1) / 2
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2

        var mainOffset: CGFloat
        if flexSpread == .packed {
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
            lineCrossOffset += lines[lineIdx].crossSize + flexLineSpacing
        }
    }

    // MARK: - Size That Fits

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

    private func wrappedSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        let lines = splitIntoLines(slots: slots, mainExtent: proposedMain)
        let totalCross = lines.reduce(CGFloat(0)) { total, line in
            total + line.slots.reduce(CGFloat(0)) { max($0, cross(of: $1.intrinsicSize)) }
        } + flexLineSpacing * CGFloat(max(0, lines.count - 1))

        return isH
            ? CGSize(width: proposedMain, height: totalCross)
            : CGSize(width: totalCross, height: proposedMain)
    }

    private func linearSize(slots: [FlexSlot], proposedMain: CGFloat) -> CGSize {
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0
        var hasFillChild = false

        for slot in slots {
            if fillExtent(of: slot.view) != nil {
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

    private func main(of size: CGSize) -> CGFloat { isH ? size.width : size.height }
    private func cross(of size: CGSize) -> CGFloat { isH ? size.height : size.width }

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
