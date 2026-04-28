// Property wrapper for reading a dependency, and the scoping helper for overriding values.

@propertyWrapper
public struct Dependency<Value> {
    private let value: Value

    public init<K: DependencyKey>(_ key: K.Type, file: StaticString = #fileID, line: UInt = #line) where K.Value == Value {
        if _isTesting && !Dependencies.values.hasValue(for: key) {
            fatalError(
                "\(K.self) does not define a testValue. " +
                "Apply @DependencyTestSource to 'static let testLive' in an extension, " +
                "or use withDependencies(_:operation:) to supply a test double.",
                file: file, line: line
            )
        }
        self.value = Dependencies.values[key]
    }

    public init(_ client: Value.Type, file: StaticString = #fileID, line: UInt = #line) where Value: DependencyProviding {
        if _isTesting && !Dependencies.values.hasValue(for: Value.Dependency.self) {
            fatalError(
                "\(Value.Dependency.self) does not define a testValue. " +
                "Apply @DependencyTestSource to 'static let testLive' in an extension of \(Value.self), " +
                "or use withDependencies(_:operation:) to supply a test double.",
                file: file, line: line
            )
        }
        self.value = Dependencies.values[client]
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
