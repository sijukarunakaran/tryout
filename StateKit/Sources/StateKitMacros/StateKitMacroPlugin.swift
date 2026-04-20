import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StateKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CasePathableMacro.self,
        FeatureMacro.self,
        NonisolatedEquatableMacro.self,
        NestedNonisolatedEquatableMacro.self,
    ]
}
