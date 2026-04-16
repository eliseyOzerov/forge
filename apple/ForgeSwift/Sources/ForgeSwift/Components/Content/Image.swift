#if canImport(UIKit)
import UIKit

/// Sync image component. Takes an already-loaded platform image.
public struct Image: LeafView {
    public let image: UIImage
    public let style: ImageStyle

    public init(_ image: UIImage, style: ImageStyle = ImageStyle()) {
        self.image = image
        self.style = style
    }

    public init(named name: String, style: ImageStyle = ImageStyle()) {
        self.image = UIImage(named: name) ?? UIImage()
        self.style = style
    }

    public func makeRenderer() -> Renderer {
        UIKitImageRenderer(image: image, style: style)
    }
}

// MARK: - AsyncImage

/// Async image component. Uses a Source<UIImage> to load the image,
/// with a state builder for loading/error/loaded states.
public struct AsyncImage: ModelView {
    public let source: any Source<UIImage>
    public let style: ImageStyle
    public let loading: (() -> any View)?
    public let error: ((Error) -> any View)?

    public init(
        source: any Source<UIImage>,
        style: ImageStyle = ImageStyle(),
        loading: (() -> any View)? = nil,
        error: ((Error) -> any View)? = nil
    ) {
        self.source = source
        self.style = style
        self.loading = loading
        self.error = error
    }

    public init(
        url: URL,
        style: ImageStyle = ImageStyle(),
        loading: (() -> any View)? = nil,
        error: ((Error) -> any View)? = nil
    ) {
        self.source = URLSource<UIImage>(url) { data in
            guard let img = UIImage(data: data) else { throw SourceError.notFound("Invalid image data") }
            return img
        }
        self.style = style
        self.loading = loading
        self.error = error
    }

    public init(
        asset name: String,
        style: ImageStyle = ImageStyle(),
        loading: (() -> any View)? = nil,
        error: ((Error) -> any View)? = nil
    ) {
        self.source = AssetSource<UIImage>(name) { data in
            guard let img = UIImage(data: data) else { throw SourceError.notFound("Invalid image data") }
            return img
        }
        self.style = style
        self.loading = loading
        self.error = error
    }

    public init(
        file url: URL,
        style: ImageStyle = ImageStyle(),
        loading: (() -> any View)? = nil,
        error: ((Error) -> any View)? = nil
    ) {
        self.source = FileSource<UIImage>(url) { data in
            guard let img = UIImage(data: data) else { throw SourceError.notFound("Invalid image data") }
            return img
        }
        self.style = style
        self.loading = loading
        self.error = error
    }

    public func model(context: BuildContext) -> AsyncImageModel {
        AsyncImageModel(context: context)
    }

    public func builder(model: AsyncImageModel) -> AsyncImageBuilder {
        AsyncImageBuilder(model: model)
    }
}

// MARK: - ImageStyle

public struct ImageStyle {
    public var fit: ImageFit
    public var tintColor: Color?
    public var cornerRadius: Double

    public init(fit: ImageFit = .aspectFit, tintColor: Color? = nil, cornerRadius: Double = 0) {
        self.fit = fit
        self.tintColor = tintColor
        self.cornerRadius = cornerRadius
    }
}

public enum ImageFit: Sendable {
    case aspectFit
    case aspectFill
    case fill
    case center

    var uiContentMode: UIView.ContentMode {
        switch self {
        case .aspectFit: .scaleAspectFit
        case .aspectFill: .scaleAspectFill
        case .fill: .scaleToFill
        case .center: .center
        }
    }
}

// MARK: - AsyncImage ViewModel

public final class AsyncImageModel: ViewModel<AsyncImage> {
    var loadedImage: UIImage?
    var loadError: Error?
    var isLoading = false

    public override func didInit(view: AsyncImage) {
        super.didInit(view: view)
        startLoading()
    }

    private func startLoading() {
        isLoading = true
        let source = view.source
        Task { @MainActor [weak self] in
            await source.load()
            guard let self else { return }
            switch source.state {
            case .loaded(let img):
                self.rebuild {
                    self.loadedImage = img
                    self.isLoading = false
                }
            case .error(let err):
                self.rebuild {
                    self.loadError = err
                    self.isLoading = false
                }
            default:
                break
            }
        }
    }
}

public final class AsyncImageBuilder: ViewBuilder<AsyncImageModel> {
    public override func build(context: BuildContext) -> any View {
        if model.isLoading {
            return model.view.loading?() ?? Text("Loading...")
        }
        if let error = model.loadError {
            return model.view.error?(error) ?? Text("Error")
        }
        if let image = model.loadedImage {
            return Image(image, style: model.view.style)
        }
        return Text("")
    }
}

// MARK: - Renderer

final class UIKitImageRenderer: Renderer {
    let image: UIImage
    let style: ImageStyle

    init(image: UIImage, style: ImageStyle) {
        self.image = image
        self.style = style
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        apply(to: imageView)
        return imageView
    }

    func update(_ platformView: PlatformView) {
        guard let imageView = platformView as? UIImageView else { return }
        apply(to: imageView)
    }

    private func apply(to imageView: UIImageView) {
        imageView.contentMode = style.fit.uiContentMode
        imageView.clipsToBounds = true

        if let tint = style.tintColor {
            imageView.image = image.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = tint.platformColor
        } else {
            imageView.image = image
        }

        imageView.layer.cornerRadius = style.cornerRadius
    }
}

#else

public struct Image: BuiltView {
    public init() {}
    public func build(context: BuildContext) -> any View { Text("TODO: Image") }
}

#endif
