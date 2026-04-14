@attached(extension, conformances: FeatureDomain)
public macro Feature() = #externalMacro(
    module: "StateKitMacros",
    type: "FeatureMacro"
)
