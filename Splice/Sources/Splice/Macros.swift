// Macros for registering dependency clients, live values, and test values.

@attached(peer, names: suffixed(Dependency))
@attached(extension, conformances: DependencyProviding, names: named(Dependency))
public macro DependencyClient() = #externalMacro(
    module: "SpliceMacros",
    type: "DependencyClientMacro"
)

@attached(peer, names: arbitrary)
public macro DependencySource() = #externalMacro(
    module: "SpliceMacros",
    type: "DependencySourceMacro"
)

@attached(peer, names: arbitrary)
public macro DependencyTestSource() = #externalMacro(
    module: "SpliceMacros",
    type: "DependencyTestSourceMacro"
)
