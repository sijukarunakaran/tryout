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
            ]
        )
    }
}
#endif
