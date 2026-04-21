import Foundation

// MARK: - Image

/// Displays an image from various sources (image set, data asset, bundle
/// resource, file, URL, raw bytes). Uses ModelView to handle async loading;
/// the builder returns a state view for loading/error or an internal
/// `ImageLeaf` when loaded. Styled via `ImageStyle`.
public struct Image: ModelView {
    public var source: ImageOrigin
    public var style: StateProperty<ImageStyle>

    public init(
        _ source: ImageOrigin,
        style: StateProperty<ImageStyle> = .constant(ImageStyle())
    ) {
        self.source = source
        self.style = style
    }

    public func style(_ build: @escaping @MainActor (ImageStyle, State) -> ImageStyle) -> Image {
        var copy = self
        copy.style = StateProperty { state in build(ImageStyle(), state) }
        return copy
    }

    public func model(context: ViewContext) -> ImageModel { ImageModel(context: context) }
    public func builder(model: ImageModel) -> ImageBuilder { ImageBuilder(model: model) }
}

// MARK: - ImageStyle

/// Visual styling for Image (size, fit, state view builder for loading/error).
@Style
public struct ImageStyle {
    public var size: Size? = nil
    @Snap public var fit: ImageFit = .cover
    @Snap public var state: StateProperty<any View>? = nil
}

// MARK: - ImageOrigin

/// Platform-agnostic image source.
public enum ImageOrigin: Sendable {
    /// Image Set in the asset catalog (`UIImage(named:)` / `NSImage(named:)`).
    /// Resolved natively by the renderer — no data round-trip.
    case image(String)
    /// Data Set in the asset catalog (`NSDataAsset`).
    case asset(String)
    /// Loose file in the app bundle (`Bundle.main.url(forResource:)`).
    case resource(String)
    /// File in the app's file storage (documents, caches, tmp).
    case file(URL)
    /// Remote URL loaded via `URLSession`.
    case url(URL)
    /// Raw image data already in memory.
    case bytes(Data)
}

// MARK: - ImageFit

/// How an image fits its container.
public enum ImageFit: Sendable, Equatable {
    case cover
    case contain
    case fill
    case center
}

// MARK: - ResolvedImage

/// Resolved image ready for rendering.
enum ResolvedImage {
    /// Image Set name — renderer resolves natively.
    case named(String)
    /// Decoded image data.
    case data(Data)
}

// MARK: - ImageLeaf

/// Internal leaf view that renders a resolved image.
struct ImageLeaf: LeafView {
    let resolved: ResolvedImage
    let style: ImageStyle

    func makeRenderer() -> Renderer {
        #if canImport(UIKit)
        UIKitImageRenderer(view: self)
        #else
        fatalError("Image not yet implemented for this platform")
        #endif
    }
}

// MARK: - ImageModel

/// Manages async image loading lifecycle.
public final class ImageModel: ViewModel<Image> {
    var resolved: ResolvedImage?
    var loadError: Error?
    var loadState: State = .loading

    public override func didInit(view: Image) {
        super.didInit(view: view)
        load(source: view.source)
    }

    public override func didUpdate(newView: Image) {
        let oldSource = view.source
        super.didUpdate(newView: newView)
        if !sourceEqual(oldSource, newView.source) {
            resolved = nil
            loadError = nil
            loadState = .loading
            load(source: newView.source)
        }
    }

    private func load(source: ImageOrigin) {
        switch source {
        case .image(let name):
            resolve(.named(name))
        case .asset(let name):
            loadDataAsset(name: name)
        case .resource(let name):
            loadResource(name: name)
        case .bytes(let data):
            resolve(.data(data))
        case .file(let url):
            loadFile(url: url)
        case .url(let url):
            loadURL(url: url)
        }
    }

    private func resolve(_ image: ResolvedImage) {
        rebuild {
            self.resolved = image
            self.loadState = .idle
        }
    }

    private func fail(_ error: Error) {
        rebuild {
            self.loadError = error
            self.loadState = .idle
        }
    }

    private func loadDataAsset(name: String) {
        if let data = NSDataAsset(name: name)?.data {
            resolve(.data(data))
        } else {
            fail(SourceError.notFound("Data asset not found: \(name)"))
        }
    }

    private func loadResource(name: String) {
        let components = (name as NSString)
        let baseName = components.deletingPathExtension
        let ext = components.pathExtension.isEmpty ? nil : components.pathExtension
        if let url = Bundle.main.url(forResource: baseName, withExtension: ext),
           let data = try? Data(contentsOf: url) {
            resolve(.data(data))
        } else {
            fail(SourceError.notFound("Bundle resource not found: \(name)"))
        }
    }

    private func loadFile(url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try Data(contentsOf: url)
                self.resolve(.data(data))
            } catch {
                self.fail(error)
            }
        }
    }

    private func loadURL(url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                self.resolve(.data(data))
            } catch {
                self.fail(error)
            }
        }
    }

    private func sourceEqual(_ a: ImageOrigin, _ b: ImageOrigin) -> Bool {
        switch (a, b) {
        case (.image(let a), .image(let b)): return a == b
        case (.asset(let a), .asset(let b)): return a == b
        case (.resource(let a), .resource(let b)): return a == b
        case (.file(let a), .file(let b)): return a == b
        case (.url(let a), .url(let b)): return a == b
        case (.bytes(let a), .bytes(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - ImageBuilder

/// Builds the image view or a state placeholder based on load state.
public final class ImageBuilder: ViewBuilder<ImageModel> {
    public override func build(context: ViewContext) -> any View {
        let style = model.view.style(model.loadState)

        if model.loadState.contains(.loading) {
            if let stateBuilder = style.state {
                return stateBuilder(model.loadState)
            }
            return Text("")
        }

        if model.loadError != nil {
            if let stateBuilder = style.state {
                return stateBuilder(model.loadState)
            }
            return Text("")
        }

        if let resolved = model.resolved {
            return ImageLeaf(resolved: resolved, style: style)
        }

        return Text("")
    }
}

// MARK: - UIKit

#if canImport(UIKit)
import UIKit

final class UIKitImageRenderer: Renderer {
    private weak var imageView: UIImageView?
    private var view: ImageLeaf

    init(view: ImageLeaf) {
        self.view = view
    }

    func mount() -> PlatformView {
        let imageView = UIImageView()
        imageView.clipsToBounds = true
        self.imageView = imageView
        applyAll(to: imageView)
        return imageView
    }

    func update(from newView: any View) {
        guard let leaf = newView as? ImageLeaf, let imageView else { return }
        view = leaf
        applyAll(to: imageView)
    }

    private func applyAll(to imageView: UIImageView) {
        switch view.resolved {
        case .named(let name):
            imageView.image = UIImage(named: name)
        case .data(let data):
            imageView.image = UIImage(data: data)
        }

        imageView.contentMode = view.style.fit.uiContentMode

        if let size = view.style.size {
            imageView.frame.size = size.cgSize
        }
    }
}

extension ImageFit {
    var uiContentMode: UIView.ContentMode {
        switch self {
        case .cover: return .scaleAspectFill
        case .contain: return .scaleAspectFit
        case .fill: return .scaleToFill
        case .center: return .center
        }
    }
}

#endif
