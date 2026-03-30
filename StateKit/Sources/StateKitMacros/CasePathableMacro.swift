import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct CasePathableMacro: MemberMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            throw MacroError.message("@CasePathable can only be applied to an enum.")
        }

        let enumName = enumDecl.name.text
        let accessModifier = Self.accessModifier(from: enumDecl.modifiers).map { "\($0) " } ?? ""

        return enumDecl.memberBlock.members.compactMap { member in
            guard
                let caseDecl = member.decl.as(EnumCaseDeclSyntax.self),
                caseDecl.elements.count == 1,
                let element = caseDecl.elements.first,
                let parameterClause = element.parameterClause,
                parameterClause.parameters.count == 1,
                let parameter = parameterClause.parameters.first
            else {
                return nil
            }

            let valueType = parameter.type.trimmedDescription

            let caseName = element.name.text
            let propertyName = caseName

            return
                """
                \(raw: accessModifier)static var \(raw: propertyName): CasePath<\(raw: enumName), \(raw: valueType)> {
                    CasePath(
                        extract: { root in
                            guard case let .\(raw: caseName)(value) = root else { return nil }
                            return value
                        },
                        embed: { value in
                            .\(raw: caseName)(value)
                        }
                    )
                }
                """
        }
    }

    private static func accessModifier(from modifiers: DeclModifierListSyntax) -> String? {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public):
                return "public"
            case .keyword(.package):
                return "package"
            default:
                continue
            }
        }
        return nil
    }
}

private enum MacroError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(message):
            return message
        }
    }
}
