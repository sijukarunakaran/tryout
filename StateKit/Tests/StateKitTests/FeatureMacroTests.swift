#if os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import StateKitMacros

final class FeatureMacroTests: XCTestCase {
    func testFeatureExpansion() {
        assertMacroExpansion(
            """
            @Feature
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped }
                private struct Dependencies {}
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            expandedSource:
            """
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped
                }
                private struct Dependencies {}
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }

            extension CartDomain: FeatureDomain {
            }
            """,
            macros: [
                "Feature": FeatureMacro.self,
            ]
        )
    }

    func testDependenciesMustBePrivate() {
        assertMacroExpansion(
            """
            @Feature
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped }
                struct Dependencies {}
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            expandedSource:
            """
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped
                }
                struct Dependencies {}
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Dependencies inside a @Feature must be private or fileprivate.", line: 5, column: 12)
            ],
            macros: [
                "Feature": FeatureMacro.self,
            ]
        )
    }

    func testStateMustBeSendableAndEquatable() {
        assertMacroExpansion(
            """
            @Feature
            enum CartDomain {
                struct State {}
                enum Action: Sendable { case tapped }
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            expandedSource:
            """
            enum CartDomain {
                struct State {}
                enum Action: Sendable { case tapped
                }
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Feature State must conform to Sendable.", line: 4, column: 12),
                DiagnosticSpec(message: "Feature State must conform to Equatable or use @NonisolatedEquatable.", line: 4, column: 12),
            ],
            macros: [
                "Feature": FeatureMacro.self,
            ]
        )
    }

    func testActionMustBeSendable() {
        assertMacroExpansion(
            """
            @Feature
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action { case tapped }
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            expandedSource:
            """
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action { case tapped
                }
                static let reducer = Reducer<State, Action> { _, _ in .none }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Feature Action must conform to Sendable.", line: 5, column: 10),
            ],
            macros: [
                "Feature": FeatureMacro.self,
            ]
        )
    }

    func testReducerMustBeStaticLetUsingFeatureTypes() {
        assertMacroExpansion(
            """
            @Feature
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped }
                var reducer: Reducer<Int, Action> { Reducer<Int, Action> { _, _ in .none } }
            }
            """,
            expandedSource:
            """
            enum CartDomain {
                struct State: Sendable, Equatable {}
                enum Action: Sendable { case tapped
                }
                var reducer: Reducer<Int, Action> { Reducer<Int, Action> { _, _ in .none } }
            }
            """,
            diagnostics: [
                DiagnosticSpec(message: "Feature reducer must be declared static.", line: 6, column: 5),
                DiagnosticSpec(message: "Feature reducer must be declared with let.", line: 6, column: 5),
                DiagnosticSpec(message: "Feature reducer must use Reducer<State, Action>.", line: 6, column: 9),
            ],
            macros: [
                "Feature": FeatureMacro.self,
            ]
        )
    }
}
#endif
