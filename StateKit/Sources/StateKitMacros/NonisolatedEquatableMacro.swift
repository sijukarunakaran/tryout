import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

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

        throw MacroError.message("@NonisolatedEquatable can only be applied to a struct or enum.")
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
        let cases = enumDecl.memberBlock.members.compactMap { member -> [String]? in
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else {
                return nil
            }
            return caseDecl.elements.map(makeEnumCaseComparison)
        }
        .flatMap { $0 }

        guard cases.isEmpty == false else {
            throw MacroError.message("@NonisolatedEquatable requires at least one enum case.")
        }

        let comparisons = """
        switch (lhs, rhs) {
        \(cases.joined(separator: "\n"))
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

    static func makeEnumCaseComparison(_ element: EnumCaseElementSyntax) -> String {
        let caseName = element.name.text
        guard let parameterClause = element.parameterClause else {
            return """
                    case (.\(caseName), .\(caseName)):
                        true
            """
        }

        let bindings = parameterClause.parameters.enumerated().map { index, parameter in
            let patternName = parameter.firstName?.text
            let baseName = bindingName(for: parameter, index: index)
            return (
                lhs: "lhs_\(baseName)",
                rhs: "rhs_\(baseName)",
                pattern: patternName == "_" ? nil : patternName
            )
        }

        let lhsPattern = bindings.map { binding in
            if let pattern = binding.pattern {
                return "\(pattern): \(binding.lhs)"
            }
            return binding.lhs
        }
        .joined(separator: ", ")

        let rhsPattern = bindings.map { binding in
            if let pattern = binding.pattern {
                return "\(pattern): \(binding.rhs)"
            }
            return binding.rhs
        }
        .joined(separator: ", ")

        let comparisons = bindings.isEmpty
            ? "true"
            : bindings.enumerated().map { index, binding in
                let prefix = index == 0 ? "" : "            && "
                return "\(prefix)\(binding.lhs) == \(binding.rhs)"
            }
            .joined(separator: "\n")

        return """
                case let (.\(caseName)(\(lhsPattern)), .\(caseName)(\(rhsPattern))):
                    \(comparisons)
        """
    }

    static func bindingName(for parameter: EnumCaseParameterSyntax, index: Int) -> String {
        let candidate = parameter.secondName?.text ?? parameter.firstName?.text ?? "value\(index)"
        let sanitized = String(candidate.map { character in
            character.isLetter || character.isNumber || character == "_" ? character : "_"
        })
        if sanitized.isEmpty || sanitized == "_" {
            return "value\(index)"
        }
        return sanitized
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
        return member.as(EnumDeclSyntax.self) != nil
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
