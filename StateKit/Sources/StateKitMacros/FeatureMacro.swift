import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct FeatureMacro: ExtensionMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enumDecl = declaration.as(EnumDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: FeatureDiagnostic.featureMustBeEnum
                )
            )
            return []
        }

        let members = enumDecl.memberBlock.members
        let stateDecls = members.compactMap { member in
            member.decl.as(StructDeclSyntax.self)?.name.text == "State"
                ? member.decl.as(StructDeclSyntax.self)
                : nil
        }
        let actionDecls = members.compactMap { member in
            member.decl.as(EnumDeclSyntax.self)?.name.text == "Action"
                ? member.decl.as(EnumDeclSyntax.self)
                : nil
        }
        let dependenciesDecls = members.compactMap { member in
            member.decl.as(StructDeclSyntax.self)?.name.text == "Dependencies"
                ? member.decl.as(StructDeclSyntax.self)
                : nil
        }
        let reducerDecls = members.compactMap { member in
            member.decl.as(VariableDeclSyntax.self)
        }
        .filter { variable in
            variable.bindings.contains { binding in
                binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text == "reducer"
            }
        }

        var shouldEmitConformance = true

        if stateDecls.isEmpty {
            shouldEmitConformance = false
            context.diagnose(
                Diagnostic(
                    node: Syntax(enumDecl.name),
                    message: FeatureDiagnostic.missingState
                )
            )
        } else {
            if stateDecls.count > 1 {
                shouldEmitConformance = false
                for stateDecl in stateDecls.dropFirst() {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(stateDecl.name),
                            message: FeatureDiagnostic.duplicateState
                        )
                    )
                }
            }

            if let stateDecl = stateDecls.first {
                if inherits(stateDecl, named: "Sendable") == false {
                    shouldEmitConformance = false
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(stateDecl.name),
                            message: FeatureDiagnostic.stateMustConformToSendable
                        )
                    )
                }

                if inherits(stateDecl, named: "Equatable") == false,
                   hasAttribute(stateDecl.attributes, named: "NonisolatedEquatable") == false
                {
                    shouldEmitConformance = false
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(stateDecl.name),
                            message: FeatureDiagnostic.stateMustConformToEquatable
                        )
                    )
                }
            }
        }

        if actionDecls.isEmpty {
            shouldEmitConformance = false
            context.diagnose(
                Diagnostic(
                    node: Syntax(enumDecl.name),
                    message: FeatureDiagnostic.missingAction
                )
            )
        } else {
            if actionDecls.count > 1 {
                shouldEmitConformance = false
                for actionDecl in actionDecls.dropFirst() {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(actionDecl.name),
                            message: FeatureDiagnostic.duplicateAction
                        )
                    )
                }
            }

            if let actionDecl = actionDecls.first, inherits(actionDecl, named: "Sendable") == false {
                shouldEmitConformance = false
                context.diagnose(
                    Diagnostic(
                        node: Syntax(actionDecl.name),
                        message: FeatureDiagnostic.actionMustConformToSendable
                    )
                )
            }
        }

        if reducerDecls.isEmpty {
            shouldEmitConformance = false
            context.diagnose(
                Diagnostic(
                    node: Syntax(enumDecl.name),
                    message: FeatureDiagnostic.missingReducer
                )
            )
        } else {
            if reducerDecls.count > 1 {
                shouldEmitConformance = false
                for reducerDecl in reducerDecls.dropFirst() {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(reducerDecl),
                            message: FeatureDiagnostic.duplicateReducer
                        )
                    )
                }
            }

            if let reducerDecl = reducerDecls.first {
                let isStatic = reducerDecl.modifiers.contains {
                    $0.name.tokenKind == .keyword(.static)
                }
                if isStatic == false {
                    shouldEmitConformance = false
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(reducerDecl),
                            message: FeatureDiagnostic.reducerMustBeStatic
                        )
                    )
                }

                if reducerDecl.bindingSpecifier.tokenKind != .keyword(.let) {
                    shouldEmitConformance = false
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(reducerDecl.bindingSpecifier),
                            message: FeatureDiagnostic.reducerMustBeLet
                        )
                    )
                }

                if let binding = reducerDecl.bindings.first {
                    let hasValidType =
                        hasReducerTypeAnnotation(binding) || hasReducerInitializer(binding)
                    if hasValidType == false {
                        shouldEmitConformance = false
                        context.diagnose(
                            Diagnostic(
                                node: Syntax(binding),
                                message: FeatureDiagnostic.reducerMustUseFeatureTypes
                            )
                        )
                    }
                }
            }
        }

        if dependenciesDecls.count > 1 {
            shouldEmitConformance = false
            for dependenciesDecl in dependenciesDecls.dropFirst() {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(dependenciesDecl.name),
                        message: FeatureDiagnostic.duplicateDependencies
                    )
                )
            }
        }
        for dependenciesDecl in dependenciesDecls {
            let isPrivate = dependenciesDecl.modifiers.contains { modifier in
                switch modifier.name.tokenKind {
                case .keyword(.private), .keyword(.fileprivate):
                    true
                default:
                    false
                }
            }

            if isPrivate == false {
                shouldEmitConformance = false
                context.diagnose(
                    Diagnostic(
                        node: Syntax(dependenciesDecl.name),
                        message: FeatureDiagnostic.dependenciesMustBePrivate
                    )
                )
            }
        }

        guard shouldEmitConformance else {
            return []
        }

        return [
            try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): FeatureDomain {}
                """
            )
        ]
    }
}

private func inherits(
    _ decl: StructDeclSyntax,
    named typeName: String
) -> Bool {
    decl.inheritanceClause?.inheritedTypes.contains(where: { inheritedType in
        inheritedType.type.trimmedDescription == typeName
    }) == true
}

private func inherits(
    _ decl: EnumDeclSyntax,
    named typeName: String
) -> Bool {
    decl.inheritanceClause?.inheritedTypes.contains(where: { inheritedType in
        inheritedType.type.trimmedDescription == typeName
    }) == true
}

private func hasAttribute(_ attributes: AttributeListSyntax?, named name: String) -> Bool {
    attributes?.contains(where: { element in
        guard case let .attribute(attribute) = element else { return false }
        return attribute.attributeName.trimmedDescription == name
    }) == true
}

private func hasReducerTypeAnnotation(_ binding: PatternBindingSyntax) -> Bool {
    binding.typeAnnotation?.type.trimmedDescription == "Reducer<State, Action>"
}

private func hasReducerInitializer(_ binding: PatternBindingSyntax) -> Bool {
    guard let initializer = binding.initializer else {
        return false
    }

    let value = initializer.value.trimmedDescription
    return value.hasPrefix("Reducer<State, Action>")
}

private enum FeatureDiagnostic: DiagnosticMessage {
    case featureMustBeEnum
    case missingState
    case missingAction
    case missingReducer
    case duplicateState
    case duplicateAction
    case duplicateReducer
    case duplicateDependencies
    case stateMustConformToSendable
    case stateMustConformToEquatable
    case actionMustConformToSendable
    case reducerMustBeStatic
    case reducerMustBeLet
    case reducerMustUseFeatureTypes
    case dependenciesMustBePrivate

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .featureMustBeEnum:
            "@Feature can only be applied to an enum."
        case .missingState:
            "@Feature requires a nested State type."
        case .missingAction:
            "@Feature requires a nested Action type."
        case .missingReducer:
            "@Feature requires a static reducer member."
        case .duplicateState:
            "@Feature only supports one nested State type."
        case .duplicateAction:
            "@Feature only supports one nested Action type."
        case .duplicateReducer:
            "@Feature only supports one reducer member."
        case .duplicateDependencies:
            "@Feature only supports one nested Dependencies type."
        case .stateMustConformToSendable:
            "Feature State must conform to Sendable."
        case .stateMustConformToEquatable:
            "Feature State must conform to Equatable or use @NonisolatedEquatable."
        case .actionMustConformToSendable:
            "Feature Action must conform to Sendable."
        case .reducerMustBeStatic:
            "Feature reducer must be declared static."
        case .reducerMustBeLet:
            "Feature reducer must be declared with let."
        case .reducerMustUseFeatureTypes:
            "Feature reducer must use Reducer<State, Action>."
        case .dependenciesMustBePrivate:
            "Dependencies inside a @Feature must be private or fileprivate."
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "StateKit.FeatureMacro", id: "\(self)")
    }
}
