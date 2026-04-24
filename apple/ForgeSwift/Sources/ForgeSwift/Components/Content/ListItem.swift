// MARK: - ListItem

/// Horizontal content row with leading, trailing, and a vertical stack
/// of primary/secondary/tertiary text slots. The primary row also
/// supports an inline tag view.
///
/// ListItem handles content layout only — wrap it in a `Box` for
/// surface, shape, or min-height constraints.
///
///     ListItem(title: "Notifications", subtitle: "3 unread")
///
///     ListItem(
///         leading: Icon("bell"),
///         primary: Text("Notifications"),
///         tag: Badge("3"),
///         trailing: Text("›")
///     )
@Copy
public struct ListItem: BuiltView {
    public var leading: (any View)?
    public var primary: (any View)?
    public var secondary: (any View)?
    public var tertiary: (any View)?
    public var tag: (any View)?
    public var trailing: (any View)?
    public var style: ListItemStyle = ListItemStyle()

    public init(
        leading: (any View)? = nil,
        primary: (any View)? = nil,
        secondary: (any View)? = nil,
        tertiary: (any View)? = nil,
        tag: (any View)? = nil,
        trailing: (any View)? = nil,
        style: ListItemStyle = ListItemStyle()
    ) {
        self.leading = leading
        self.primary = primary
        self.secondary = secondary
        self.tertiary = tertiary
        self.tag = tag
        self.trailing = trailing
        self.style = style
    }

    public init(
        title: String,
        subtitle: String? = nil,
        leading: (any View)? = nil,
        trailing: (any View)? = nil,
        tag: (any View)? = nil,
        style: ListItemStyle = ListItemStyle()
    ) {
        self.leading = leading
        self.primary = Text(title)
        self.secondary = subtitle.map { Text($0) }
        self.tertiary = nil
        self.tag = tag
        self.trailing = trailing
        self.style = style
    }

    public func build(context: ViewContext) -> any View {
        let s = style

        // Primary row: primary + tag
        var primaryRow: (any View)? = primary
        if let primary, let tag {
            primaryRow = Row(spacing: s.spacingTag, alignment: .centerLeft) {
                primary
                tag
            }
        }

        // Content column: primary row, secondary, tertiary
        let contentChildren: [any View] = [primaryRow, secondary, tertiary].compactMap { $0 }
        let content: any View
        if contentChildren.isEmpty {
            content = EmptyView()
        } else {
            content = Provided(s.primary) {
                Column(spacing: s.spacingContent, alignment: .topLeft) {
                    contentChildren[0]
                    if contentChildren.count > 1 {
                        Provided(s.secondary) { contentChildren[1] }
                    }
                    if contentChildren.count > 2 {
                        Provided(s.tertiary) { contentChildren[2] }
                    }
                }
            }
        }

        // Outer row: leading, content, trailing
        return Box(frame: .fillWidth, padding: s.padding) {
            Row(spacing: s.spacingHorizontal, alignment: .centerLeft) {
                if let leading {
                    Box(alignment: Alignment(0, s.alignmentLeading.y)) { leading }
                }
                Box(frame: .fillWidth, alignment: .centerLeft) { content }
                if let trailing {
                    Box(alignment: Alignment(0, s.alignmentTrailing.y)) { trailing }
                }
            }
        }
    }
}

extension ListItem {
    /// Configure style. The callback receives the current style for modification.
    public func style(_ build: (ListItemStyle) -> ListItemStyle) -> Self {
        self.style(build(self.style))
    }
}

// MARK: - ListItemStyle

/// Visual configuration for a ListItem.
@Style
public struct ListItemStyle: Equatable, Sendable {
    public var primary: TextStyle = TextStyle(font: Font(size: 17, weight: 500))
    public var secondary: TextStyle = TextStyle(font: Font(size: 14, weight: 400), color: Color(0.5, 0.5, 0.55))
    public var tertiary: TextStyle = TextStyle(font: Font(size: 13, weight: 400), color: Color(0.6, 0.6, 0.65))
    public var spacingHorizontal: Double = 12
    public var spacingContent: Double = 4
    public var spacingTag: Double = 6
    public var padding: Padding = Padding(top: 12, bottom: 12, leading: 16, trailing: 16)
    public var alignmentLeading: Alignment = .center
    public var alignmentTrailing: Alignment = .center
}
