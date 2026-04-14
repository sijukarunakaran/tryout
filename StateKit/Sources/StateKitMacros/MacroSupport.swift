import SwiftDiagnostics
import SwiftSyntax

enum MacroSupport {
    static func accessModifier(from modifiers: DeclModifierListSyntax) -> String? {
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

    static func lowercaseFirstLetter(_ value: String) -> String {
        guard let first = value.first else { return value }
        return first.lowercased() + value.dropFirst()
    }
}

enum MacroError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case let .message(message):
            return message
        }
    }
}
