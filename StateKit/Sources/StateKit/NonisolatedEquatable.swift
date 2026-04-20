@attached(memberAttribute)
@attached(extension, conformances: Equatable, names: named(==))
public macro NonisolatedEquatable() = #externalMacro(
    module: "StateKitMacros",
    type: "NonisolatedEquatableMacro"
)

@attached(memberAttribute)
@attached(extension, conformances: Equatable, names: named(==))
public macro _NestedNonisolatedEquatable() = #externalMacro(
    module: "StateKitMacros",
    type: "NestedNonisolatedEquatableMacro"
)
