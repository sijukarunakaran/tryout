import Foundation
import Testing
@testable import LocalDI

@DependencyClient
private struct ClockClient: Sendable {
    var now: @Sendable () -> Date
}

extension ClockClient {
    @DependencySource
    private static let live = Self(
        now: Date.init
    )
}

private struct NowReader {
    @Dependency(ClockClient.self) var clock

    func read() -> Date {
        clock.now()
    }
}

@Test func dependencyOverrideIsUsed() async throws {
    let fixedDate = Date(timeIntervalSince1970: 123456789)

    let result = withDependencies(
        { values in
            values[ClockClient.Dependency.self] = ClockClient(
                now: { fixedDate }
            )
        },
        operation: {
            NowReader().read()
        }
    )

    #expect(result == fixedDate)
}
