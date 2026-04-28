// Macros for registering dependency clients, live values, and test values.

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

@attached(peer, names: arbitrary)
public macro DependencyTestSource() = #externalMacro(
    module: "LocalDIMacros",
    type: "DependencyTestSourceMacro"
)
