#if os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import StateKitMacros

final class CasePathableMacroTests: XCTestCase {
    func testSinglePayloadCaseGeneratesStaticVar() {
        assertMacroExpansion(
            """
            @CasePathable
            enum MyAction {
                case loaded(Int)
                case failed(String)
            }
            """,
            expandedSource:
            """
            enum MyAction {
                case loaded(Int)
                case failed(String)

                static var loaded: CasePath<MyAction, Int> {
                    CasePath(
                        extract: { root in
                            guard case let .loaded(value) = root else {
                                return nil
                            }
                            return value
                        },
                        embed: { value in
                            .loaded(value)
                        }
                    )
                }

                static var failed: CasePath<MyAction, String> {
                    CasePath(
                        extract: { root in
                            guard case let .failed(value) = root else {
                                return nil
                            }
                            return value
                        },
                        embed: { value in
                            .failed(value)
                        }
                    )
                }
            }
            """,
            macros: ["CasePathable": CasePathableMacro.self]
        )
    }

    func testNoPayloadCaseEmitsDiagnosticNote() {
        assertMacroExpansion(
            """
            @CasePathable
            enum MyAction {
                case tapped
                case loaded(Int)
            }
            """,
            expandedSource:
            """
            enum MyAction {
                case tapped
                case loaded(Int)

                static var loaded: CasePath<MyAction, Int> {
                    CasePath(
                        extract: { root in
                            guard case let .loaded(value) = root else {
                                return nil
                            }
                            return value
                        },
                        embed: { value in
                            .loaded(value)
                        }
                    )
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@CasePathable skips '.tapped': no-payload cases cannot produce a CasePath.",
                    line: 3,
                    column: 10,
                    severity: .note
                )
            ],
            macros: ["CasePathable": CasePathableMacro.self]
        )
    }

    func testMultiPayloadCaseEmitsDiagnosticNote() {
        assertMacroExpansion(
            """
            @CasePathable
            enum MyAction {
                case multi(Int, String)
                case loaded(Int)
            }
            """,
            expandedSource:
            """
            enum MyAction {
                case multi(Int, String)
                case loaded(Int)

                static var loaded: CasePath<MyAction, Int> {
                    CasePath(
                        extract: { root in
                            guard case let .loaded(value) = root else {
                                return nil
                            }
                            return value
                        },
                        embed: { value in
                            .loaded(value)
                        }
                    )
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@CasePathable skips '.multi': multi-parameter cases are not supported. Use a single tuple payload instead.",
                    line: 3,
                    column: 10,
                    severity: .note
                )
            ],
            macros: ["CasePathable": CasePathableMacro.self]
        )
    }
}
#endif
