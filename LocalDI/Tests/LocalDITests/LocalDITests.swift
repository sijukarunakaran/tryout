import Foundation
import Testing
@testable import LocalDI

// MARK: - ClockClient

@DependencyClient
private struct ClockClient: Sendable {
    var now: @Sendable () -> Date
}

extension ClockClient {
    @DependencySource
    private static let live = Self(now: Date.init)
}

// testValue returns a fixed sentinel so tests can assert against it directly.
private let clockTestDate = Date(timeIntervalSince1970: 123456789)

extension ClockClient {
    @DependencyTestSource
    private static let testLive = Self(now: { clockTestDate })
}

// MARK: - CounterKey (distinguishes liveValue from testValue)

// A minimal key defined by hand to give liveValue and testValue distinct values,
// letting us assert which one is returned without relying on unimplemented.
private enum CounterKey: DependencyKey {
    static let liveValue = 42
    static let testValue: Int? = 0
}

// MARK: - Readers

private struct NowReader {
    @Dependency(ClockClient.self) var clock
    func read() -> Date { clock.now() }
}

private struct CounterReader {
    @Dependency(CounterKey.self) var count
}

// MARK: - Concurrency helpers

private actor ValueBox<T: Sendable> {
    var value: T
    init(_ initial: T) { value = initial }
    func set(_ newValue: T) { value = newValue }
}

// MARK: - Tests

@Suite struct LocalDITests {
    init() {}

    @Test func clockTestValueIsUsed() {
        // testValue is active in the test process — no withDependencies needed.
        #expect(NowReader().read() == clockTestDate)
    }

    @Test func clockTestValueIsUsedAsync() async {
        let result = await MainActor.run { NowReader().read() }
        #expect(result == clockTestDate)
    }

    @Test func testValueIsReturnedWhenNoOverrideIsSet() {
        // CounterKey.testValue == 0, liveValue == 42.
        // Running inside the test process, DependencyValues should pick testValue.
        #expect(CounterReader().count == 0)
    }

    @Test func overrideTakesPrecedenceOverTestValue() {
        let result = withDependencies(
            { $0[CounterKey.self] = 99 },
            operation: { CounterReader().count }
        )
        #expect(result == 99)
    }

    // MARK: - Concurrency

    // Two child tasks override the same key to different values concurrently.
    // Each async let runs in its own child task with its own task-local scope,
    // so the overrides must not bleed into each other.
    @Test func concurrentScopesAreIsolated() async {
        async let a: Int = withDependencies({ $0[CounterKey.self] = 10 }) {
            await Task.yield()
            return CounterReader().count
        }
        async let b: Int = withDependencies({ $0[CounterKey.self] = 20 }) {
            await Task.yield()
            return CounterReader().count
        }
        let (ra, rb) = await (a, b)
        #expect(ra == 10)
        #expect(rb == 20)
    }

    // async let creates a structured child task that inherits the parent's
    // task-local values, so withDependencies overrides propagate into it.
    @Test func childTaskInheritsScope() async {
        let result = await withDependencies({ $0[CounterKey.self] = 55 }) {
            async let child: Int = CounterReader().count
            return await child
        }
        #expect(result == 55)
    }

    // Task.detached is NOT a child task — it does not inherit task-local values.
    // This is a fundamental Swift @TaskLocal limitation: always use structured
    // concurrency (async let, TaskGroup) inside withDependencies to preserve scoping.
    @Test func detachedTaskDoesNotInheritScope() async {
        let box = ValueBox(0)
        await withDependencies({ $0[CounterKey.self] = 77 }) {
            let t = Task.detached { await box.set(CounterReader().count) }
            await t.value
        }
        // Detached task sees testValue (0), not the parent override (77).
        let captured = await box.value
        #expect(captured == 0)
    }
}

