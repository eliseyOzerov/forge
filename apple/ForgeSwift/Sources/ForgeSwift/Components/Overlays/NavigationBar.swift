import Foundation

// MARK: - NavigationItem

/// Per-screen navigation-bar configuration, declared by the hosted
/// view via `.navigation(_:)` and applied by the Router's
/// NavigationBar on every rebuild.
public struct NavigationItem {
    public var title: String?
    public var main: (any View)?
    public var leading: (any View)?
    public var trailing: (any View)?
    public var bottom: (any View)?
    public var background: StateProperty<Surface>?
    public var hidden: Bool
    public var hideImplicitBackButton: Bool
    public var onBack: (@MainActor () -> Void)?
    public var alignment: Alignment
    public var padding: Padding?

    public init(
        title: String? = nil,
        main: (any View)? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        background: StateProperty<Surface>? = nil,
        hidden: Bool = false,
        hideImplicitBackButton: Bool = false,
        onBack: (@MainActor () -> Void)? = nil,
        alignment: Alignment = .center,
        padding: Padding? = nil
    ) {
        self.title = title
        self.main = main
        self.leading = leading
        self.trailing = trailing
        self.bottom = bottom
        self.background = background
        self.hidden = hidden
        self.hideImplicitBackButton = hideImplicitBackButton
        self.onBack = onBack
        self.alignment = alignment
        self.padding = padding
    }
}

// MARK: - Navigation (BuiltView)

/// Declarative navigation-bar configuration. Wrap a screen's content
/// in `Navigation(title:, trailing:, …) { content }` and the enclosing
/// Router applies the declared fields to its NavigationBar on every rebuild.
public struct Navigation: BuiltView {
    public let item: NavigationItem
    public let child: any View

    public init(
        title: String? = nil,
        main: (any View)? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        background: StateProperty<Surface>? = nil,
        hidden: Bool = false,
        hideImplicitBackButton: Bool = false,
        onBack: (@MainActor () -> Void)? = nil,
        alignment: Alignment = .center,
        padding: Padding? = nil,
        @ChildBuilder content: () -> any View
    ) {
        self.item = NavigationItem(
            title: title, main: main, leading: leading,
            trailing: trailing, bottom: bottom, background: background,
            hidden: hidden, hideImplicitBackButton: hideImplicitBackButton,
            onBack: onBack, alignment: alignment, padding: padding
        )
        self.child = content()
    }

    public init(item: NavigationItem, @ChildBuilder content: () -> any View) {
        self.item = item
        self.child = content()
    }

    public func build(context: ViewContext) -> any View {
        if let channel = context.tryRead(Observable<NavigationItem>.self) {
            channel.value = item
        }
        return child
    }
}

// MARK: - .navigation(...) modifier

public extension View {
    func navigation(
        title: String? = nil,
        main: (any View)? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        background: StateProperty<Surface>? = nil,
        hidden: Bool = false,
        hideImplicitBackButton: Bool = false,
        onBack: (@MainActor () -> Void)? = nil,
        alignment: Alignment = .center,
        padding: Padding? = nil
    ) -> Navigation {
        Navigation(
            title: title, main: main, leading: leading,
            trailing: trailing, bottom: bottom, background: background,
            hidden: hidden, hideImplicitBackButton: hideImplicitBackButton,
            onBack: onBack, alignment: alignment, padding: padding
        ) { self }
    }

    func navigation(_ item: NavigationItem) -> Navigation {
        Navigation(item: item) { self }
    }
}

// MARK: - NavBarContentRow

/// Three-slot horizontal layout: leading, main, trailing.
/// Main is sized to the remaining space after leading/trailing are
/// measured. Horizontal positioning of main depends on `centerMode`:
///
/// - `.absolute`: center main in the bar's full width. If that would
///   overlap leading or trailing, fall back to centering in the
///   remaining space between them.
/// - `.between`: always center main in the remaining space between
///   leading and trailing.
///
/// `alignment` controls where main sits when not centering:
/// `.leading` pushes it flush after leading, `.trailing` flush before
/// trailing. Default `.center` uses the `centerMode` logic.
public struct NavBarContentRow: ContainerView {
    public let leading: (any View)?
    public let main: (any View)?
    public let trailing: (any View)?
    public let alignment: Alignment
    public let centerMode: NavBarCenterMode
    public let children: [any View]

    public init(
        leading: (any View)? = nil,
        main: (any View)? = nil,
        trailing: (any View)? = nil,
        alignment: Alignment = .center,
        centerMode: NavBarCenterMode = .absolute
    ) {
        self.leading = leading
        self.main = main
        self.trailing = trailing
        self.alignment = alignment
        self.centerMode = centerMode
        self.children = [
            leading ?? EmptyView(),
            main ?? EmptyView(),
            trailing ?? EmptyView(),
        ]
    }

    public func makeRenderer() -> ContainerRenderer {
        #if canImport(UIKit)
        NavBarContentRowRenderer(view: self)
        #else
        fatalError("NavBarContentRow not yet implemented for this platform")
        #endif
    }
}

public enum NavBarCenterMode: Equatable, Sendable {
    /// Center main in the bar's full width. Falls back to `.between`
    /// if main would overlap leading or trailing.
    case absolute
    /// Center main in the space between leading and trailing.
    case between
}

// MARK: - NavBarContentRowRenderer

#if canImport(UIKit)

final class NavBarContentRowRenderer: ContainerRenderer {
    private weak var rowView: NavBarContentRowView?
    private var view: NavBarContentRow

    init(view: NavBarContentRow) {
        self.view = view
    }

    func mount() -> PlatformView {
        let rv = NavBarContentRowView()
        self.rowView = rv
        rv.mainAlignment = view.alignment
        rv.centerMode = view.centerMode
        return rv
    }

    func update(from newView: any View) {
        guard let row = newView as? NavBarContentRow, let rv = rowView else { return }
        let old = view
        view = row

        var needsLayout = false

        if old.alignment != row.alignment {
            rv.mainAlignment = row.alignment
            needsLayout = true
        }
        if old.centerMode != row.centerMode {
            rv.centerMode = row.centerMode
            needsLayout = true
        }

        if needsLayout { rv.setNeedsLayout() }
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

import UIKit

// MARK: - NavBarContentRowView

final class NavBarContentRowView: UIView {
    var mainAlignment: Alignment = .center
    var centerMode: NavBarCenterMode = .absolute

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let children = subviews
        guard children.count == 3 else { return .zero }
        let h = children.map({ $0.sizeThatFits(size).height }).max() ?? 0
        return CGSize(width: size.width, height: h)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let children = subviews
        guard children.count == 3 else { return }

        let leadingView = children[0]
        let mainView = children[1]
        let trailingView = children[2]

        let w = bounds.width
        let h = bounds.height

        // 1. Measure leading and trailing with loose constraints.
        let leadingSize = leadingView.sizeThatFits(bounds.size)
        let trailingSize = trailingView.sizeThatFits(bounds.size)

        // 2. Measure main within remaining space.
        let remainingW = max(0, w - leadingSize.width - trailingSize.width)
        let mainSize = mainView.sizeThatFits(CGSize(width: remainingW, height: h))

        // 3. Position leading flush left, trailing flush right.
        leadingView.frame = CGRect(
            x: 0,
            y: (h - leadingSize.height) / 2,
            width: leadingSize.width,
            height: leadingSize.height
        )
        trailingView.frame = CGRect(
            x: w - trailingSize.width,
            y: (h - trailingSize.height) / 2,
            width: trailingSize.width,
            height: trailingSize.height
        )

        // 4. Position main.
        let mainX: CGFloat
        let ax = mainAlignment.x

        if ax < -0.5 {
            mainX = leadingSize.width
        } else if ax > 0.5 {
            mainX = w - trailingSize.width - mainSize.width
        } else {
            switch centerMode {
            case .absolute:
                let centered = (w - mainSize.width) / 2
                let overlapsLeading = centered < leadingSize.width
                let overlapsTrailing = centered + mainSize.width > w - trailingSize.width
                if overlapsLeading || overlapsTrailing {
                    mainX = leadingSize.width + (remainingW - mainSize.width) / 2
                } else {
                    mainX = centered
                }
            case .between:
                mainX = leadingSize.width + (remainingW - mainSize.width) / 2
            }
        }

        mainView.frame = CGRect(
            x: mainX,
            y: (h - mainSize.height) / 2,
            width: mainSize.width,
            height: mainSize.height
        )
    }
}
#endif

// MARK: - NavigationBar

/// Full navigation bar component. Composes NavBarContentRow inside a
/// styled Box with optional bottom accessory. The bar handles its own
/// height, surface, padding, and safe area insets.
///
///     NavigationBar(
///         main: Text("Home"),
///         trailing: Button(onTap: { ... }) { Icon("plus") },
///         surface: .color(.systemBackground)
///     )
///
/// The `bottom` slot sits below the main content row (search bars,
/// segmented controls, etc.). The surface can cover just the content
/// row or extend to include the bottom via `includeBottomInSurface`.
public struct NavigationBar: BuiltView {
    public let leading: (any View)?
    public let main: (any View)?
    public let trailing: (any View)?
    public let bottom: (any View)?
    public let alignment: Alignment
    public let centerMode: NavBarCenterMode
    public let height: Double
    public let padding: Padding
    public let surface: Surface?
    public let hidden: Bool
    public let includeBottomInSurface: Bool

    public init(
        leading: (any View)? = nil,
        main: (any View)? = nil,
        trailing: (any View)? = nil,
        bottom: (any View)? = nil,
        alignment: Alignment = .center,
        centerMode: NavBarCenterMode = .absolute,
        height: Double = 44,
        padding: Padding = .zero,
        surface: Surface? = nil,
        hidden: Bool = false,
        includeBottomInSurface: Bool = false
    ) {
        self.leading = leading
        self.main = main
        self.trailing = trailing
        self.bottom = bottom
        self.alignment = alignment
        self.centerMode = centerMode
        self.height = height
        self.padding = padding
        self.surface = surface
        self.hidden = hidden
        self.includeBottomInSurface = includeBottomInSurface
    }

    public func build(context: ViewContext) -> any View {
        if hidden { return EmptyView() }

        let row = NavBarContentRow(
            leading: leading,
            main: main,
            trailing: trailing,
            alignment: alignment,
            centerMode: centerMode
        )

        let contentRow = Box(
            BoxStyle(frame: .height(.fix(height)), padding: padding)
        ) { row }

        #if canImport(UIKit)
        // SafeArea top inset pushes content below the status bar.
        // The surface extends edge-to-edge behind the status bar.
        var body: any View = SafeArea(edges: .top) { contentRow }
        #else
        var body: any View = contentRow
        #endif

        if !includeBottomInSurface, let surface {
            body = Box(surface: surface) { body }
        }

        #if canImport(UIKit)
        if let bottom {
            body = Column {
                body
                bottom
            }
        }
        #endif

        if includeBottomInSurface, let surface {
            return Box(surface: surface) { body }
        }

        return body
    }
}
