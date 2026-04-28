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
        let accessModifier = MacroSupport.accessModifier(from: enumDecl.modifiers).map { "\($0) " } ?? ""

        var results: [DeclSyntax] = []

        for member in enumDecl.memberBlock.members {
            guard
                let caseDecl = member.decl.as(EnumCaseDeclSyntax.self),
                caseDecl.elements.count == 1,
                let element = caseDecl.elements.first
            else {
                continue
            }

            let caseName = element.name.text

            guard let parameterClause = element.parameterClause else {
                context.diagnose(Diagnostic(
                    node: Syntax(element.name),
                    message: CasePathableDiagnostic.noPayload(caseName: caseName)
                ))
                continue
            }

            guard parameterClause.parameters.count == 1, let parameter = parameterClause.parameters.first else {
                context.diagnose(Diagnostic(
                    node: Syntax(element.name),
                    message: CasePathableDiagnostic.multiplePayloads(caseName: caseName)
                ))
                continue
            }

            let valueType = parameter.type.trimmedDescription

            results.append(
                """
                \(raw: accessModifier)static var \(raw: caseName): CasePath<\(raw: enumName), \(raw: valueType)> {
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
            )
        }

        return results
    }
}

private enum CasePathableDiagnostic: DiagnosticMessage {
    case noPayload(caseName: String)
    case multiplePayloads(caseName: String)

    var severity: DiagnosticSeverity { .note }

    var message: String {
        switch self {
        case .noPayload(let name):
            "@CasePathable skips '.\(name)': no-payload cases cannot produce a CasePath."
        case .multiplePayloads(let name):
            "@CasePathable skips '.\(name)': multi-parameter cases are not supported. Use a single tuple payload instead."
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "StateKit.CasePathableMacro", id: "\(self)")
    }
}
