import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct SpliceMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DependencyClientMacro.self,
        DependencySourceMacro.self,
        DependencyTestSourceMacro.self,
    ]
}
