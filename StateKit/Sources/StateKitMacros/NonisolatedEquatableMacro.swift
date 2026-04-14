import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct NonisolatedEquatableMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            throw MacroError.message("@NonisolatedEquatable can only be applied to a struct.")
        }

        let properties = structDecl.memberBlock.members.compactMap { member -> String? in
            guard
                let variable = member.decl.as(VariableDeclSyntax.self),
                variable.bindings.count == 1,
                let binding = variable.bindings.first,
                binding.accessorBlock == nil,
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                return nil
            }

            return identifier.identifier.text
        }

        let comparisons: String
        if properties.isEmpty {
            comparisons = "true"
        } else {
            comparisons = properties.enumerated().map { index, property in
                let prefix = index == 0 ? "" : "            && "
                return "\(prefix)lhs.\(property) == rhs.\(property)"
            }
            .joined(separator: "\n")
        }

        let accessModifier = MacroSupport.accessModifier(from: structDecl.modifiers).map { "\($0) " } ?? ""

        return [
            try ExtensionDeclSyntax(
                """
                \(raw: accessModifier)extension \(type): Equatable {
                    nonisolated \(raw: accessModifier)static func == (lhs: Self, rhs: Self) -> Bool {
                        \(raw: comparisons)
                    }
                }
                """
            )
        ]
    }
}
