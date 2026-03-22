# LocalDI

`LocalDI` is a small dependency injection library built around three ideas:

- dependencies are keyed by type
- overrides are scoped with `TaskLocal`
- registration boilerplate is generated with macros

It is designed for simple app code and tests where you want:

- ergonomic property-wrapper based access
- scoped dependency overrides
- lightweight dependency clients

## Installation

`LocalDI` is already configured as a local package in this workspace. If you want to use it from another package, add it as a dependency and import `LocalDI`.

## Core Concepts

### 1. `DependencyKey`

Every dependency has a key that provides its fallback value:

```swift
public protocol DependencyKey {
    associatedtype Value
    static var liveValue: Value { get }
}
```

Most of the time you do not write this key manually because the macro system generates it.

### 2. `DependencyValues`

`DependencyValues` stores the current dependency overrides for the active task:

```swift
public struct DependencyValues: @unchecked Sendable
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

## Declaring a Dependency Client

The intended style is:

```swift
import LocalDI

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

It also synthesizes a fileprivate bridge so the `live` property itself can be `private`.

That means this is supported:

```swift
@DependencySource
private static let live = ...
```

and this is also supported:

```swift
@DependencySource
static let live = ...
```

`private` is recommended when you do not need direct access to `live` outside the file.

## Using a Dependency

Inside a feature or model:

```swift
struct FileManagerDemoViewModel {
    @Dependency(FileManagerClient.self) private var fileManager

    func save(_ text: String) throws -> URL {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("localdi-demo")

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

Overrides are applied only within the `operation` scope.

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

## What the Macros Generate

Given:

```swift
@DependencyClient
struct ClockClient {
    var now: @Sendable () -> Date
}

extension ClockClient {
    @DependencySource
    private static let live = Self(
        now: Date.init
    )
}
```

the library conceptually generates code similar to:

```swift
fileprivate enum ClockClientDependency: DependencyKey {
    fileprivate static var liveValue: ClockClient {
        ClockClient.__dependencySource
    }
}

extension ClockClient: DependencyProviding {
    fileprivate typealias Dependency = ClockClientDependency
}

extension ClockClient {
    fileprivate static var __dependencySource: Self {
        live
    }
}
```

The exact generated code may differ, but this is the model to keep in mind.

## Design Tradeoffs

### Eager capture in `@Dependency`

`@Dependency` resolves the dependency in its initializer and stores the value. This improves test ergonomics, but it also means:

- dependency changes after object creation are not observed by that object
- overrides should be in place before creating the dependent object

This is an intentional design choice in the current version.

### `DependencySource` naming convention

`@DependencySource` currently requires the source property to be named `live`. This keeps the macro simple and predictable.

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
```

## Recommendations

- Prefer `@DependencyClient` on the client type.
- Prefer `@DependencySource private static let live` in an extension.
- Prefer `values[MyClient.self]` over `values[MyClient.Dependency.self]`.
- Set up overrides before creating the object that reads `@Dependency`.
- Use small client structs with closure members for easy testing.

## Current Example in This Workspace

See:

- `Sources/LocalDI/LocalDI.swift`
- `Sources/LocalDIMacros/DependencyRegistrationMacro.swift`
- `Tests/LocalDITests/LocalDITests.swift`

And the app-side usage:

- `../Layout/LocalDI+FileManager.swift`
- `../Layout/FileManagerDemoView.swift`
- `../LayoutTests/FileManagerDemoViewModelTests.swift`
