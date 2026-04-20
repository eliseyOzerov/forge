#if canImport(UIKit)
import UIKit
#endif
import Foundation

/// State of an async source.
public enum SourceState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)

    public var value: T? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

/// An async data source that produces a value of type T.
/// Handles loading, parsing, caching, and error states.
@MainActor
public protocol Source<T>: AnyObject {
    associatedtype T
    var state: SourceState<T> { get }
    func load() async
}

// MARK: - AssetSource

/// Loads data from the app bundle (NSDataAsset or file resource),
/// parses it with the provided closure.
@MainActor
public final class AssetSource<T>: Source {
    public private(set) var state: SourceState<T> = .idle
    private let name: String
    private let ext: String?
    private let parse: (Data) throws -> T
    private let cache: MemoryCache

    public init(_ name: String, extension ext: String? = nil, cache: MemoryCache = .shared, parse: @escaping (Data) throws -> T) {
        self.name = name
        self.ext = ext
        self.parse = parse
        self.cache = cache
    }

    public func load() async {
        let key = "asset:\(name).\(ext ?? "")"
        if let cached: T = cache.get(key) {
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            let data = try loadFromBundle()
            let result = try parse(data)
            cache.set(key, value: result)
            state = .loaded(result)
        } catch {
            state = .error(error)
        }
    }

    private func loadFromBundle() throws -> Data {
        #if canImport(UIKit)
        if let asset = NSDataAsset(name: name) { return asset.data }
        #endif
        if let url = Bundle.main.url(forResource: name, withExtension: ext) {
            return try Data(contentsOf: url)
        }
        throw SourceError.notFound("Asset '\(name)' not found in bundle")
    }
}

// MARK: - FileSource

/// Loads data from a file URL, parses with the provided closure.
@MainActor
public final class FileSource<T>: Source {
    public private(set) var state: SourceState<T> = .idle
    private let url: URL
    private let parse: (Data) throws -> T
    private let cache: MemoryCache

    public init(_ url: URL, cache: MemoryCache = .shared, parse: @escaping (Data) throws -> T) {
        self.url = url
        self.parse = parse
        self.cache = cache
    }

    public func load() async {
        let key = "file:\(url.absoluteString)"
        if let cached: T = cache.get(key) {
            state = .loaded(cached)
            return
        }

        state = .loading
        do {
            let data = try Data(contentsOf: url)
            let result = try parse(data)
            cache.set(key, value: result)
            state = .loaded(result)
        } catch {
            state = .error(error)
        }
    }
}

// MARK: - URLSource

/// Loads data from a remote URL. Checks disk cache before
/// downloading, stores downloaded data to disk, parsed result
/// to memory.
@MainActor
public final class URLSource<T>: Source {
    public private(set) var state: SourceState<T> = .idle
    private let url: URL
    private let parse: (Data) throws -> T
    private let memoryCache: MemoryCache
    private let diskCache: DiskCache

    public init(_ url: URL, memoryCache: MemoryCache = .shared, diskCache: DiskCache = .shared, parse: @escaping (Data) throws -> T) {
        self.url = url
        self.parse = parse
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }

    public func load() async {
        let key = url.absoluteString

        if let cached: T = memoryCache.get(key) {
            state = .loaded(cached)
            return
        }

        if let diskData = diskCache.get(key) {
            do {
                let result = try parse(diskData)
                memoryCache.set(key, value: result)
                state = .loaded(result)
                return
            } catch {}
        }

        state = .loading
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            diskCache.set(key, data: data)
            let result = try parse(data)
            memoryCache.set(key, value: result)
            state = .loaded(result)
        } catch {
            state = .error(error)
        }
    }
}

// MARK: - Error

public enum SourceError: Error, LocalizedError {
    case notFound(String)

    public var errorDescription: String? {
        switch self {
        case .notFound(let msg): msg
        }
    }
}
