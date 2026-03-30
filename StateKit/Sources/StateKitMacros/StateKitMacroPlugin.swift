import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct StateKitMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CasePathableMacro.self,
    ]
}
