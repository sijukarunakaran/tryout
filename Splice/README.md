# Splice

`Splice` is a small dependency injection library built around three ideas:

- dependencies are keyed by type
- overrides are scoped with `TaskLocal`
- registration boilerplate is generated with macros

It adds first-class test-safety: dependencies that have no test double registered will crash at the call site instead of silently falling back to live values.

It is designed for simple app code and tests where you want:

- ergonomic property-wrapper based access
- scoped dependency overrides with `TaskLocal` isolation
- a hard failure when a test accesses an unregistered dependency
- lightweight dependency clients

## Installation

`Splice` is already configured as a local package in this workspace. If you want to use it from another package, add it as a dependency and import `Splice`.

## Core Concepts

### 1. `DependencyKey`

Every dependency has a key that provides its fallback values:

```swift
public protocol DependencyKey {
    associatedtype Value: Sendable
    static var liveValue: Value { get }
    static var testValue: Value? { get }   // nil by default
}
```

Most of the time you do not write this key manually because the macro system generates it.

`testValue` is returned inside the test process when no explicit override is in place.  
If `testValue` is `nil` and no override exists, accessing the dependency in a test crashes with a descriptive message.

### 2. `DependencyValues`

`DependencyValues` stores the current dependency overrides for the active task:

```swift
public struct DependencyValues: Sendable
```

It supports two subscripts:

```swift
values[MyClient.self]
values[MyClient.Dependency.self]
```

The client-based subscript is the preferred one for app code and tests.

### 3. `@Dependency`

Use `@Dependency` to read a dependency inside a type:

```swift
struct FeatureModel {
    @Dependency(FileManagerClient.self) var fileManager
}
```

Important: `@Dependency` captures the current dependency value when the containing type is initialized. That means:

- if you create an object inside `withDependencies`, the dependency is captured there
- later method calls can happen outside `withDependencies`
- this is useful for setup-style tests

In tests, if the key has no `testValue` and no explicit override is in place, the initializer will call `fatalError` with a message pointing you to `@DependencyTestSource`.

## Declaring a Dependency Client

The intended style is:

```swift
import Splice

@DependencyClient
struct FileManagerClient: Sendable {
    var fileExists: @Sendable (URL) -> Bool
    var createDirectory: @Sendable (URL, Bool) throws -> Void
    var write: @Sendable (Data, URL) throws -> Void
    var read: @Sendable (URL) throws -> Data
}
```

`@DependencyClient` generates:

- a dependency key named `<TypeName>Dependency`
- conformance to `DependencyProviding`
- the nested `Dependency` typealias used by the library internally

## Defining the Live Value

Define the live source in an extension using `@DependencySource`:

```swift
extension FileManagerClient {
    @DependencySource
    private static let live = Self(
        fileExists: { FileManager.default.fileExists(atPath: $0.path) },
        createDirectory: { url, intermediate in
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: intermediate
            )
        },
        write: { data, url in
            try data.write(to: url)
        },
        read: { url in
            try Data(contentsOf: url)
        }
    )
}
```

`@DependencySource` currently expects:

- a `static` property
- named `live`

It synthesizes a fileprivate bridge so the `live` property itself can be `private`.

## Defining the Test Value

Define a test double in a separate extension using `@DependencyTestSource`:

```swift
extension FileManagerClient {
    @DependencyTestSource
    private static let testLive = Self(
        fileExists: { _ in false },
        createDirectory: { _, _ in },
        write: { _, _ in },
        read: { _ in Data() }
    )
}
```

`@DependencyTestSource` currently expects:

- a `static` property
- named `testLive`

When a test runs and no explicit `withDependencies` override is in place, `DependencyValues` returns this value automatically. If `testLive` is not defined and there is no override, `@Dependency` crashes with a diagnostic message.

## Using a Dependency

Inside a feature or model:

```swift
struct FileManagerDemoViewModel {
    @Dependency(FileManagerClient.self) private var fileManager

    func save(_ text: String) throws -> URL {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("splice-demo")

        if !fileManager.fileExists(folderURL) {
            try fileManager.createDirectory(folderURL, true)
        }

        let fileURL = folderURL.appendingPathComponent("note.txt")
        try fileManager.write(Data(text.utf8), fileURL)
        return fileURL
    }
}
```

## Overriding Dependencies

Use `withDependencies` to override values in a scoped way:

```swift
let result = withDependencies(
    { values in
        values[FileManagerClient.self] = .init(
            fileExists: { _ in true },
            createDirectory: { _, _ in },
            write: { _, _ in },
            read: { _ in Data() }
        )
    },
    operation: {
        try FileManagerDemoViewModel().save("Hello")
    }
)
```

There are sync and async variants:

```swift
withDependencies(_:operation:)
await withDependencies(_:operation:)
```

Overrides are applied only within the `operation` scope and are isolated per task, so concurrent tasks with different overrides do not bleed into each other.

## Test Ergonomics

Because `@Dependency` captures values at initialization time, you can create a system under test once inside `withDependencies` and use it afterward:

```swift
func makeViewModel(fileManager: FileManagerClient) -> FileManagerDemoViewModel {
    withDependencies(
        { values in
            values[FileManagerClient.self] = fileManager
        },
        operation: {
            FileManagerDemoViewModel()
        }
    )
}
```

Then your tests can do:

```swift
let viewModel = makeViewModel(fileManager: mock)
let url = try viewModel.save("Hello")
```

without wrapping every assertion in another `withDependencies` block.

When `@DependencyTestSource` is used, the test double is available globally inside the test process with no setup at all:

```swift
@Test func clockTestValueIsUsed() {
    // testValue is active in the test process — no withDependencies needed.
    #expect(NowReader().read() == clockTestDate)
}
```

## What the Macros Generate

Given:

```swift
@DependencyClient
struct ClockClient: Sendable {
    var now: @Sendable () -> Date
}

extension ClockClient {
    @DependencySource
    private static let live = Self(now: Date.init)
}

extension ClockClient {
    @DependencyTestSource
    private static let testLive = Self(now: { fixedDate })
}
```

the library conceptually generates code similar to:

```swift
fileprivate enum ClockClientDependency: DependencyKey {
    fileprivate static var liveValue: ClockClient { ClockClient.__dependencySource }
    fileprivate static var testValue: ClockClient? { ClockClient.__dependencyTestSource }
}

extension ClockClient: DependencyProviding {
    fileprivate typealias Dependency = ClockClientDependency
}

extension ClockClient {
    fileprivate static var __dependencySource: Self { live }
    fileprivate static var __dependencyTestSource: Self { testLive }
}
```

The exact generated code may differ, but this is the model to keep in mind.

## Design Tradeoffs

### Eager capture in `@Dependency`

`@Dependency` resolves the dependency in its initializer and stores the value. This improves test ergonomics, but it also means:

- dependency changes after object creation are not observed by that object
- overrides should be in place before creating the dependent object

This is an intentional design choice.

### Crash on missing test double

`Splice` crashes when a test accesses a dependency that has neither a `testValue` nor an explicit `withDependencies` override. This is intentional: it surfaces missing test doubles at the call site rather than letting live code run silently in tests.

### `DependencySource` and `DependencyTestSource` naming convention

Both macros currently require a fixed property name (`live` and `testLive` respectively). This keeps the macros simple and predictable.

### Macro-generated internals

The macros generate support types and bridge accessors. Those are implementation details and should not be relied on directly.

## API Summary

Main public API:

```swift
public protocol DependencyKey
public protocol DependencyProviding
public struct DependencyValues
public enum Dependencies
public struct Dependency<Value>
public func withDependencies<R>(_:operation:) rethrows -> R
public func withDependencies<R>(_:operation:) async rethrows -> R
public macro DependencyClient()
public macro DependencySource()
public macro DependencyTestSource()
```

## Recommendations

- Prefer `@DependencyClient` on the client type.
- Prefer `@DependencySource private static let live` in an extension.
- Prefer `@DependencyTestSource private static let testLive` in a separate extension.
- Prefer `values[MyClient.self]` over `values[MyClient.Dependency.self]`.
- Set up overrides before creating the object that reads `@Dependency`.
- Use small client structs with closure members for easy testing.
- Avoid `Task.detached` inside `withDependencies` — detached tasks do not inherit task-local values.

## Current Example in This Workspace

See:

- `Sources/Splice/DependencyKey.swift`
- `Sources/Splice/DependencyValues.swift`
- `Sources/Splice/Dependency.swift`
- `Sources/Splice/Macros.swift`
- `Tests/SpliceTests/SpliceTests.swift`

And the app-side usage:

- `../Layout/FileManagerDemoView.swift`
- `../LayoutTests/FileManagerDemoViewModelTests.swift`
