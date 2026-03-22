import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct DependencyClientMacro: PeerMacro, ExtensionMacro {
    static let sourceAccessorName = "__dependencySource"

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let enclosingType = Self.enclosingType(for: declaration) else {
            throw MacroError.message("@DependencyClient can only be applied to a type.")
        }
        let dependencyTypeName = enclosingType.name
        let keyTypeName = "\(dependencyTypeName)Dependency"
        let accessModifier = enclosingType.accessModifier.map { "\($0) " } ?? ""

        return [
            """
            \(raw: accessModifier)enum \(raw: keyTypeName): DependencyKey {
                \(raw: accessModifier)static var liveValue: \(raw: dependencyTypeName) {
                    \(raw: dependencyTypeName).\(raw: sourceAccessorName)
                }
            }
            """
        ]
    }

    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let enclosingType = Self.enclosingType(for: declaration) else {
            throw MacroError.message("@DependencyClient can only be applied to a type.")
        }
        let keyTypeName = "\(enclosingType.name)Dependency"
        let accessModifier = enclosingType.accessModifier.map { "\($0) " } ?? ""

        return [
            try ExtensionDeclSyntax(
                """
                extension \(type.trimmed): DependencyProviding {
                    \(raw: accessModifier)typealias Dependency = \(raw: keyTypeName)
                }
                """
            )
        ]
    }

    private static func enclosingType(for declaration: some DeclSyntaxProtocol) -> (name: String, accessModifier: String?)? {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            return (structDecl.name.text, accessModifier(from: structDecl.modifiers))
        }
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            return (classDecl.name.text, accessModifier(from: classDecl.modifiers))
        }
        if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            return (enumDecl.name.text, accessModifier(from: enumDecl.modifiers))
        }
        if let actorDecl = declaration.as(ActorDeclSyntax.self) {
            return (actorDecl.name.text, accessModifier(from: actorDecl.modifiers))
        }
        return nil
    }

    private static func accessModifier(from modifiers: DeclModifierListSyntax) -> String? {
        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public):
                return "public"
            case .keyword(.package):
                return "package"
            case .keyword(.private):
                return "fileprivate"
            case .keyword(.fileprivate):
                return "fileprivate"
            default:
                continue
            }
        }
        return nil
    }
}

struct DependencySourceMacro: PeerMacro {
    private static let sourceAccessorName = DependencyClientMacro.sourceAccessorName

    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variable = declaration.as(VariableDeclSyntax.self) else {
            throw MacroError.message("@DependencySource can only be applied to a static property.")
        }
        guard variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.static) }) else {
            throw MacroError.message("@DependencySource can only be applied to a static property.")
        }
        guard variable.bindings.count == 1,
            let binding = variable.bindings.first,
            let identifier = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text,
            identifier == "live"
        else {
            throw MacroError.message("@DependencySource must be applied to a property named 'live'.")
        }

        return [
            """
            fileprivate static var \(raw: sourceAccessorName): Self {
                live
            }
            """
        ]
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
