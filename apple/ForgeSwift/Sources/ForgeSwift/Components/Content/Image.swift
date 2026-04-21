// MARK: - Image

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
        UIKitImageRenderer(view: self)
    }
}

#endif

// MARK: - ImageStyle

/// Visual style for an image (fit mode, tint, corner radius).
@Init @Copy
public struct ImageStyle {
    @Snap public var fit: ImageFit = .aspectFit
    public var tintColor: Color? = nil
    public var cornerRadius: Double = 0
}

/// How an image fits its container (cover, contain, fill, etc.).
public enum ImageFit: Sendable {
    case aspectFit
    case aspectFill
    case fill
    case center
}

// MARK: - Renderer

#if canImport(UIKit)

final class UIKitImageRenderer: Renderer {
    private weak var imageView: UIImageView?
    private var view: Image

    init(view: Image) {
        self.view = view
    }

    func update(from newView: any View) {
        guard let img = newView as? Image, let imageView else { return }
        let old = view
        view = img

        let imageChanged = old.image !== img.image
        if imageChanged {
            imageView.superview?.setNeedsLayout()
        }

        // Always apply image+style (ImageFit/tint lack Equatable)
        applyImage(to: imageView)
        imageView.contentMode = img.style.fit.uiContentMode
        imageView.layer.cornerRadius = img.style.cornerRadius
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        self.imageView = imageView
        imageView.contentMode = view.style.fit.uiContentMode
        applyImage(to: imageView)
        imageView.layer.cornerRadius = view.style.cornerRadius
        return imageView
    }

    private func applyImage(to imageView: UIImageView) {
        if let tint = view.style.tintColor {
            imageView.image = view.image.withRenderingMode(.alwaysTemplate)
            imageView.tintColor = tint.platformColor
        } else {
            imageView.image = view.image
        }
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

    public func model(context: ViewContext) -> AsyncImageModel {
        AsyncImageModel(context: context)
    }

    public func builder(model: AsyncImageModel) -> AsyncImageBuilder {
        AsyncImageBuilder(model: model)
    }
}

// MARK: - AsyncImage ViewModel

/// View model that manages async loading state for an AsyncImage.
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

/// Builds the appropriate child view based on async image loading state.
public final class AsyncImageBuilder: ViewBuilder<AsyncImageModel> {
    public override func build(context: ViewContext) -> any View {
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

extension ImageFit {
    var uiContentMode: UIView.ContentMode {
        switch self {
        case .aspectFit: .scaleAspectFit
        case .aspectFill: .scaleAspectFill
        case .fill: .scaleToFill
        case .center: .center
        }
    }
}

#endif
