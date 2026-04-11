//
//  InstanceService.swift
//  UIKitPlayground
//
//  Created by Elisey Ozerov on 7. 8. 25.
//

import Foundation

protocol Factory<T> {
    associatedtype T
    var value: T { get }
    init(factory: @escaping () -> T)
}

final class LazySingleton<T>: Factory {
    typealias Value = T
    private let factory: () -> T
    private var instance: T?
    
    init(factory: @escaping () -> T) {
        self.factory = factory
    }
    
    var value: T {
        if let instance = instance {
            return instance
        }
        self.instance = factory()
        return instance!
    }
}

final class WeakSingleton<T: AnyObject>: Factory {
    typealias Value = T
    private let factory: () -> T
    private weak var instance: T?
    
    init(factory: @escaping () -> T) {
        self.factory = factory
    }
    
    var value: T {
        if let instance = instance {
            return instance
        }
        self.instance = factory()
        return instance!
    }
}

final class Singleton<T>: Factory {
    typealias Value = T
    private let instance: T
    
    init(factory: @escaping () -> T) {
        self.instance = factory()
    }
    
    var value: T { instance }
}

final class Transient<T>: Factory {
    typealias Value = T
    private let factory: () -> T
    
    init(factory: @escaping () -> T) {
        self.factory = factory
    }
    
    var value: T { factory() }
}

protocol InstanceService {
    func instance<T>(_ type: T.Type) throws -> T
    /// Registers a factory that will be return a new object on each injection
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
    /// Registers a lazy singleton
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T)
}

final class DI: InstanceService, @unchecked Sendable {
    static let shared = DI()
    
    private var transientFactories: [ObjectIdentifier: () -> Any] = [:]
    private var singletonFactories: [ObjectIdentifier: () -> Any] = [:]
    private var singletonInstances: [ObjectIdentifier: Any] = [:]
    
    // Thread-safe access using NSLock
    private let transientLock = NSLock()
    private let singletonLock = NSLock()
    
    private init() {}
    
    func instance<T>(_ type: T.Type) throws -> T {
        let identifier = ObjectIdentifier(type)
        
        // Check singletons first (they take precedence)
        if let singleton = getSingleton(identifier: identifier, type: type) {
            return singleton
        }
        
        // Check transient factories
        if let transient = getTransient(identifier: identifier, type: type) {
            return transient
        }
        
        throw DependencyError("No registration found for \(type). Register it or make it conform to AutoInjectable.")
    }
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let identifier = ObjectIdentifier(type)
        
        transientLock.lock()
        defer { transientLock.unlock() }
        transientFactories[identifier] = factory
    }
    
    func registerSingleton<T>(_ type: T.Type, factory: @escaping () -> T) {
        let identifier = ObjectIdentifier(type)
        
        singletonLock.lock()
        defer { singletonLock.unlock() }
        singletonFactories[identifier] = factory
    }
    
    // MARK: - Private Thread-Safe Helpers
    
    private func getSingleton<T>(identifier: ObjectIdentifier, type: T.Type) -> T? {
        singletonLock.lock()
        defer { singletonLock.unlock() }
        
        // Check if instance already exists
        if let existing = singletonInstances[identifier] as? T {
            return existing
        }
        
        // Create new instance if factory exists
        guard let factory = singletonFactories[identifier] else {
            return nil
        }
        
        let instance = factory() as! T
        singletonInstances[identifier] = instance
        return instance
    }
    
    private func getTransient<T>(identifier: ObjectIdentifier, type: T.Type) -> T? {
        transientLock.lock()
        defer { transientLock.unlock() }
        
        guard let factory = transientFactories[identifier] else {
            return nil
        }
        return factory() as? T
    }
    
    // MARK: - Utility Methods
    
    func isRegistered<T>(_ type: T.Type) -> Bool {
        let identifier = ObjectIdentifier(type)
        
        singletonLock.lock()
        let hasSingleton = singletonFactories[identifier] != nil
        singletonLock.unlock()
        
        transientLock.lock()
        let hasTransient = transientFactories[identifier] != nil
        transientLock.unlock()
        
        return hasSingleton || hasTransient
    }
    
    func clearSingletons() {
        singletonLock.lock()
        defer { singletonLock.unlock() }
        singletonInstances.removeAll()
    }
}

struct DependencyError: Error, LocalizedError {
    let message: String?
    
    init(_ message: String? = nil) {
        self.message = message
    }
    
    var errorDescription: String? {
        return message ?? "Dependency injection error"
    }
}

@propertyWrapper
struct Inject<T> {
    private class InstanceHolder {
        var instance: T?
        let lock = NSLock()
    }
    
    private let holder = InstanceHolder()
    
    // we need to subscribe to changes of instance in the container
    // 
    
    var wrappedValue: T {
        holder.lock.lock()
        defer { holder.lock.unlock() }
        
        if let instance = holder.instance {
            return instance
        }
        
        do {
            let newInstance = try DI.shared.instance(T.self)
            holder.instance = newInstance
            return newInstance
        } catch {
            fatalError("Failed to inject \(T.self): \(error)")
        }
    }
    
    init() {}
}

// MARK: - Example Usage
protocol Dependency {}

struct Dependent {
    @Inject private var dependency: Dependency
    
    func useDependency() {
        // dependency is thread-safely injected
        print("Using dependency: \(dependency)")
    }
}
