//
//  UIImageView.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 2. 8. 25.
//

import UIKit
import Combine

//typealias Image = UIImageView

// MARK: - Convenience Initializers
extension UIImageView {
    
    convenience init(_ image: UIImage?) {
        self.init()
        self.image = image
    }
    
    convenience init(systemName: String) {
        self.init()
        self.image = UIImage(systemName: systemName)
    }
    
    convenience init(named: String) {
        self.init()
        self.image = UIImage(named: named)
    }
    
    convenience init(url: URL, placeholder: UIImage? = UIImage(systemName: "photo")) {
        self.init()
        networkImage(url, placeholder: placeholder)
    }
    
    convenience init(url: String, placeholder: UIImage? = UIImage(systemName: "photo")) {
        self.init()
        networkImage(url, placeholder: placeholder)
    }
}

// MARK: - Fluent API
extension UIImageView {
    
    @discardableResult
    func image(_ image: UIImage?) -> Self {
        self.image = image
        return self
    }
    
    @discardableResult
    func systemImage(_ systemName: String) -> Self {
        self.image = UIImage(systemName: systemName)
        return self
    }
    
    @discardableResult
    func bundleImage(_ name: String) -> Self {
        self.image = UIImage(named: name)
        return self
    }
    
    @discardableResult
    func clipsToBounds(_ clips: Bool = true) -> Self {
        clipsToBounds = clips
        return self
    }
    
    @discardableResult
    func tintColor(_ color: UIColor) -> Self {
        tintColor = color
        return self
    }
    
    @discardableResult
    func isUserInteractionEnabled(_ enabled: Bool) -> Self {
        isUserInteractionEnabled = enabled
        return self
    }
    
    @discardableResult
    func isHighlighted(_ highlighted: Bool) -> Self {
        isHighlighted = highlighted
        return self
    }
    
    @discardableResult
    func highlightedImage(_ image: UIImage?) -> Self {
        highlightedImage = image
        return self
    }
    
    @discardableResult
    func preferredSymbolConfiguration(_ configuration: UIImage.SymbolConfiguration?) -> Self {
        preferredSymbolConfiguration = configuration
        return self
    }
    
    @discardableResult
    func adjustsImageSizeForAccessibilityContentSizeCategory(_ adjusts: Bool) -> Self {
        adjustsImageSizeForAccessibilityContentSizeCategory = adjusts
        return self
    }
}

// MARK: - Reactive API
extension UIImageView {
    
    @discardableResult
    func image(_ image: some Publisher<UIImage?, Never>) -> Self {
        bind(image.eraseToAnyPublisher(), to: \UIImageView.image)
        return self
    }
    
    @discardableResult
    func tintColor(_ tintColor: some Publisher<UIColor, Never>) -> Self {
        bind(tintColor.eraseToAnyPublisher(), to: \UIImageView.tintColor)
        return self
    }
    
    @discardableResult
    func contentMode(_ contentMode: some Publisher<UIView.ContentMode, Never>) -> Self {
        bind(contentMode.eraseToAnyPublisher(), to: \UIImageView.contentMode)
        return self
    }
    
    @discardableResult
    func isHighlighted(_ isHighlighted: some Publisher<Bool, Never>) -> Self {
        bind(isHighlighted.eraseToAnyPublisher(), to: \UIImageView.isHighlighted)
        return self
    }
    
    @discardableResult
    func systemImage(_ systemImage: some Publisher<String, Never>) -> Self {
        sink(systemImage.eraseToAnyPublisher()) { [weak self] systemName in
            self?.image = UIImage(systemName: systemName)
        }
        return self
    }
    
    @discardableResult
    func bundleImage(_ bundleImage: some Publisher<String, Never>) -> Self {
        sink(bundleImage.eraseToAnyPublisher()) { [weak self] imageName in
            self?.image = UIImage(named: imageName)
        }
        return self
    }
    
    @discardableResult
    func networkImage(_ networkImage: some Publisher<String?, Never>) -> Self {
        sink(networkImage.eraseToAnyPublisher()) { [weak self] urlString in
            guard let urlString = urlString else { return }
            self?.networkImage(urlString)
        }
        return self
    }
}

// MARK: - Network image
extension UIImageView {
    private static var loadingTaskKey: UInt8 = 0
    
    private var loadingTask: Task<Void, Never>? {
        get {
            objc_getAssociatedObject(self, &Self.loadingTaskKey) as? Task<Void, Never>
        }
        set {
            objc_setAssociatedObject(self, &Self.loadingTaskKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @discardableResult
    func networkImage(
        _ url: URL,
        placeholder: UIImage? = UIImage(systemName: "photo"),
        errorImage: UIImage? = UIImage(systemName: "exclamationmark.triangle")
    ) -> Self {
        // Cancel any existing load
        loadingTask?.cancel()
        
        // Set placeholder immediately
        image = placeholder
        
        // Start loading
        loadingTask = Task { [weak self] in
            do {
                let loadedImage = try await ImageLoader.shared.loadImage(from: url)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    // Add a nice fade transition
                    UIView.transition(
                        with: self!,
                        duration: 0.2,
                        options: .transitionCrossDissolve
                    ) {
                        self?.image = loadedImage
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self?.image = errorImage
                }
            }
        }
        
        return self
    }
    
    @discardableResult
    func networkImage(
        _ urlString: String,
        placeholder: UIImage? = UIImage(systemName: "photo"),
        errorImage: UIImage? = UIImage(systemName: "exclamationmark.triangle")
    ) -> Self {
        guard let url = URL(string: urlString) else {
            image = errorImage
            return self
        }
        
        return networkImage(url, placeholder: placeholder, errorImage: errorImage)
    }
    
    func cancelImageLoad() {
        loadingTask?.cancel()
        loadingTask = nil
    }
}

actor ImageLoader {
    static let shared = ImageLoader()
    
    private var activeRequests: [URL: Task<UIImage?, Error>] = [:]
    
    func loadImage(from url: URL) async throws -> UIImage? {
        // Check if already loading - deduplicate requests
        if let existingTask = activeRequests[url] {
            return try await existingTask.value
        }
        
        // Create new task
        let task = Task<UIImage?, Error> {
            defer { activeRequests.removeValue(forKey: url) }
            
            // Check memory cache first
            if let cached = ImageCache.shared.image(for: url) {
                return cached
            }
            
            // Check disk cache
            if let diskImage = try await ImageDiskCache.shared.image(for: url) {
                ImageCache.shared.store(image: diskImage, for: url)
                return diskImage
            }
            
            // Download from network
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw ImageError.invalidResponse
            }
            
            guard let image = UIImage(data: data) else {
                throw ImageError.invalidImageData
            }
            
            // Cache the result
            ImageCache.shared.store(image: image, for: url)
            Task { await ImageDiskCache.shared.store(data: data, for: url) }
            
            return image
        }
        
        activeRequests[url] = task
        return try await task.value
    }
    
    func cancelLoad(for url: URL) {
        activeRequests[url]?.cancel()
        activeRequests.removeValue(forKey: url)
    }
}

enum ImageError: Error {
    case invalidResponse
    case invalidImageData
    case networkError(Error)
}

final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    
    private let cache = NSCache<NSString, UIImage>()
    private let queue = DispatchQueue(label: "ImageCache", attributes: .concurrent)
    
    private init() {
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
        
        // Clear cache on memory warning
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.cache.removeAllObjects()
        }
    }
    
    func image(for url: URL) -> UIImage? {
        queue.sync {
            cache.object(forKey: url.absoluteString as NSString)
        }
    }
    
    func store(image: UIImage, for url: URL) {
        queue.async(flags: .barrier) {
            let cost = (image.cgImage?.bytesPerRow ?? 0) * (image.cgImage?.height ?? 0)
            self.cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
        }
    }
    
    func removeImage(for url: URL) {
        queue.async(flags: .barrier) {
            self.cache.removeObject(forKey: url.absoluteString as NSString)
        }
    }
    
    func clearCache() {
        queue.async(flags: .barrier) {
            self.cache.removeAllObjects()
        }
    }
}

actor ImageDiskCache {
    static let shared = ImageDiskCache()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let maxCacheSize: Int = 100 * 1024 * 1024 // 100MB
    
    private init() {
        let urls = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = urls[0].appendingPathComponent("ImageCache")
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func cacheKey(for url: URL) -> String {
        return url.absoluteString.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
    }
    
    func image(for url: URL) async throws -> UIImage? {
        let key = cacheKey(for: url)
        let fileURL = cacheDirectory.appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return UIImage(data: data)
    }
    
    func store(data: Data, for url: URL) async {
        do {
            let key = cacheKey(for: url)
            let fileURL = cacheDirectory.appendingPathComponent(key)
            try data.write(to: fileURL)
            
            // Check cache size and cleanup if needed
            await cleanupIfNeeded()
        } catch {
            print("Failed to cache image: \(error)")
        }
    }
    
    private func cleanupIfNeeded() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey])
            
            let filesWithInfo = try files.compactMap { url -> (URL, Int, Date)? in
                let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                guard let size = resources.fileSize,
                      let date = resources.creationDate else { return nil }
                return (url, size, date)
            }
            
            let totalSize = filesWithInfo.reduce(0) { $0 + $1.1 }
            
            if totalSize > maxCacheSize {
                // Delete oldest files first
                let sortedFiles = filesWithInfo.sorted { $0.2 < $1.2 }
                var currentSize = totalSize
                
                for (url, size, _) in sortedFiles {
                    try fileManager.removeItem(at: url)
                    currentSize -= size
                    
                    if currentSize <= maxCacheSize / 2 { // Clean to 50% capacity
                        break
                    }
                }
            }
        } catch {
            print("Cache cleanup failed: \(error)")
        }
    }
    
    func clearCache() async {
        do {
            try fileManager.removeItem(at: cacheDirectory)
            try fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        } catch {
            print("Failed to clear cache: \(error)")
        }
    }
}
