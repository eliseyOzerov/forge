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

struct FlexSlot {
    let view: UIView
    let intrinsicSize: CGSize
    let mainExtent: Extent?
    var resolvedSize: CGSize
    var origin: CGPoint = .zero

    var mainFlex: Double? {
        if case .fill(let flex, _, _) = mainExtent { return flex }
        return nil
    }
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

        // Step 1: measure all children at intrinsic size
        var slots = measureChildren(children)

        // Step 2: split into lines
        let lines = splitIntoLines(slots: slots, mainExtent: mainExtent)

        // Step 3+4: layout each line
        var layoutLines: [(slots: [Int], crossSize: CGFloat)] = []
        for line in lines {
            let lineCross = resolveAndPositionLine(line: line, slots: &slots, mainExtent: mainExtent, crossExtent: crossExtent)
            layoutLines.append((slots: line, crossSize: lineCross))
        }

        // Step 5: stack lines along cross axis
        stackLines(layoutLines, slots: &slots, crossExtent: crossExtent)

        // Apply frames
        for slot in slots {
            slot.view.frame = CGRect(origin: slot.origin, size: slot.resolvedSize)
        }
    }

    // MARK: - Step 1: Measure

    private func measureChildren(_ children: [UIView]) -> [FlexSlot] {
        children.map { child in
            let childFrame = (child as? BoxView)?.boxFrame
            let extent = isH ? childFrame?.width : childFrame?.height
            let size = child.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            return FlexSlot(view: child, intrinsicSize: size, mainExtent: extent, resolvedSize: size)
        }
    }

    // MARK: - Step 2: Split into lines

    private func splitIntoLines(slots: [FlexSlot], mainExtent: CGFloat) -> [[Int]] {
        guard flexWrap else { return [Array(0..<slots.count)] }

        var lines: [[Int]] = []
        var currentLine: [Int] = []
        var currentMain: CGFloat = 0

        for i in 0..<slots.count {
            let childMain = main(of: slots[i].intrinsicSize)
            let spacingBefore = currentLine.isEmpty ? 0 : flexSpacing

            if !currentLine.isEmpty && currentMain + spacingBefore + childMain > mainExtent {
                lines.append(currentLine)
                currentLine = [i]
                currentMain = childMain
            } else {
                currentMain += spacingBefore + childMain
                currentLine.append(i)
            }
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines
    }

    // MARK: - Step 3+4: Resolve fills and position within a line

    private func resolveAndPositionLine(line: [Int], slots: inout [FlexSlot], mainExtent: CGFloat, crossExtent: CGFloat) -> CGFloat {
        let count = line.count

        // Sum fixed children on main axis
        var totalFixed: CGFloat = 0
        var totalFlex: Double = 0
        for idx in line {
            if let flex = slots[idx].mainFlex {
                totalFlex += flex
            } else {
                totalFixed += main(of: slots[idx].intrinsicSize)
            }
        }

        // Distribute remaining space to fill children
        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(count - 1) : 0
        let freeSpace = max(0, mainExtent - totalFixed - spacingTotal)

        for idx in line {
            if let flex = slots[idx].mainFlex {
                let normalizedFlex = max(1.0, totalFlex)
                let share = freeSpace * flex / normalizedFlex
                let crossSize = isH
                    ? slots[idx].view.sizeThatFits(CGSize(width: share, height: crossExtent)).height
                    : slots[idx].view.sizeThatFits(CGSize(width: crossExtent, height: share)).width
                slots[idx].resolvedSize = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
            }
        }

        // Line cross size
        let lineCross = line.reduce(CGFloat(0)) { max($0, cross(of: slots[$1].resolvedSize)) }

        // Spread spacing
        let totalChildrenMain = line.reduce(CGFloat(0)) { $0 + main(of: slots[$1].resolvedSize) }
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        // Position along main axis
        let mainAlignFactor = isH ? (flexAlignment.x + 1) / 2 : (flexAlignment.y + 1) / 2
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2

        var mainOffset: CGFloat
        if flexSpread == .packed {
            let groupSize = totalChildrenMain + spacingTotal
            mainOffset = (mainExtent - groupSize) * mainAlignFactor
        } else {
            mainOffset = spaceBefore
        }

        for idx in line {
            let childMain = main(of: slots[idx].resolvedSize)
            let childCross = cross(of: slots[idx].resolvedSize)
            let crossOffset = (lineCross - childCross) * crossAlignFactor

            if isH {
                slots[idx].origin = CGPoint(x: mainOffset, y: crossOffset)
            } else {
                slots[idx].origin = CGPoint(x: crossOffset, y: mainOffset)
            }
            mainOffset += childMain + spaceBetween
        }

        return lineCross
    }

    // MARK: - Step 5: Stack lines along cross axis

    private func stackLines(_ lines: [(slots: [Int], crossSize: CGFloat)], slots: inout [FlexSlot], crossExtent: CGFloat) {
        guard lines.count > 1 else { return }

        let totalLineCross = lines.reduce(CGFloat(0)) { $0 + $1.crossSize }
        let totalLineSpacing = flexLineSpacing * CGFloat(lines.count - 1)
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2
        let freeLineCross = crossExtent - totalLineCross - totalLineSpacing
        var lineCrossOffset = freeLineCross * crossAlignFactor

        for line in lines {
            for idx in line.slots {
                if isH {
                    slots[idx].origin.y += lineCrossOffset
                } else {
                    slots[idx].origin.x += lineCrossOffset
                }
            }
            lineCrossOffset += line.crossSize + flexLineSpacing
        }
    }

    // MARK: - Size That Fits

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard !children.isEmpty else { return .zero }

        let slots = measureChildren(children)
        let proposedMain = main(of: size)

        if flexWrap {
            let lines = splitIntoLines(slots: slots, mainExtent: proposedMain)
            var totalCross: CGFloat = 0
            var maxMain: CGFloat = 0

            for line in lines {
                var lineMain: CGFloat = 0
                var lineCross: CGFloat = 0
                for idx in line {
                    lineMain += main(of: slots[idx].intrinsicSize)
                    lineCross = max(lineCross, cross(of: slots[idx].intrinsicSize))
                }
                lineMain += flexSpacing * CGFloat(max(0, line.count - 1))
                maxMain = max(maxMain, lineMain)
                totalCross += lineCross
            }
            totalCross += flexLineSpacing * CGFloat(max(0, lines.count - 1))

            return isH
                ? CGSize(width: proposedMain, height: totalCross)
                : CGSize(width: totalCross, height: proposedMain)
        }

        // Non-wrap
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0
        var hasFillChild = false

        for slot in slots {
            if slot.mainFlex != nil {
                hasFillChild = true
                crossMax = max(crossMax, cross(of: slot.intrinsicSize))
            } else {
                mainTotal += main(of: slot.intrinsicSize)
                crossMax = max(crossMax, cross(of: slot.intrinsicSize))
            }
        }

        mainTotal += flexSpacing * CGFloat(children.count - 1)

        let mainResult: CGFloat
        if flexSpread != .packed || hasFillChild {
            mainResult = main(of: size)
        } else {
            mainResult = mainTotal
        }

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
