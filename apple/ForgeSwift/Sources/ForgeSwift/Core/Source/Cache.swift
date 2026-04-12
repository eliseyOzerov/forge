import Foundation

/// In-memory cache backed by NSCache. Evicts under memory pressure.
public final class MemoryCache: @unchecked Sendable {
    private let storage = NSCache<NSString, CacheBox>()

    public static let shared = MemoryCache()

    public init(countLimit: Int = 200) {
        storage.countLimit = countLimit
    }

    public func get<T>(_ key: String) -> T? {
        (storage.object(forKey: key as NSString))?.value as? T
    }

    public func set<T>(_ key: String, value: T) {
        storage.setObject(CacheBox(value), forKey: key as NSString)
    }

    public func remove(_ key: String) {
        storage.removeObject(forKey: key as NSString)
    }

    public func clear() {
        storage.removeAllObjects()
    }
}

/// Disk cache in the Caches directory. Stores raw Data keyed by
/// a hashed filename. Survives app restarts, cleared by OS under
/// storage pressure.
public final class DiskCache: @unchecked Sendable {
    private let directory: URL
    private let queue = DispatchQueue(label: "forge.diskcache", attributes: .concurrent)

    public static let shared = DiskCache()

    public init(name: String = "forge") {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.directory = caches.appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func get(_ key: String) -> Data? {
        queue.sync { try? Data(contentsOf: fileURL(for: key)) }
    }

    public func set(_ key: String, data: Data) {
        queue.async(flags: .barrier) {
            try? data.write(to: self.fileURL(for: key))
        }
    }

    public func remove(_ key: String) {
        queue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: self.fileURL(for: key))
        }
    }

    public func clear() {
        queue.async(flags: .barrier) {
            try? FileManager.default.removeItem(at: self.directory)
            try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        }
    }

    private func fileURL(for key: String) -> URL {
        let hash = key.utf8.reduce(into: UInt64(5381)) { $0 = $0 &* 33 &+ UInt64($1) }
        return directory.appendingPathComponent(String(hash, radix: 16))
    }
}

/// Type-erased box for NSCache (requires class type).
private final class CacheBox: @unchecked Sendable {
    let value: Any
    init(_ value: Any) { self.value = value }
}
