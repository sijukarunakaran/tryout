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
}
#endif
