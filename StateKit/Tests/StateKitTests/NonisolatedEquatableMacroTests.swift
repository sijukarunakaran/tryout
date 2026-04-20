#if os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import StateKitMacros

final class NonisolatedEquatableMacroTests: XCTestCase {
    func testStructExpansion() {
        assertMacroExpansion(
            """
            @NonisolatedEquatable
            struct FeatureState {
                var count = 0
                let name: String
            }
            """,
            expandedSource:
            """
            struct FeatureState {
                var count = 0
                let name: String
            }

            extension FeatureState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.count == rhs.count
                        && lhs.name == rhs.name
                }
            }
            """,
            macros: [
                "NonisolatedEquatable": NonisolatedEquatableMacro.self,
                "_NestedNonisolatedEquatable": NestedNonisolatedEquatableMacro.self,
            ]
        )
    }

    func testPayloadFreeEnumExpansion() {
        assertMacroExpansion(
            """
            @NonisolatedEquatable
            enum Mode {
                case picker
                case create
            }
            """,
            expandedSource:
            """
            enum Mode {
                case picker
                case create
            }

            extension Mode: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    switch (lhs, rhs) {
                    case (.picker, .picker):
                        true
                    case (.create, .create):
                        true
                    default:
                        false
                    }
                }
            }
            """,
            macros: [
                "NonisolatedEquatable": NonisolatedEquatableMacro.self,
                "_NestedNonisolatedEquatable": NestedNonisolatedEquatableMacro.self,
            ]
        )
    }

    func testNestedStructReceivesMacro() {
        assertMacroExpansion(
            """
            @NonisolatedEquatable
            struct ParentState {
                var childState: ChildState

                struct ChildState {
                    var count = 0
                }
            }
            """,
            expandedSource:
            """
            struct ParentState {
                var childState: ChildState
                struct ChildState {
                    var count = 0
                }
            }

            extension ParentState.ChildState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.count == rhs.count
                }
            }

            extension ParentState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.childState == rhs.childState
                }
            }
            """,
            macros: [
                "NonisolatedEquatable": NonisolatedEquatableMacro.self,
                "_NestedNonisolatedEquatable": NestedNonisolatedEquatableMacro.self,
            ]
        )
    }

    func testNestedStructDoesNotDuplicateMacro() {
        assertMacroExpansion(
            """
            @NonisolatedEquatable
            struct ParentState {
                var childState: ChildState

                @NonisolatedEquatable
                struct ChildState {
                    var count = 0
                }
            }
            """,
            expandedSource:
            """
            struct ParentState {
                var childState: ChildState

                struct ChildState {
                    var count = 0
                }
            }

            extension ParentState.ChildState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.count == rhs.count
                }
            }

            extension ParentState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.childState == rhs.childState
                }
            }
            """,
            macros: [
                "NonisolatedEquatable": NonisolatedEquatableMacro.self,
                "_NestedNonisolatedEquatable": NestedNonisolatedEquatableMacro.self,
            ]
        )
    }

    func testNestedPayloadFreeEnumReceivesMacro() {
        assertMacroExpansion(
            """
            @NonisolatedEquatable
            struct ParentState {
                var mode: Mode

                enum Mode {
                    case picker
                    case create
                }
            }
            """,
            expandedSource:
            """
            struct ParentState {
                var mode: Mode

                enum Mode {
                    case picker
                    case create
                }
            }

            extension ParentState.Mode: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    switch (lhs, rhs) {
                    case (.picker, .picker):
                        true
                    case (.create, .create):
                        true
                    default:
                        false
                    }
                }
            }

            extension ParentState: Equatable {
                nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
                    lhs.mode == rhs.mode
                }
            }
            """,
            macros: [
                "NonisolatedEquatable": NonisolatedEquatableMacro.self,
                "_NestedNonisolatedEquatable": NestedNonisolatedEquatableMacro.self,
            ]
        )
    }
}
#endif
