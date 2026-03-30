@attached(member, names: arbitrary)
public macro CasePathable() = #externalMacro(
    module: "StateKitMacros",
    type: "CasePathableMacro"
)
