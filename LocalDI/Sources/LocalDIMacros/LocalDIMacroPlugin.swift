import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct LocalDIMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DependencyClientMacro.self,
        DependencySourceMacro.self,
        DependencyTestSourceMacro.self,
    ]
}
