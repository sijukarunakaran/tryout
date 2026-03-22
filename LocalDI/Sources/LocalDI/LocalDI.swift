import Foundation

public protocol DependencyKey {
    associatedtype Value
    static var liveValue: Value { get }
}

public protocol DependencyProviding {
    associatedtype Dependency: DependencyKey where Dependency.Value == Self
}

@attached(peer, names: suffixed(Dependency))
@attached(extension, conformances: DependencyProviding, names: named(Dependency))
public macro DependencyClient() = #externalMacro(
    module: "LocalDIMacros",
    type: "DependencyClientMacro"
)

@attached(peer, names: arbitrary)
public macro DependencySource() = #externalMacro(
    module: "LocalDIMacros",
    type: "DependencySourceMacro"
)

public struct DependencyValues: @unchecked Sendable {
    private var storage: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<Client: DependencyProviding>(_ client: Client.Type) -> Client {
        get {
            self[Client.Dependency.self]
        }
        set {
            self[Client.Dependency.self] = newValue
        }
    }

    public subscript<K: DependencyKey>(key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            return K.liveValue
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

public enum Dependencies {
    @TaskLocal public static var values = DependencyValues()
}

@propertyWrapper
public struct Dependency<Value> {
    private let value: Value

    public init(_ keyPath: WritableKeyPath<DependencyValues, Value>) {
        self.value = Dependencies.values[keyPath: keyPath]
    }

    public init<K: DependencyKey>(_ key: K.Type) where K.Value == Value {
        self.value = Dependencies.values[key]
    }

    public init(_ client: Value.Type) where Value: DependencyProviding {
        self.value = Dependencies.values[Value.Dependency.self]
    }

    public var wrappedValue: Value {
        value
    }
}

public func withDependencies<R>(
    _ update: (inout DependencyValues) -> Void,
    operation: () throws -> R
) rethrows -> R {
    var copy = Dependencies.values
    update(&copy)
    return try Dependencies.$values.withValue(copy) {
        try operation()
    }
}

public func withDependencies<R>(
    _ update: (inout DependencyValues) -> Void,
    operation: () async throws -> R
) async rethrows -> R {
    var copy = Dependencies.values
    update(&copy)
    return try await Dependencies.$values.withValue(copy) {
        try await operation()
    }
}
