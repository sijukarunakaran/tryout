import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct NonisolatedEquatableMacro: ExtensionMacro, MemberAttributeMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        try NestedNonisolatedEquatableMacro.memberAttributeExpansion(
            attachedTo: declaration,
            providingAttributesFor: member
        )
    }

    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try NonisolatedEquatableMacroSupport.extensionExpansion(
            attachedTo: declaration,
            type: type
        )
    }

}

struct NestedNonisolatedEquatableMacro: ExtensionMacro, MemberAttributeMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        try memberAttributeExpansion(
            attachedTo: declaration,
            providingAttributesFor: member
        )
    }

    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        try NonisolatedEquatableMacroSupport.extensionExpansion(
            attachedTo: declaration,
            type: type
        )
    }

    fileprivate static func memberAttributeExpansion(
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol
    ) throws -> [AttributeSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }
        guard NonisolatedEquatableMacroSupport.supportsNestedAnnotation(member) else {
            return []
        }
        guard
            NonisolatedEquatableMacroSupport.hasAttribute(
                NonisolatedEquatableMacroSupport.attributes(of: member),
                named: "NonisolatedEquatable"
            ) == false,
            NonisolatedEquatableMacroSupport.hasAttribute(
                NonisolatedEquatableMacroSupport.attributes(of: member),
                named: "_NestedNonisolatedEquatable"
            ) == false
        else {
            return []
        }

        return [
            AttributeSyntax(
                attributeName: IdentifierTypeSyntax(name: .identifier("_NestedNonisolatedEquatable"))
            )
        ]
    }
}

private enum NonisolatedEquatableMacroSupport {
    static func extensionExpansion(
        attachedTo declaration: some DeclGroupSyntax,
        type: some TypeSyntaxProtocol
    ) throws -> [ExtensionDeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return [try makeStructExtension(type: type, structDecl: structDecl)]
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return try [makeEnumExtension(type: type, enumDecl: enumDecl)]
        }

        throw MacroError.message("@NonisolatedEquatable can only be applied to a struct or payload-free enum.")
    }

    static func makeStructExtension(
        type: some TypeSyntaxProtocol,
        structDecl: StructDeclSyntax
    ) throws -> ExtensionDeclSyntax {
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
        return try makeExtension(
            typeName: type.trimmedDescription,
            accessModifier: accessModifier,
            comparisons: comparisons
        )
    }

    static func makeEnumExtension(
        type: some TypeSyntaxProtocol,
        enumDecl: EnumDeclSyntax
    ) throws -> ExtensionDeclSyntax {
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
        return try makeExtension(
            typeName: type.trimmedDescription,
            accessModifier: accessModifier,
            comparisons: comparisons
        )
    }

    static func makePropertyComparisons(for properties: [String]) -> String {
        if properties.isEmpty {
            return "true"
        }
        return properties.enumerated().map { index, property in
            let prefix = index == 0 ? "" : "            && "
            return "\(prefix)lhs.\(property) == rhs.\(property)"
        }
        .joined(separator: "\n")
    }

    static func makeExtension(
        typeName: String,
        accessModifier: String,
        comparisons: String
    ) throws -> ExtensionDeclSyntax {
        try ExtensionDeclSyntax(
            """
            \(raw: accessModifier)extension \(raw: typeName): Equatable {
                nonisolated \(raw: accessModifier)static func == (lhs: Self, rhs: Self) -> Bool {
                    \(raw: comparisons)
                }
            }
            """
        )
    }

    static func hasAttribute(_ attributes: AttributeListSyntax?, named name: String) -> Bool {
        attributes?.contains(where: { element in
            guard case let .attribute(attribute) = element else { return false }
            return attribute.attributeName.trimmedDescription == name
        }) == true
    }

    static func supportsNestedAnnotation(_ member: some DeclSyntaxProtocol) -> Bool {
        if member.as(StructDeclSyntax.self) != nil {
            return true
        }
        guard let enumDecl = member.as(EnumDeclSyntax.self) else {
            return false
        }

        let cases = enumDecl.memberBlock.members.compactMap { $0.decl.as(EnumCaseDeclSyntax.self) }
        guard cases.isEmpty == false else {
            return false
        }
        return cases.allSatisfy { caseDecl in
            caseDecl.elements.allSatisfy { $0.parameterClause == nil }
        }
    }

    static func attributes(of member: some DeclSyntaxProtocol) -> AttributeListSyntax? {
        if let structDecl = member.as(StructDeclSyntax.self) {
            return structDecl.attributes
        }
        if let enumDecl = member.as(EnumDeclSyntax.self) {
            return enumDecl.attributes
        }
        return nil
    }
}
