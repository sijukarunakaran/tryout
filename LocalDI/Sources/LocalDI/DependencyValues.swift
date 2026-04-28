// Storage for the current set of dependency values, scoped via TaskLocal.

public struct DependencyValues: Sendable {
    private var storage: [ObjectIdentifier: any Sendable] = [:]

    public init() {}

    public subscript<Client: DependencyProviding>(_ client: Client.Type) -> Client {
        get { self[Client.Dependency.self] }
        set { self[Client.Dependency.self] = newValue }
    }

    public subscript<K: DependencyKey>(_ key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value { return value }
            return _isTesting ? (K.testValue ?? K.liveValue) : K.liveValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }

    /// Returns `true` when the dependency has either an explicit override in storage
    /// or a defined `testValue`. Used by `@Dependency` init to decide whether to crash.
    func hasValue<K: DependencyKey>(for key: K.Type) -> Bool {
        storage[ObjectIdentifier(key)] != nil || K.testValue != nil
    }
}

public enum Dependencies {
    @TaskLocal public static var values = DependencyValues()
}
