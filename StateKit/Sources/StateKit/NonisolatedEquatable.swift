@attached(extension, conformances: Equatable, names: named(==))
public macro NonisolatedEquatable() = #externalMacro(
    module: "StateKitMacros",
    type: "NonisolatedEquatableMacro"
)
