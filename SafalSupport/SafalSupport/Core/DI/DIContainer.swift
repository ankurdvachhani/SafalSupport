import Foundation

@propertyWrapper
struct Inject<T> {
    let wrappedValue: T
    
    init() {
        self.wrappedValue = DIContainer.shared.resolve()
    }
}

@propertyWrapper
struct Provider<T> {
    let wrappedValue: () -> T
    
    init() {
        self.wrappedValue = { DIContainer.shared.resolve() }
    }
}

final class DIContainer {
    static let shared = DIContainer()
    
    private var dependencies = [String: Any]()
    private var factories = [String: () -> Any]()
    
    private init() {}
    
    func register<T>(_ dependency: T) {
        let key = String(describing: T.self)
        dependencies[key] = dependency
    }
    
    func register<T>(_ factory: @escaping () -> T) {
        let key = String(describing: T.self)
        factories[key] = factory
    }
    
    func resolve<T>() -> T {
        let key = String(describing: T.self)
        
        if let dependency = dependencies[key] as? T {
            return dependency
        }
        
        if let factory = factories[key] as? () -> T {
            return factory()
        }
        
        fatalError("No dependency found for \(key)")
    }
} 