# Forge Type Lexicon

One-sentence description of every Forge type. Paths are relative to `apple/ForgeSwift/Sources/ForgeSwift/`.

---

## App

| Type | Description | File |
|------|-------------|------|
| `App` | Application entry point and lifecycle delegate (UIKit/AppKit). | `App.swift` |

## Core / Data

| Type | Description | File |
|------|-------------|------|
| `Binding<Value>` | Two-way data binding with getter/setter closures and onChange hooks. | `Core/Data/Binding.swift` |
| `RefBox<T>` | Private reference box backing Binding's mutable storage. | `Core/Data/Binding.swift` |
| `MemoryCache` | In-memory cache backed by NSCache, evicted under memory pressure. | `Core/Data/Cache.swift` |
| `DiskCache` | Disk-based cache in the Caches directory, cleared by the OS under storage pressure. | `Core/Data/Cache.swift` |
| `CacheBox` | Private NSObject wrapper enabling NSCache storage of arbitrary types. | `Core/Data/Cache.swift` |
| `Copyable` | Protocol for value types needing a closure-based copy-and-mutate pattern. | `Core/Data/Copyable.swift` |
| `Observable<T>` | Property wrapper holding a value that notifies observers on change via Binding projection. | `Core/Data/Observable.swift` |
| `Notifier` | Concrete notification engine storing listeners and firing them on `notify()`. | `Core/Data/Observable.swift` |
| `Listenable` | Protocol for anything subscribable for change notifications. | `Core/Data/Observable.swift` |
| `Subscription` | Cancellable subscription handle returned by `Listenable.listen()`. | `Core/Data/Observable.swift` |
| `Similarity` | Enum namespace for vector distance and similarity metrics (cosine, euclidean, etc.). | `Core/Data/Similarity.swift` |
| `SourceState<T>` | Async source state machine with idle, loading, loaded, and error cases. | `Core/Data/Source.swift` |
| `Source<T>` | Protocol for async data sources that produce values with state tracking and caching. | `Core/Data/Source.swift` |
| `AssetSource<T>` | Loads parsed data from the app bundle with memory caching. | `Core/Data/Source.swift` |
| `FileSource<T>` | Loads parsed data from a file URL with memory caching. | `Core/Data/Source.swift` |
| `URLSource<T>` | Remote data loader that checks disk cache before downloading. | `Core/Data/Source.swift` |
| `SourceError` | Loading error cases for Source (e.g. notFound). | `Core/Data/Source.swift` |
| `Statistics` | Enum namespace for statistical operations on numeric sequences (mean, median, stddev, etc.). | `Core/Data/Statistics.swift` |

## Core / Geometry

| Type | Description | File |
|------|-------------|------|
| `Alignment` | Alignment within a container backed by Vec2 with values -1 (start) to 1 (end). | `Core/Geometry/Alignment.swift` |
| `Axis` | Enum for horizontal or vertical direction. | `Core/Geometry/Axis.swift` |
| `Edge` | Enum for rectangle edges (top, bottom, leading, trailing). | `Core/Geometry/Edge.swift` |
| `Edge.Set` | OptionSet-based bitfield of edges with composition operators. | `Core/Geometry/Edge.swift` |
| `Frame` | Sizing constraints for views with width/height Extents. | `Core/Geometry/Frame.swift` |
| `Extent` | Dimension sizing mode (hug content, fill parent, or fixed value). | `Core/Geometry/Frame.swift` |
| `Overflow` | Container overflow behavior (clip, visible, scroll). | `Core/Geometry/Overflow.swift` |
| `ScrollConfig` | Configuration for scroll overflow with axis, indicators, and bounce settings. | `Core/Geometry/Overflow.swift` |
| `ScrollState` | Observable scroll state for programmatic control (offset, content size, viewport). | `Core/Geometry/Overflow.swift` |
| `Padding` | Edge insets (top, bottom, leading, trailing) for spacing around content. | `Core/Geometry/Padding.swift` |
| `Path` | Platform-agnostic 2D path with building, querying, boolean ops, and metrics. | `Core/Geometry/Path.swift` |
| `PathTangent` | Point and angle sampled from a Path at a given distance. | `Core/Geometry/Path.swift` |
| `PathSegment` | Private segment representation for path length and sampling calculations. | `Core/Geometry/Path.swift` |
| `Rect` | Axis-aligned rectangle with factory methods, boundary ops, and coordinate mapping. | `Core/Geometry/Rect.swift` |
| `Shape` | Protocol for closed-path constructors given a bounding rect (type-erasable via AnyShape). | `Core/Geometry/Shape.swift` |
| `RectShape` | Rectangle shape. | `Core/Geometry/Shape.swift` |
| `EllipseShape` | Ellipse shape. | `Core/Geometry/Shape.swift` |
| `CircleShape` | Circle shape. | `Core/Geometry/Shape.swift` |
| `CapsuleShape` | Capsule (stadium) shape — rectangle with fully rounded ends. | `Core/Geometry/Shape.swift` |
| `RegularPolygon` | Regular polygon with configurable side count and rotation. | `Core/Geometry/Shape.swift` |
| `StarShape` | Star shape with configurable point count and inner radius ratio. | `Core/Geometry/Shape.swift` |
| `PolygonShape` | Arbitrary polygon constructed from a list of points. | `Core/Geometry/Shape.swift` |
| `ScaledShape` | Shape decorator that scales by x/y factors. | `Core/Geometry/Shape.swift` |
| `RotatedShape` | Shape decorator that rotates by radians. | `Core/Geometry/Shape.swift` |
| `TranslatedShape` | Shape decorator that translates by an offset. | `Core/Geometry/Shape.swift` |
| `InsetShape` | Shape decorator that insets (or outsets) by a given amount. | `Core/Geometry/Shape.swift` |
| `RoundedModifiedShape` | Shape decorator that applies rounded corners. | `Core/Geometry/Shape.swift` |
| `ChamferedShape` | Shape decorator that applies chamfered (beveled) corners. | `Core/Geometry/Shape.swift` |
| `UnionShape` | Boolean union of two shapes (iOS 16+). | `Core/Geometry/Shape.swift` |
| `IntersectionShape` | Boolean intersection of two shapes (iOS 16+). | `Core/Geometry/Shape.swift` |
| `SubtractionShape` | Boolean subtraction of two shapes (iOS 16+). | `Core/Geometry/Shape.swift` |
| `SymmetricDifferenceShape` | Boolean XOR of two shapes (iOS 16+). | `Core/Geometry/Shape.swift` |
| `CustomShape` | Closure-based shape with an optional vertex factory. | `Core/Geometry/Shape.swift` |
| `ShapeUtils` | Internal enum namespace for shape geometry helpers (rounding, chamfering, etc.). | `Core/Geometry/Shape.swift` |
| `Size` | 2D extent (width x height) with area, aspect ratio, and isEmpty queries. | `Core/Geometry/Size.swift` |
| `Vector` | Protocol for fixed-dimension numeric vectors with linear algebra ops. | `Core/Geometry/Vector.swift` |
| `Vec2` | 2D vector with cross product, perpendicular, angle, and rotation ops. | `Core/Geometry/Vector.swift` |
| `Point` | Typealias for Vec2 used semantically as a position. | `Core/Geometry/Vector.swift` |
| `Vec3` | 3D vector with cross product and xy projection. | `Core/Geometry/Vector.swift` |
| `Vec4` | 4D vector with xyz/xy projections. | `Core/Geometry/Vector.swift` |

## Core / Time

| Type | Description | File |
|------|-------------|------|
| `TimeConstants` | Enum namespace for time unit conversion constants (seconds per minute, etc.). | `Core/Time/Time.swift` |
| `Duration` | Span of time stored as seconds with component constructors and formatting. | `Core/Time/Time.swift` |
| `PartOfDay` | Time-of-day category (morning, noon, afternoon, evening, night). | `Core/Time/Time.swift` |
| `Time` | Time of day (hours, minutes, seconds) without date or timezone, wraps on overflow. | `Core/Time/Time.swift` |
| `TimeComponent` | Calendar component enum (millisecond through year) with Foundation.Calendar conversion. | `Core/Time/Time.swift` |
| `Date` | Calendar date (year, month, day) without time or timezone. | `Core/Time/Time.swift` |
| `Timestamp` | Point in time as Unix seconds since epoch with component access and boundary queries. | `Core/Time/Time.swift` |
| `FoundationDate` | Typealias for Foundation.Date to avoid naming conflicts. | `Core/Time/Time.swift` |

## Core / View

| Type | Description | File |
|------|-------------|------|
| `View` | Fundamental protocol — every Forge view returns a Node. | `Core/View/View.swift` |
| `LeafView` | Protocol for views that render a platform view via a Renderer. | `Core/View/View.swift` |
| `BuiltView` | Protocol for stateless composites with a `build(context:)` method. | `Core/View/View.swift` |
| `ModelView` | Protocol for stateful composites backed by a persistent Model and per-render Builder. | `Core/View/View.swift` |
| `ViewLifecycle` | Protocol defining the lifecycle contract for a ModelView's persistent state. | `Core/View/View.swift` |
| `ViewModel<View>` | Open base class implementing ViewLifecycle for ModelView state containers. | `Core/View/View.swift` |
| `ViewBuilding` | Protocol defining the builder contract for a ModelView's per-render logic. | `Core/View/View.swift` |
| `ViewBuilder<Model>` | Open base class implementing ViewBuilding for ModelView render builders. | `Core/View/View.swift` |
| `ViewContext` | Protocol providing read-only access to theme, observables, and provided values during build. | `Core/View/View.swift` |
| `Renderer` | Protocol for leaf-view platform renderers. | `Core/View/View.swift` |
| `ProxyView` | Protocol for views that wrap a single child view. | `Core/View/View.swift` |
| `ProxyRenderer` | Protocol for renderers of proxy views. | `Core/View/View.swift` |
| `ContainerView` | Protocol for views that contain multiple child views. | `Core/View/View.swift` |
| `ContainerRenderer` | Protocol for renderers of container views. | `Core/View/View.swift` |
| `Identified` | Protocol for views with a stable identity for reconciliation. | `Core/View/View.swift` |
| `Buildable` | Struct wrapper that implements BuiltView from a build closure. | `Core/View/View.swift` |
| `Observing<T>` | BuiltView that rebuilds when a Listenable changes. | `Core/View/View.swift` |
| `Offstage` | View that mounts but remains invisible (preserves state while hidden). | `Core/View/View.swift` |
| `ListBuilder<T>` | Builder struct for constructing lists of views. | `Core/View/View.swift` |
| `ChildrenBuilder` | Typealias for `ListBuilder<any View>`. | `Core/View/View.swift` |
| `ChildBuilder` | Typealias for `ValueBuilder`. | `Core/View/View.swift` |
| `ValueBuilder` | Builder struct for constructing a single view. | `Core/View/View.swift` |
| `EmptyView` | Empty placeholder leaf view. | `Core/View/View.swift` |
| `AnyView` | Type-erased wrapper for any View. | `Core/View/View.swift` |
| `IdentifiedView<Inner>` | View wrapper that attaches a stable identity for reconciliation. | `Core/View/View.swift` |
| `Node` | Long-lived identity anchor owning Model, Builder/Renderer, platform view, and subscriptions. | `Core/View/Node.swift` |
| `LeafNode` | Node for leaf views backed by a Renderer. | `Core/View/Node.swift` |
| `BuiltNode` | Node for stateless composites (BuiltView). | `Core/View/Node.swift` |
| `OffstageNode` | Node for Offstage views that mounts but stays invisible. | `Core/View/Node.swift` |
| `ProxyNode` | Node for proxy views wrapping a single child. | `Core/View/Node.swift` |
| `ModelNode` | Node for stateful composites (ModelView) with lifecycle management. | `Core/View/Node.swift` |
| `ContainerNode` | Node for container views managing multiple children. | `Core/View/Node.swift` |
| `PassthroughView` | Internal UIView/NSView subclass that passes touches through to children. | `Core/View/Node.swift` |
| `OffstageView` | Internal UIView subclass for hidden-but-mounted views. | `Core/View/Node.swift` |
| `ModelLifecycle` | Private struct managing model attach/detach lifecycle. | `Core/View/Node.swift` |
| `Animation` | Duration + delay + curve specification for animated transitions. | `Core/View/Animation.swift` |
| `Curve` | Typealias for `Mapper<Double, Double>` — maps linear time 0-1 to eased output. | `Core/View/Animation.swift` |
| `Track` | One animated value within a Motion with from/to values and optional curve override. | `Core/View/Animation.swift` |
| `Motion` | Multi-track animation driven by a single time source with tick-based updates. | `Core/View/Animation.swift` |
| `MotionDriver` | Observable tick source with linear progress 0-1 and pause/resume/seek control. | `Core/View/Animation.swift` |
| `MotionDriver.State` | Nested enum for driver state (idle, running, paused, completed). | `Core/View/Animation.swift` |
| `MotionDriver.Direction` | Nested enum for driver direction (forward, reverse). | `Core/View/Animation.swift` |
| `Lerpable` | Protocol for types that can be linearly interpolated between two values. | `Core/View/Animation.swift` |
| `Mergeable` | Protocol for types whose instances can be merged (non-nil fields win). | `Core/View/Animation.swift` |
| `Canvas` | Protocol for platform-agnostic 2D drawing with primitives and state ops. | `Core/View/Canvas.swift` |
| `Filter` | Canvas filter definitions (blur, shadow). | `Core/View/Canvas.swift` |
| `CGCanvas` | CoreGraphics implementation of Canvas. | `Core/View/Canvas.swift` |
| `Color` | RGBA color with perceptual luminance, color space conversions, palettes, and harmonies. | `Core/View/Color.swift` |
| `_ColorInverseBox` | Reference box for a color's optional inverse, enabling lazy computation. | `Core/View/Color.swift` |
| `OkLab` | Perceptually uniform color space (L, a, b). | `Core/View/Color.swift` |
| `OkLch` | Perceptually uniform cylindrical color space (L, C, H). | `Core/View/Color.swift` |
| `HSV` | HSV color space (hue 0-360, saturation 0-1, value 0-1). | `Core/View/Color.swift` |
| `HSL` | HSL color space (hue 0-360, saturation 0-1, lightness 0-1). | `Core/View/Color.swift` |
| `ColorSpace` | Enum of supported color spaces (srgb, oklab, oklch). | `Core/View/Color.swift` |
| `Hue` | Canonical hue identifier, an open TokenKey for apps to extend with custom hues. | `Core/View/Color.swift` |
| `HueScale` | Eleven colors at ascending depth (s0-s10) generated via an OkLch curve. | `Core/View/Color.swift` |
| `ScaleCurve` | Parametrization for HueScale generation via start/cusp/end anchors with handle magnitudes. | `Core/View/Color.swift` |
| `HueToken` | Single hue's full scale family (primary, vibrant, muted, grayscale). | `Core/View/Color.swift` |
| `CustomColor` | Named color outside the 12-hue grid with a palette derivation closure. | `Core/View/Color.swift` |
| `CustomColors` | View onto a palette's custom colors with per-token overrides. | `Core/View/Color.swift` |
| `ColorPalette` | Generative color substrate with 12 hue tokens, buildable from a seed or angles. | `Core/View/Color.swift` |
| `ColorRole` | Semantic color role (surface, fill, label, brand) as an open NamedKey. | `Core/View/Color.swift` |
| `ColorTheme` | Application color theme with roles, status tokens, and palette. | `Core/View/Color.swift` |
| `GesturePosition` | Focal position in both local and global coordinates. | `Core/View/Gestures.swift` |
| `TapStart` | Event fired at the start of a tap gesture. | `Core/View/Gestures.swift` |
| `TapUpdate` | Event fired during a tap gesture (finger moved). | `Core/View/Gestures.swift` |
| `TapEnd` | Event fired at the end of a tap gesture. | `Core/View/Gestures.swift` |
| `DoubleTapStart` | Event fired at the start of a double-tap gesture. | `Core/View/Gestures.swift` |
| `DoubleTapUpdate` | Event fired during a double-tap gesture. | `Core/View/Gestures.swift` |
| `DoubleTapEnd` | Event fired at the end of a double-tap gesture. | `Core/View/Gestures.swift` |
| `LongPressStart` | Event fired at the start of a long-press gesture. | `Core/View/Gestures.swift` |
| `LongPressUpdate` | Event fired during a long-press gesture. | `Core/View/Gestures.swift` |
| `LongPressEnd` | Event fired at the end of a long-press gesture. | `Core/View/Gestures.swift` |
| `DragStart` | Event fired at the start of a drag gesture. | `Core/View/Gestures.swift` |
| `DragUpdate` | Event fired during a drag gesture with translation and velocity. | `Core/View/Gestures.swift` |
| `DragEnd` | Event fired at the end of a drag gesture. | `Core/View/Gestures.swift` |
| `PanStart` | Event fired at the start of a multi-pointer pan gesture. | `Core/View/Gestures.swift` |
| `PanUpdate` | Event fired during a pan gesture with scale and rotation. | `Core/View/Gestures.swift` |
| `PanEnd` | Event fired at the end of a pan gesture. | `Core/View/Gestures.swift` |
| `TapConfig` | Configuration for tap gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `DoubleTapConfig` | Configuration for double-tap gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `PressConfig` | Configuration for press gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `HoldConfig` | Configuration for hold (long-press + drag) gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `DragConfig` | Configuration for drag gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `PanConfig` | Configuration for multi-pointer pan gesture recognition with callbacks. | `Core/View/Gestures.swift` |
| `LayoutReader` | ProxyView that reports the proposed container size to a content closure. | `Core/View/LayoutReader.swift` |
| `PlatformView` | Typealias for UIView (iOS) or NSView (macOS). | `Core/View/Platform.swift` |
| `PlatformColor` | Typealias for UIColor (iOS) or NSColor (macOS). | `Core/View/Platform.swift` |
| `PlatformFont` | Typealias for UIFont (iOS) or NSFont (macOS). | `Core/View/Platform.swift` |
| `Provided<each T>` | Injects values into a subtree, accessible via `context.read`/`context.watch`. | `Core/View/Provided.swift` |
| `ProvidedSlot<T>` | Per-provider storage cell with Observable for reactivity. | `Core/View/Provided.swift` |
| `AnyProvidedSlot` | Type-erased base protocol for mixed-T provider slot storage. | `Core/View/Provided.swift` |
| `RectReporter` | ProxyView that reports its post-layout rect to a callback in the parent's coordinate space. | `Core/View/RectReporter.swift` |
| `Ref<V>` | Property wrapper for obtaining a reference to a mounted view. | `Core/View/Ref.swift` |
| `Root` | Top-level resolver that owns the root Node and drives the view tree. | `Core/View/Resolver.swift` |
| `PlatformBridge` | Platform view that bridges Root into UIKit/AppKit view hierarchy. | `Core/View/Resolver.swift` |
| `SpacingToken` | Named spacing value token for the spacing theme. | `Core/View/Spacing.swift` |
| `SpacingTheme` | Theme collection of spacing tokens. | `Core/View/Spacing.swift` |
| `State` | OptionSet for interaction state flags (idle, pressed, disabled, focused, hovered, selected, loading, scrolledUnder). | `Core/View/State.swift` |
| `HapticStyle` | Haptic feedback intensity (light, medium, heavy, rigid, soft, none). | `Core/View/State.swift` |
| `Mapper<T, K>` | Generic function wrapper mapping T to K with an optional id. | `Core/View/State.swift` |
| `Handler` | Typealias for `@MainActor () -> Void`. | `Core/View/State.swift` |
| `ValueHandler<T>` | Typealias for `(T) -> Void`. | `Core/View/State.swift` |
| `StateProperty<T>` | Typealias for `Mapper<State, T>` — resolves a value based on UI state. | `Core/View/State.swift` |
| `ThemeSlot<T>` | Container for a themed value with an optional override. | `Core/View/Theme.swift` |
| `TokenTheme` | Abstract base for all theme containers. | `Core/View/Theme.swift` |
| `NamedKey` | Base protocol for named token identifiers (Hashable, Sendable). | `Core/View/Tokens.swift` |
| `TokenKey` | Protocol for token identifiers with a `defaultValue`. | `Core/View/Tokens.swift` |
| `TokenMap<K>` | Lookup table for token values keyed by a TokenKey. | `Core/View/Tokens.swift` |
| `PriorityLevel` | Named priority level token. | `Core/View/Tokens.swift` |
| `PriorityTokens<V>` | Stack of values at different priority levels (primary, secondary, tertiary, quaternary). | `Core/View/Tokens.swift` |
| `Status` | Named status token (success, warning, error, info). | `Core/View/Tokens.swift` |
| `StatusTokens<V>` | Collection of values keyed by Status tokens. | `Core/View/Tokens.swift` |

## Components / Content

| Type | Description | File |
|------|-------------|------|
| `Graphic` | Drawable vector graphics leaf view with SVG support; styled via GraphicStyle. | `Components/Content/Graphic.swift` |
| `GraphicStyle` | Visual styling for Graphic (fill, stroke, opacity, tint). | `Components/Content/Graphic.swift` |
| `GraphicSource` | Source for a Graphic (SVG data or file). | `Components/Content/Graphic.swift` |
| `GraphicOverride` | Override for specific elements within a Graphic. | `Components/Content/Graphic.swift` |
| `SVGPainter` | Renders an SVGDocument with paint attributes onto a Canvas. | `Components/Content/Graphic.swift` |
| `SVGDocument` | Parsed SVG document structure containing SVGElements. | `Components/Content/Graphic.swift` |
| `SVGElement` | Recursive enum of SVG element types (path, rect, circle, group, etc.). | `Components/Content/Graphic.swift` |
| `SVGPaintAttributes` | Paint attributes for SVG rendering (fill, stroke, opacity). | `Components/Content/Graphic.swift` |
| `SVGPaint` | SVG paint type (color, none). | `Components/Content/Graphic.swift` |
| `SVGPathData` | Data for an SVG path element. | `Components/Content/Graphic.swift` |
| `SVGRectData` | Data for an SVG rect element. | `Components/Content/Graphic.swift` |
| `SVGCircleData` | Data for an SVG circle element. | `Components/Content/Graphic.swift` |
| `SVGEllipseData` | Data for an SVG ellipse element. | `Components/Content/Graphic.swift` |
| `SVGLineData` | Data for an SVG line element. | `Components/Content/Graphic.swift` |
| `SVGPolygonData` | Data for an SVG polygon element. | `Components/Content/Graphic.swift` |
| `SVGGroupData` | Data for an SVG group element. | `Components/Content/Graphic.swift` |
| `SVGGroupBuilder` | Private XML parser delegate helper for building SVG groups. | `Components/Content/Graphic.swift` |
| `SVGPathDataParser` | Internal enum namespace for parsing SVG path `d` attribute strings. | `Components/Content/Graphic.swift` |
| `Symbol` | Platform system icon leaf view (SF Symbols on Apple, Material Symbols on Android); styled via SymbolStyle. | `Components/Content/Symbol.swift` |
| `SymbolStyle` | Visual styling for Symbol (size, weight, color, scale, mode, variable value). | `Components/Content/Symbol.swift` |
| `SymbolScale` | Symbol scale relative to adjacent text (small, medium, large). | `Components/Content/Symbol.swift` |
| `SymbolMode` | How a symbol's colors are applied (monochrome, hierarchical, palette, multicolor). | `Components/Content/Symbol.swift` |
| `SymbolRole` | Named symbol role token. | `Components/Content/Symbol.swift` |
| `SymbolTheme` | Theme for symbols with per-role defaults. | `Components/Content/Symbol.swift` |
| `Weight` | Shared font/icon weight enum (ultraLight through black, plus numeric). | `Core/Data/Weight.swift` |
| `Image` | ModelView that loads and displays images from various sources (image set, data asset, bundle resource, file, URL, bytes); styled via ImageStyle. | `Components/Content/Image.swift` |
| `ImageStyle` | Visual styling for Image (size, fit, state view builder for loading/error). | `Components/Content/Image.swift` |
| `ImageOrigin` | Platform-agnostic image source enum (image, asset, resource, file, url, bytes). | `Components/Content/Image.swift` |
| `ImageFit` | How an image fits its container (cover, contain, fill, center). | `Components/Content/Image.swift` |
| `ResolvedImage` | Internal enum for resolved image data (named image set or raw data). | `Components/Content/Image.swift` |
| `ImageLeaf` | Internal leaf view that renders a resolved image via platform renderer. | `Components/Content/Image.swift` |
| `ImageModel` | Persistent state managing async image loading lifecycle. | `Components/Content/Image.swift` |
| `ImageBuilder` | Per-render builder that shows state view or loaded image. | `Components/Content/Image.swift` |
| `Loader` | Loading spinner/progress indicator leaf view. | `Components/Content/Loader.swift` |
| `LoaderStyle` | Enum of built-in loader animation variants (circular, dots, pulse, bars, etc.). | `Components/Content/Loader.swift` |
| `LoaderPainter` | Protocol for custom loader drawing implementations. | `Components/Content/Loader.swift` |
| `CircularPainter` | Internal painter for the circular spinning loader. | `Components/Content/Loader.swift` |
| `DotsPainter` | Internal painter for the animated dots loader. | `Components/Content/Loader.swift` |
| `PulsePainter` | Internal painter for the pulsing loader. | `Components/Content/Loader.swift` |
| `BarsPainter` | Internal painter for the animated bars loader. | `Components/Content/Loader.swift` |
| `OrbitPainter` | Internal painter for the orbiting loader. | `Components/Content/Loader.swift` |
| `RipplePainter` | Internal painter for the ripple loader. | `Components/Content/Loader.swift` |
| `BouncePainter` | Internal painter for the bouncing loader. | `Components/Content/Loader.swift` |
| `WavePainter` | Internal painter for the wave loader. | `Components/Content/Loader.swift` |
| `FlipPainter` | Internal painter for the flipping loader. | `Components/Content/Loader.swift` |
| `FadePainter` | Internal painter for the fading loader. | `Components/Content/Loader.swift` |
| `Fill` | Protocol for types that can fill a shape on a Canvas (color, gradient, image). | `Components/Content/Surface.swift` |
| `ColorFill` | Solid color fill. | `Components/Content/Surface.swift` |
| `GradientFill<G>` | Gradient-based fill wrapping any Gradient type. | `Components/Content/Surface.swift` |
| `ImageFill` | Image-based fill with content fit and tiling options. | `Components/Content/Surface.swift` |
| `Gradient` | Protocol for gradient types drawable on a Canvas within bounds. | `Components/Content/Surface.swift` |
| `GradientStop` | Single stop in a gradient (color + location). | `Components/Content/Surface.swift` |
| `LinearGradient` | Gradient along a linear axis between two points. | `Components/Content/Surface.swift` |
| `RadialGradient` | Gradient radiating from a center point. | `Components/Content/Surface.swift` |
| `AngularGradient` | Angular/conic gradient sweeping around a center point. | `Components/Content/Surface.swift` |
| `GlassStyle` | Frosted glass style variants for blur-based backgrounds. | `Components/Content/Surface.swift` |
| `ImageSource` | Image source wrapper (asset name, UIImage, data, URL). | `Components/Content/Surface.swift` |
| `ContentFit` | How content fits its container (cover, contain, fill, etc.). | `Components/Content/Surface.swift` |
| `Shader` | Custom shader specification for rendering. | `Components/Content/Surface.swift` |
| `Paint` | Complete paint specification (fill, blend mode, opacity). | `Components/Content/Surface.swift` |
| `BlendMode` | Blend mode operators (normal, multiply, screen, overlay, etc.). | `Components/Content/Surface.swift` |
| `Stroke` | Stroke specification with width, cap, join, and dash pattern. | `Components/Content/Surface.swift` |
| `StrokeCap` | Line cap style (butt, round, square). | `Components/Content/Surface.swift` |
| `StrokeJoin` | Line join style (miter, round, bevel). | `Components/Content/Surface.swift` |
| `Dash` | Dash pattern for stroked lines. | `Components/Content/Surface.swift` |
| `Transform2D` | 2D affine transformation matrix with static factory methods. | `Components/Content/Surface.swift` |
| `RotationAxis` | Rotation axis (x, y, z). | `Components/Content/Surface.swift` |
| `FillRule` | Path fill rule (winding, evenOdd). | `Components/Content/Surface.swift` |
| `SurfaceContext` | Context passed to layers during surface rendering. | `Components/Content/Surface.swift` |
| `Layer` | Protocol for composable rendering layers (fill, stroke, shadow, transform, clip, fade, blend). | `Components/Content/Surface.swift` |
| `FillLayer` | Layer that fills a shape with a Fill. | `Components/Content/Surface.swift` |
| `StrokeLayer` | Layer that strokes a shape's outline. | `Components/Content/Surface.swift` |
| `ShadowLayer` | Layer that renders a shadow behind content. | `Components/Content/Surface.swift` |
| `TransformLayer` | Layer that applies a 2D transform. | `Components/Content/Surface.swift` |
| `ClipLayer` | Layer that clips content to a shape. | `Components/Content/Surface.swift` |
| `FadeLayer` | Layer that fades content with an opacity value. | `Components/Content/Surface.swift` |
| `BlendLayer` | Layer that composites content with a blend mode. | `Components/Content/Surface.swift` |
| `Surface` | Complete surface specification composed of ordered layers. | `Components/Content/Surface.swift` |
| `SurfaceRenderer` | Renderer that draws a Surface's layers onto a platform view. | `Components/Content/Surface.swift` |
| `TextStyle` | Text styling (font, color, maxLines, align, case, overflow, decoration). | `Components/Content/Text.swift` |
| `Font` | Font specification (family, size, height, tracking, weight, italic, features). | `Components/Content/Text.swift` |
| `FontFeatures` | Advanced OpenType font feature settings. | `Components/Content/Text.swift` |
| `FontAxis` | Variable font axes (weight, width, slant, optical size, grade, etc.). | `Components/Content/Text.swift` |
| `TextAlign` | Text alignment (leading, trailing, center, justify). | `Components/Content/Text.swift` |
| `TextOverflow` | Text overflow mode (clip, ellipsis). | `Components/Content/Text.swift` |
| `TextCase` | Text case transformation (plain, uppercase, lowercase, capitalize, title, pascal, camel, snake, kebab, dot, sponge). | `Components/Content/Text.swift` |
| `TextDecoration` | Text decoration with separate underline, strikethrough, and shadow. | `Components/Content/Text.swift` |
| `TextLineStyle` | Visual style for an underline or strikethrough line (color, style). | `Components/Content/Text.swift` |
| `ShadowConfig` | Shadow configuration for text (color, offset, blur). | `Components/Content/Text.swift` |
| `Text` | Text display composite view; styled via TextStyle. | `Components/Content/Text.swift` |
| `TextLeaf` | Internal leaf view that renders text to a platform label. | `Components/Content/Text.swift` |
| `FontInfo` | Internal struct caching resolved platform font metrics. | `Components/Content/Text.swift` |
| `VariationAxisInfo` | Internal struct describing a variable font axis range. | `Components/Content/Text.swift` |
| `TextSize` | Named text size token for the text theme. | `Components/Content/Text.swift` |
| `TextWeight` | Named text weight token for the text theme. | `Components/Content/Text.swift` |
| `TextLineHeight` | Named text line-height token for the text theme. | `Components/Content/Text.swift` |
| `TextRole` | Named text role token (body, caption, title, etc.). | `Components/Content/Text.swift` |
| `RoleTheme` | Per-role text style theme. | `Components/Content/Text.swift` |
| `TextTheme` | Complete text theme with sizes, weights, line heights, and roles. | `Components/Content/Text.swift` |

## Components / Input

| Type | Description | File |
|------|-------------|------|
| `Button` | Tappable component with state-reactive styling; styled via ButtonStyle. | `Components/Input/Button.swift` |
| `ButtonStyle` | Visual styling for Button (box, text, haptic, animation per state). | `Components/Input/Button.swift` |
| `ButtonModel` | Persistent state for Button tracking press/disabled state. | `Components/Input/Button.swift` |
| `ButtonBuilder` | Per-render builder for Button. | `Components/Input/Button.swift` |
| `ButtonRole` | Named button role token. | `Components/Input/Button.swift` |
| `ButtonTheme` | Theme for buttons with per-role defaults. | `Components/Input/Button.swift` |
| `Gesture` | Low-level gesture handler proxy view attaching gesture recognizers to its child. | `Components/Input/Gesture.swift` |
| `AccessibilityTraits` | OptionSet of accessibility feature flags. | `Components/Input/Gesture.swift` |
| `AccessibilityConfig` | Accessibility configuration (label, traits, hint, value). | `Components/Input/Gesture.swift` |
| `TapHandler` | BuiltView that attaches a tap gesture to its child. | `Components/Input/Gesture.swift` |
| `DoubleTapHandler` | BuiltView that attaches a double-tap gesture to its child. | `Components/Input/Gesture.swift` |
| `PressHandler` | BuiltView that attaches a press gesture to its child. | `Components/Input/Gesture.swift` |
| `HoldHandler` | BuiltView that attaches a hold (long-press + drag) gesture to its child. | `Components/Input/Gesture.swift` |
| `DragHandler` | BuiltView that attaches a drag gesture to its child. | `Components/Input/Gesture.swift` |
| `PanHandler` | BuiltView that attaches a multi-pointer pan gesture to its child. | `Components/Input/Gesture.swift` |
| `Plane` | Draggable 2D surface with gesture tracking for position control. | `Components/Input/Plane.swift` |
| `PlaneModel` | Persistent state for Plane tracking pan/drag position. | `Components/Input/Plane.swift` |
| `PlaneBuilder` | Per-render builder for Plane. | `Components/Input/Plane.swift` |
| `PlaneLeaf` | Internal leaf view backing Plane's gesture surface. | `Components/Input/Plane.swift` |
| `DragTransform` | Typealias for `Mapper<Vec2, Vec2>` — transforms drag position. | `Components/Input/Plane.swift` |
| `Segmented<T>` | Segmented control component for selecting among hashable options. | `Components/Input/Segmented.swift` |
| `SegmentedStyle<T>` | Visual styling for Segmented. | `Components/Input/Segmented.swift` |
| `SegmentedModel<T>` | Persistent state for Segmented tracking selection. | `Components/Input/Segmented.swift` |
| `SegmentedBuilder<T>` | Per-render builder for Segmented. | `Components/Input/Segmented.swift` |
| `SegmentedGestures<T>` | Internal leaf view managing segmented control touch handling. | `Components/Input/Segmented.swift` |
| `SegmentedRole` | Named segmented role token. | `Components/Input/Segmented.swift` |
| `SegmentedTheme<T>` | Theme for segmented controls. | `Components/Input/Segmented.swift` |
| `Slider` | Numeric slider component for selecting a value within a range. | `Components/Input/Slider.swift` |
| `SliderStyle` | Visual styling for Slider (track, thumb, label). | `Components/Input/Slider.swift` |
| `TrackStyle` | Styling for the slider track. | `Components/Input/Slider.swift` |
| `ThumbStyle` | Styling for the slider thumb. | `Components/Input/Slider.swift` |
| `TrackDivisions` | Division marker configuration for the slider track. | `Components/Input/Slider.swift` |
| `DivisionLabelStyle` | Styling for division labels on a slider. | `Components/Input/Slider.swift` |
| `ThumbLabelStyle` | Styling for the thumb value label on a slider. | `Components/Input/Slider.swift` |
| `SliderModel` | Persistent state for Slider tracking drag position. | `Components/Input/Slider.swift` |
| `SliderBuilder` | Per-render builder for Slider. | `Components/Input/Slider.swift` |
| `SliderLeaf` | Internal leaf view managing slider touch handling. | `Components/Input/Slider.swift` |
| `SliderRole` | Named slider role token. | `Components/Input/Slider.swift` |
| `SliderTheme` | Theme for sliders. | `Components/Input/Slider.swift` |
| `Stepper<T>` | Numeric stepper with increment/decrement buttons and optional text input. | `Components/Input/Stepper.swift` |
| `StepperStyle<T>` | Visual styling for Stepper. | `Components/Input/Stepper.swift` |
| `StepperButton` | Styling for a stepper's +/- buttons. | `Components/Input/Stepper.swift` |
| `LongPressConfig` | Configuration for stepper long-press repeat acceleration. | `Components/Input/Stepper.swift` |
| `StepperDragConfig` | Configuration for stepper drag-to-change behavior. | `Components/Input/Stepper.swift` |
| `ValueTransition` | Transition animation for stepper value changes. | `Components/Input/Stepper.swift` |
| `TransitionDirection` | Direction of a value transition animation (up, down, fade). | `Components/Input/Stepper.swift` |
| `StepperModel<T>` | Persistent state for Stepper. | `Components/Input/Stepper.swift` |
| `StepperBuilder<T>` | Per-render builder for Stepper. | `Components/Input/Stepper.swift` |
| `StepperFieldLeaf<T>` | Internal leaf view for the stepper's editable text field. | `Components/Input/Stepper.swift` |
| `TextField<T>` | Text input field with generic value type, parsing, and validation. | `Components/Input/TextField.swift` |
| `TextFieldLogic<T>` | Logic for TextField value parsing, formatting, and validation. | `Components/Input/TextField.swift` |
| `TextFieldDecoration` | Decoration slots for TextField (prefix, suffix, hint). | `Components/Input/TextField.swift` |
| `KeyboardConfig` | Keyboard configuration (type, content type, autocapitalization, return key). | `Components/Input/TextField.swift` |
| `KeyboardType` | Keyboard type (default, numeric, decimal, email, phone, URL, etc.). | `Components/Input/TextField.swift` |
| `ContentType` | Content type hint for autofill (password, oneTimeCode, etc.). | `Components/Input/TextField.swift` |
| `Autocapitalization` | Autocapitalization mode (none, words, sentences, allCharacters). | `Components/Input/TextField.swift` |
| `ReturnKey` | Return key style (done, go, next, search, send, etc.). | `Components/Input/TextField.swift` |
| `TextFieldStyle` | Visual styling for TextField. | `Components/Input/TextField.swift` |
| `LabelPosition` | Label position relative to input (above, leading, floating, none). | `Components/Input/TextField.swift` |
| `TextMask` | Internal enum for text masking behavior (password, etc.). | `Components/Input/TextField.swift` |
| `PasswordStrength` | Password strength indicator levels. | `Components/Input/TextField.swift` |
| `TextFieldModel<T>` | Persistent state for TextField. | `Components/Input/TextField.swift` |
| `TextFieldBuilder<T>` | Per-render builder for TextField. | `Components/Input/TextField.swift` |
| `TextFieldLeaf<T>` | Internal leaf view managing native text input. | `Components/Input/TextField.swift` |
| `TextFieldRole` | Named text field role token. | `Components/Input/TextField.swift` |
| `TextFieldTheme` | Theme for text fields. | `Components/Input/TextField.swift` |
| `TextParser<T>` | Typealias for `Mapper<String, T?>` — parses text input into a typed value. | `Components/Input/TextField.swift` |
| `TextFormatter<T>` | Typealias for `Mapper<T, String>` — formats a typed value for display. | `Components/Input/TextField.swift` |
| `TextTransformer` | Typealias for `Mapper<String, String>` — transforms text input. | `Components/Input/TextField.swift` |
| `InputFilter` | Typealias for `Mapper<String, Bool>` — filters input characters. | `Components/Input/TextField.swift` |
| `InputValidator<T>` | Typealias for `Mapper<T, String?>` — validates parsed values, returning error text. | `Components/Input/TextField.swift` |
| `Toggle` | Toggle/checkbox/radio/switch component; styled via ToggleStyle. | `Components/Input/Toggle.swift` |
| `ToggleStyle` | Visual styling for Toggle. | `Components/Input/Toggle.swift` |
| `TogglePainter` | Protocol for custom toggle drawing implementations. | `Components/Input/Toggle.swift` |
| `ToggleModel` | Persistent state for Toggle. | `Components/Input/Toggle.swift` |
| `ToggleBuilder` | Per-render builder for Toggle. | `Components/Input/Toggle.swift` |
| `ToggleLeaf` | Internal leaf view managing toggle touch handling. | `Components/Input/Toggle.swift` |
| `CheckboxPainter` | Built-in painter for checkbox-style toggles. | `Components/Input/Toggle.swift` |
| `RadioPainter` | Built-in painter for radio-button-style toggles. | `Components/Input/Toggle.swift` |
| `SwitchPainter` | Built-in painter for switch-style toggles. | `Components/Input/Toggle.swift` |
| `HeartPainter` | Built-in painter for heart-shaped toggles. | `Components/Input/Toggle.swift` |
| `ToggleRole` | Named toggle role token. | `Components/Input/Toggle.swift` |
| `ToggleTheme` | Theme for toggles. | `Components/Input/Toggle.swift` |

## Components / Layout

| Type | Description | File |
|------|-------------|------|
| `Box` | Fundamental layout container with surface, shape, padding, clipping, and overflow. | `Components/Layout/Box.swift` |
| `BoxStyle` | Visual styling for Box. | `Components/Layout/Box.swift` |
| `BoxRole` | Named box role token. | `Components/Layout/Box.swift` |
| `BoxTheme` | Theme for boxes. | `Components/Layout/Box.swift` |
| `DebugOverlay` | Debug visualization overlay showing layout boundaries. | `Components/Layout/Box.swift` |
| `BoxView` | Internal UIView subclass backing Box's platform rendering. | `Components/Layout/Box.swift` |
| `SurfaceView` | Internal UIView subclass rendering Surface layers via Core Animation. | `Components/Layout/Box.swift` |
| `Spread` | Item distribution mode within a flex container (packed, between, around, even). | `Components/Layout/Flex.swift` |
| `Column` | Vertical flex container arranging children top-to-bottom. | `Components/Layout/Flex.swift` |
| `Row` | Horizontal flex container arranging children left-to-right. | `Components/Layout/Flex.swift` |
| `FlexSlot` | Internal struct representing one child slot in a flex layout. | `Components/Layout/Flex.swift` |
| `FlexLine` | Internal struct representing one line of children in a wrapping flex layout. | `Components/Layout/Flex.swift` |
| `SafeArea` | Container that insets content to respect device safe areas (notches, home indicator). | `Components/Layout/SafeArea.swift` |

## Components / Native

| Type | Description | File |
|------|-------------|------|
| `BarButton` | Native navigation bar button item. | `Components/Native/BarButton.swift` |
| `BarButtonStyle` | Style variants for bar buttons. | `Components/Native/BarButton.swift` |
| `BarButtonRole` | Role variants for bar buttons (back, close, action, etc.). | `Components/Native/BarButton.swift` |
| `NativeView<V>` | Wrapper that embeds a raw UIView/NSView into the Forge view tree. | `Components/Native/NativeView.swift` |

## Components / Overlays

| Type | Description | File |
|------|-------------|------|
| `Lift` | Elevation component that presents its child as a floating overlay. | `Components/Overlays/Lift.swift` |
| `LiftModel` | Persistent state for Lift managing overlay lifecycle. | `Components/Overlays/Lift.swift` |
| `LiftBuilder` | Per-render builder for Lift. | `Components/Overlays/Lift.swift` |
| `LiftOverlay` | Internal BuiltView implementing the lifted overlay as a Route. | `Components/Overlays/Lift.swift` |
| `NavigationBar` | Navigation bar composite view with leading/center/trailing content. | `Components/Overlays/NavigationBar.swift` |
| `NavigationItem` | Item configuration for a navigation bar slot. | `Components/Overlays/NavigationBar.swift` |
| `Navigation` | Full navigation setup composing a NavigationBar with page content. | `Components/Overlays/NavigationBar.swift` |
| `NavBarContentRow` | Container view for a row of navigation bar content. | `Components/Overlays/NavigationBar.swift` |
| `NavBarCenterMode` | How center content is displayed in the navigation bar (title, custom, etc.). | `Components/Overlays/NavigationBar.swift` |
| `Route` | Protocol for any view the Router can manage (key, opaque, duration, cover). | `Components/Overlays/Router/Route.swift` |
| `RoutePhase` | Phase of a route's lifecycle (entering, exiting, settled, hidden). | `Components/Overlays/Router/Route.swift` |
| `RouteHandle` | Protocol for controlling a route (dismiss, scrub transition progress). | `Components/Overlays/Router/Route.swift` |
| `RouteModel` | Per-route state managing lifecycle, animation, and phase transitions. | `Components/Overlays/Router/Route.swift` |
| `PopGuard` | Modifier that intercepts and optionally prevents route dismissal. | `Components/Overlays/Router/Route.swift` |
| `RouterHandle` | Protocol for controlling the Router (push, pop, insert, remove, replace). | `Components/Overlays/Router/Router.swift` |
| `Router` | Navigation router with stack management and deep link support. | `Components/Overlays/Router/Router.swift` |
| `RouterModel` | Persistent state for Router managing the route stack. | `Components/Overlays/Router/Router.swift` |
| `RouterBuilder` | Per-render builder for Router. | `Components/Overlays/Router/Router.swift` |
| `CoverTransform` | Fileprivate BuiltView applying cover-style transitions to routes. | `Components/Overlays/Router/Router.swift` |
| `DeepLink` | Deep link configuration mapping a URL pattern to route construction. | `Components/Overlays/Router/Router.swift` |
| `URLParams` | Parsed URL parameters extracted from a matched deep link. | `Components/Overlays/Router/Router.swift` |
| `DeepLinkBuilder` | Builder for constructing DeepLink configurations. | `Components/Overlays/Router/Router.swift` |
| `DeepLinkMap` | Collection mapping URL patterns to route factories. | `Components/Overlays/Router/Router.swift` |
| `Screen` | Full-screen route type. | `Components/Overlays/Router/Routes.swift` |
| `Modal` | Modal overlay route type. | `Components/Overlays/Router/Routes.swift` |
| `Sheet` | Bottom sheet route type with detent support. | `Components/Overlays/Router/Routes.swift` |
| `SheetDetent` | Sheet height presets (small, medium, large). | `Components/Overlays/Router/Routes.swift` |
| `Drawer` | Side drawer route type. | `Components/Overlays/Router/Routes.swift` |
| `HorizontalEdge` | Horizontal edge (leading, trailing) for drawer placement. | `Components/Overlays/Router/Routes.swift` |
| `Cover` | Full-cover route type (modal that covers entire screen). | `Components/Overlays/Router/Routes.swift` |
| `Alert` | Alert dialog route type. | `Components/Overlays/Router/Routes.swift` |
| `Barrier` | Scrim/barrier overlay behind modal routes. | `Components/Overlays/Router/Routes.swift` |
| `Coachmark` | Tutorial coachmark overlay route type. | `Components/Overlays/Router/Routes.swift` |
| `ContextMenu` | Context menu route type. | `Components/Overlays/Router/Routes.swift` |
| `Lightbox` | Full-screen image viewer route type. | `Components/Overlays/Router/Routes.swift` |
| `Popover` | Popover menu route type. | `Components/Overlays/Router/Routes.swift` |
| `Toast` | Toast notification route type. | `Components/Overlays/Router/Routes.swift` |
| `ToastPosition` | Toast position (top, bottom, center). | `Components/Overlays/Router/Routes.swift` |

## Components / Visibility

| Type | Description | File |
|------|-------------|------|
| `Animated<T>` | ModelView that animates a Lerpable value and rebuilds on each frame. | `Components/Visibility/Animated.swift` |
| `AnimatedModel<T>` | Persistent state for Animated managing the animation driver. | `Components/Visibility/Animated.swift` |
| `AnimatedBuilder<T>` | Per-render builder for Animated. | `Components/Visibility/Animated.swift` |
| `DismissPhase` | Phase of a gesture-driven dismissal (none, dismissing, dismissed). | `Components/Visibility/Dismissible.swift` |
| `DismissThreshold` | Threshold configuration for when a drag becomes a dismissal. | `Components/Visibility/Dismissible.swift` |
| `Dismissible` | ModelView wrapping content in a gesture-driven dismiss interaction. | `Components/Visibility/Dismissible.swift` |
| `DismissibleModel` | Persistent state for Dismissible tracking drag progress. | `Components/Visibility/Dismissible.swift` |
| `DismissibleBuilder` | Per-render builder for Dismissible. | `Components/Visibility/Dismissible.swift` |
| `TransitionStatus` | Status of a transition animation (entering, exiting, settled). | `Components/Visibility/Transition.swift` |
| `TransitionState` | Current animation state passed to TransitionEffect (status, progress). | `Components/Visibility/Transition.swift` |
| `TransitionEffect` | Protocol for custom transition effects applied on mount/unmount. | `Components/Visibility/Transition.swift` |
| `Fade` | Opacity-based transition effect. | `Components/Visibility/Transition.swift` |
| `Scale` | Scale-based transition effect. | `Components/Visibility/Transition.swift` |
| `Slide` | Slide-in/out transition effect from an edge. | `Components/Visibility/Transition.swift` |
| `Rotate` | Rotation-based transition effect. | `Components/Visibility/Transition.swift` |
| `Transition` | ProxyView that applies TransitionEffects when its child mounts or unmounts. | `Components/Visibility/Transition.swift` |
| `EffectOp` | Internal enum describing a transition operation (surface transform, offset, opacity). | `Components/Visibility/Effect.swift` |
| `EffectView` | Internal ProxyView that applies resolved EffectOps to its child. | `Components/Visibility/Effect.swift` |
