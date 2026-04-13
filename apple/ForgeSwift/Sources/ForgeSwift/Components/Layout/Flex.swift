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

        let mainExtent = mainSize(of: bounds.size)
        let crossExtent = crossSize(of: bounds.size)

        // Step 1: measure all children at intrinsic size
        let intrinsicSizes = measureChildren(children, proposing: bounds.size)

        // Step 2: split into lines
        let lines = splitIntoLines(children: children, sizes: intrinsicSizes, mainExtent: mainExtent)

        // Step 3+4: layout each line (resolve fills, apply spread, align)
        var lineRects: [(crossOffset: CGFloat, crossSize: CGFloat)] = []
        var resolvedFrames: [(index: Int, frame: CGRect)] = []

        for line in lines {
            let result = layoutLine(line: line, children: children, intrinsicSizes: intrinsicSizes,
                                     mainExtent: mainExtent, crossExtent: crossExtent)
            lineRects.append((crossOffset: 0, crossSize: result.lineCrossSize))
            resolvedFrames.append(contentsOf: result.frames)
        }

        // Step 5: stack lines along cross axis
        let totalLineCross = lineRects.reduce(0) { $0 + $1.crossSize }
        let totalLineSpacing = flexLineSpacing * CGFloat(max(0, lines.count - 1))
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2
        let freeLineCross = crossExtent - totalLineCross - totalLineSpacing
        var lineCrossOffset = freeLineCross * crossAlignFactor

        for (lineIdx, line) in lines.enumerated() {
            let lineCross = lineRects[lineIdx].crossSize

            for idx in line {
                guard let entry = resolvedFrames.first(where: { $0.index == idx }) else { continue }
                var frame = entry.frame

                // Shift by line's cross offset
                if isH {
                    frame.origin.y += lineCrossOffset
                } else {
                    frame.origin.x += lineCrossOffset
                }
                children[idx].frame = frame
            }

            lineCrossOffset += lineCross + flexLineSpacing
        }
    }

    // MARK: - Step 1: Measure

    private func measureChildren(_ children: [UIView], proposing size: CGSize) -> [CGSize] {
        children.map { child in
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            // Fill children measured at zero on main axis for intrinsic sizing
            if case .fill = mainExtentType {
                return isH
                    ? CGSize(width: 0, height: child.sizeThatFits(size).height)
                    : CGSize(width: child.sizeThatFits(size).width, height: 0)
            }
            return child.sizeThatFits(size)
        }
    }

    // MARK: - Step 2: Split into lines

    private func splitIntoLines(children: [UIView], sizes: [CGSize], mainExtent: CGFloat) -> [[Int]] {
        guard flexWrap else { return [Array(0..<children.count)] }

        var lines: [[Int]] = []
        var currentLine: [Int] = []
        var currentMainUsed: CGFloat = 0

        for i in 0..<children.count {
            let childMain = mainSize(of: sizes[i])
            let spacingBefore = currentLine.isEmpty ? 0 : flexSpacing

            if !currentLine.isEmpty && currentMainUsed + spacingBefore + childMain > mainExtent {
                lines.append(currentLine)
                currentLine = [i]
                currentMainUsed = childMain
            } else {
                currentMainUsed += spacingBefore + childMain
                currentLine.append(i)
            }
        }
        if !currentLine.isEmpty { lines.append(currentLine) }
        return lines
    }

    // MARK: - Step 3+4: Layout a single line

    private struct LineResult {
        let frames: [(index: Int, frame: CGRect)]
        let lineCrossSize: CGFloat
    }

    private func layoutLine(line: [Int], children: [UIView], intrinsicSizes: [CGSize],
                             mainExtent: CGFloat, crossExtent: CGFloat) -> LineResult {
        let count = line.count

        // Measure fixed + detect fill
        var sizes: [CGSize] = []
        var totalFixed: CGFloat = 0
        var totalFlex: CGFloat = 0

        for idx in line {
            let child = children[idx]
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            if case .fill(let flex, _, _) = mainExtentType {
                sizes.append(intrinsicSizes[idx])
                totalFlex += flex
            } else {
                let size = intrinsicSizes[idx]
                sizes.append(size)
                totalFixed += mainSize(of: size)
            }
        }

        // Distribute fill space
        let spacingTotal = flexSpread == .packed ? flexSpacing * CGFloat(count - 1) : 0
        let freeSpace = max(0, mainExtent - totalFixed - spacingTotal)

        for (i, idx) in line.enumerated() {
            let child = children[idx]
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            if case .fill(let flex, _, _) = mainExtentType {
                let normalizedFlex = max(1.0, totalFlex)
                let share = normalizedFlex > 0 ? freeSpace * flex / normalizedFlex : 0
                let crossSize = isH
                    ? child.sizeThatFits(CGSize(width: share, height: crossExtent)).height
                    : child.sizeThatFits(CGSize(width: crossExtent, height: share)).width
                sizes[i] = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
            }
        }

        // Line cross size
        let lineCrossSize = sizes.reduce(CGFloat(0)) { max($0, crossSize(of: $1)) }

        // Spread spacing
        let totalChildrenMain = sizes.reduce(CGFloat(0)) { $0 + mainSize(of: $1) }
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        // Position
        let mainAlignFactor = isH ? (flexAlignment.x + 1) / 2 : (flexAlignment.y + 1) / 2
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2

        var mainOffset: CGFloat
        if flexSpread == .packed {
            let groupSize = totalChildrenMain + spacingTotal
            mainOffset = (mainExtent - groupSize) * mainAlignFactor
        } else {
            mainOffset = spaceBefore
        }

        var frames: [(index: Int, frame: CGRect)] = []

        for (i, idx) in line.enumerated() {
            let childMain = mainSize(of: sizes[i])
            let childCross = crossSize(of: sizes[i])
            let crossOffset = (lineCrossSize - childCross) * crossAlignFactor

            let frame: CGRect
            if isH {
                frame = CGRect(x: mainOffset, y: crossOffset, width: sizes[i].width, height: sizes[i].height)
            } else {
                frame = CGRect(x: crossOffset, y: mainOffset, width: sizes[i].width, height: sizes[i].height)
            }
            frames.append((index: idx, frame: frame))
            mainOffset += childMain + spaceBetween
        }

        return LineResult(frames: frames, lineCrossSize: lineCrossSize)
    }

    // MARK: - Size That Fits

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard !children.isEmpty else { return .zero }

        let intrinsicSizes = measureChildren(children, proposing: size)
        let proposedMain = mainSize(of: size)

        if flexWrap {
            let lines = splitIntoLines(children: children, sizes: intrinsicSizes, mainExtent: proposedMain)
            var totalCross: CGFloat = 0
            var maxMain: CGFloat = 0

            for line in lines {
                var lineMain: CGFloat = 0
                var lineCross: CGFloat = 0
                for idx in line {
                    lineMain += mainSize(of: intrinsicSizes[idx])
                    lineCross = max(lineCross, crossSize(of: intrinsicSizes[idx]))
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

        // Non-wrap: original logic
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0
        var hasFillChild = false

        for (i, child) in children.enumerated() {
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            if case .fill = mainExtentType {
                hasFillChild = true
                crossMax = max(crossMax, crossSize(of: intrinsicSizes[i]))
            } else {
                mainTotal += mainSize(of: intrinsicSizes[i])
                crossMax = max(crossMax, crossSize(of: intrinsicSizes[i]))
            }
        }

        let spacingTotal = flexSpacing * CGFloat(children.count - 1)
        mainTotal += spacingTotal

        let mainResult: CGFloat
        if flexSpread != .packed || hasFillChild {
            mainResult = mainSize(of: size)
        } else {
            mainResult = mainTotal
        }

        return isH ? CGSize(width: mainResult, height: crossMax) : CGSize(width: crossMax, height: mainResult)
    }

    // MARK: - Helpers

    private func mainSize(of size: CGSize) -> CGFloat { isH ? size.width : size.height }
    private func crossSize(of size: CGSize) -> CGFloat { isH ? size.height : size.width }

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
