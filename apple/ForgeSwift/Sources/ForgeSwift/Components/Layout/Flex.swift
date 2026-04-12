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
    public let alignment: Alignment
    public let spread: Spread
    public let children: [any View]

    public init(spacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, children: [any View]) {
        self.spacing = spacing; self.alignment = alignment; self.spread = spread; self.children = children
    }

    public init(spacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.alignment = alignment; self.spread = spread; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        FlexRenderer(axis: .vertical, spacing: spacing, alignment: alignment, spread: spread)
    }
}

public struct Row: ContainerView {
    public let spacing: Double
    public let alignment: Alignment
    public let spread: Spread
    public let children: [any View]

    public init(spacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, children: [any View]) {
        self.spacing = spacing; self.alignment = alignment; self.spread = spread; self.children = children
    }

    public init(spacing: Double = 0, alignment: Alignment = .center, spread: Spread = .packed, @ChildrenBuilder content: () -> [any View]) {
        self.spacing = spacing; self.alignment = alignment; self.spread = spread; self.children = content()
    }

    public func makeRenderer() -> ContainerRenderer {
        FlexRenderer(axis: .horizontal, spacing: spacing, alignment: alignment, spread: spread)
    }
}

// MARK: - Renderer

final class FlexRenderer: ContainerRenderer {
    let axis: NSLayoutConstraint.Axis
    let spacing: Double
    let alignment: Alignment
    let spread: Spread

    init(axis: NSLayoutConstraint.Axis, spacing: Double, alignment: Alignment, spread: Spread) {
        self.axis = axis; self.spacing = spacing; self.alignment = alignment; self.spread = spread
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
        view.flexAlignment = alignment
        view.flexSpread = spread
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
    var flexAlignment: Alignment = .center
    var flexSpread: Spread = .packed

    override func layoutSubviews() {
        super.layoutSubviews()
        let children = subviews
        guard !children.isEmpty else { return }

        let isH = flexAxis == .horizontal
        let mainExtent = isH ? bounds.width : bounds.height
        let crossExtent = isH ? bounds.height : bounds.width

        // Phase 1: measure children, identify flex vs non-flex
        var sizes: [CGSize] = []
        var totalFixed: CGFloat = 0
        var totalFlex: CGFloat = 0

        for child in children {
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            if case .fill(let flex, _, _) = mainExtentType {
                sizes.append(.zero) // placeholder
                totalFlex += flex
            } else {
                let size = child.sizeThatFits(bounds.size)
                sizes.append(size)
                totalFixed += isH ? size.width : size.height
            }
        }

        // Phase 2: distribute remaining space
        let count = children.count
        let spacingTotal = flexSpread == .packed ? flexSpacing * Double(count - 1) : 0
        let freeSpace = max(0, mainExtent - totalFixed - spacingTotal)

        for (i, child) in children.enumerated() {
            let childFrame = (child as? BoxView)?.boxFrame
            let mainExtentType = isH ? childFrame?.width : childFrame?.height

            if case .fill(let flex, _, _) = mainExtentType {
                let share = totalFlex > 0 ? freeSpace * flex / totalFlex : 0
                let crossSize = isH ? child.sizeThatFits(CGSize(width: share, height: crossExtent)).height : child.sizeThatFits(CGSize(width: crossExtent, height: share)).width
                sizes[i] = isH ? CGSize(width: share, height: crossSize) : CGSize(width: crossSize, height: share)
            }
        }

        // Phase 3: compute spacing for spread modes
        let totalChildrenMain = sizes.reduce(CGFloat(0)) { $0 + (isH ? $1.width : $1.height) }
        let remainingSpace = mainExtent - totalChildrenMain
        let (spaceBefore, spaceBetween) = resolveSpacing(freeSpace: remainingSpace, count: count)

        // Phase 4: position children
        let mainAlignFactor = isH ? (flexAlignment.x + 1) / 2 : (flexAlignment.y + 1) / 2
        let crossAlignFactor = isH ? (flexAlignment.y + 1) / 2 : (flexAlignment.x + 1) / 2

        var mainOffset: CGFloat
        if flexSpread == .packed {
            let groupSize = totalChildrenMain + spacingTotal
            mainOffset = (mainExtent - groupSize) * mainAlignFactor
        } else {
            mainOffset = spaceBefore
        }

        for (i, child) in children.enumerated() {
            let childMain = isH ? sizes[i].width : sizes[i].height
            let childCross = isH ? sizes[i].height : sizes[i].width
            let crossOffset = (crossExtent - childCross) * crossAlignFactor

            if isH {
                child.frame = CGRect(x: mainOffset, y: crossOffset, width: sizes[i].width, height: sizes[i].height)
            } else {
                child.frame = CGRect(x: crossOffset, y: mainOffset, width: sizes[i].width, height: sizes[i].height)
            }

            mainOffset += childMain + spaceBetween
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard !children.isEmpty else { return .zero }

        let isH = flexAxis == .horizontal
        var mainTotal: CGFloat = 0
        var crossMax: CGFloat = 0

        for child in children {
            let s = child.sizeThatFits(size)
            if isH {
                mainTotal += s.width
                crossMax = max(crossMax, s.height)
            } else {
                mainTotal += s.height
                crossMax = max(crossMax, s.width)
            }
        }

        let spacingTotal = flexSpacing * CGFloat(children.count - 1)
        mainTotal += spacingTotal

        // Non-packed spread fills the available main axis
        let mainSize: CGFloat
        if flexSpread != .packed {
            mainSize = isH ? size.width : size.height
        } else {
            mainSize = mainTotal
        }

        return isH ? CGSize(width: mainSize, height: crossMax) : CGSize(width: crossMax, height: mainSize)
    }

    private func resolveSpacing(freeSpace: CGFloat, count: Int) -> (before: CGFloat, between: CGFloat) {
        switch flexSpread {
        case .packed:
            return (0, flexSpacing)
        case .between:
            return count <= 1 ? (0, 0) : (0, freeSpace / CGFloat(count - 1))
        case .around:
            let s = freeSpace / CGFloat(count)
            return (s / 2, s)
        case .even:
            let s = freeSpace / CGFloat(count + 1)
            return (s, s)
        }
    }
}

#endif
