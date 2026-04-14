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
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return try expansion(for: structDecl, type: type)
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try expansion(for: enumDecl, type: type)
        }

        throw MacroError.message("@NonisolatedEquatable can only be applied to a struct or payload-free enum.")
    }

    private static func expansion(
        for structDecl: StructDeclSyntax,
        type: some TypeSyntaxProtocol
    ) throws -> [ExtensionDeclSyntax] {
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
        let comparisons = makePropertyComparisons(for: properties)
        let accessModifier = MacroSupport.accessModifier(from: structDecl.modifiers).map { "\($0) " } ?? ""
        return [
            try makeExtension(
                type: type,
                accessModifier: accessModifier,
                comparisons: comparisons
            )
        ]
    }

    private static func expansion(
        for enumDecl: EnumDeclSyntax,
        type: some TypeSyntaxProtocol
    ) throws -> [ExtensionDeclSyntax] {
        let cases = enumDecl.memberBlock.members.compactMap { member -> String? in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return nil
            }
            guard caseDecl.elements.allSatisfy({ $0.parameterClause == nil }) else {
                return nil
            }
            return caseDecl.elements.map(\.name.text).joined(separator: "\u{0}")
        }
        .flatMap { $0.split(separator: "\u{0}").map(String.init) }

        guard cases.isEmpty == false else {
            throw MacroError.message("@NonisolatedEquatable requires at least one payload-free enum case.")
        }

        let hasPayloadCase = enumDecl.memberBlock.members.contains { member in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return false
            }
            return caseDecl.elements.contains { $0.parameterClause != nil }
        }
        guard hasPayloadCase == false else {
            throw MacroError.message("@NonisolatedEquatable does not support enums with associated values.")
        }

        let comparisons = """
        switch (lhs, rhs) {
        \(cases.map { "        case (.\($0), .\($0)):\n            true" }.joined(separator: "\n"))
        default:
            false
        }
        """

        let accessModifier = MacroSupport.accessModifier(from: enumDecl.modifiers).map { "\($0) " } ?? ""
        return [
            try makeExtension(
                type: type,
                accessModifier: accessModifier,
                comparisons: comparisons
            )
        ]
    }

    private static func makePropertyComparisons(for properties: [String]) -> String {
        if properties.isEmpty {
            return "true"
        }
        return properties.enumerated().map { index, property in
            let prefix = index == 0 ? "" : "            && "
            return "\(prefix)lhs.\(property) == rhs.\(property)"
        }
        .joined(separator: "\n")
    }

    private static func makeExtension(
        type: some TypeSyntaxProtocol,
        accessModifier: String,
        comparisons: String
    ) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax(
            """
            \(raw: accessModifier)extension \(type): Equatable {
                nonisolated \(raw: accessModifier)static func == (lhs: Self, rhs: Self) -> Bool {
                    \(raw: comparisons)
                }
            }
            """
        )
    }
}
