import Testing
@testable import StateKit

// Thread-safe collector for use in @Sendable effect callbacks
private actor ValueCollector<T: Sendable> {
    var values: [T] = []
    func append(_ value: T) { values.append(value) }
}

@Suite("Effect behaviour")
struct EffectTests {
    @Test("merge fires all effects")
    func mergeFiresAllEffects() async {
        let collector = ValueCollector<Int>()
        let e1 = Effect<Int>.task { 1 }
        let e2 = Effect<Int>.task { 2 }
        let merged = Effect.merge(e1, e2)
        let tasks = merged.run { v in Task { await collector.append(v) } }
        for t in tasks { await t.value }
        // Give time for inner tasks to complete
        try? await Task.sleep(nanoseconds: 10_000_000)
        let received = await collector.values
        #expect(received.sorted() == [1, 2])
    }

    @Test("none effect produces no tasks")
    func noneProducesNoTasks() {
        let tasks = Effect<Int>.none.run { _ in }
        #expect(tasks.isEmpty)
    }

    @Test("isEmpty is true only for none")
    func isEmptyFlagCorrect() {
        #expect(Effect<Int>.none.isEmpty == true)
        #expect(Effect<Int>.task { 1 }.isEmpty == false)
        #expect(Effect<Int>.fireAndForget {}.isEmpty == false)
    }

    @Test("cancellableTask cancel-in-flight replaces previous task")
    func cancellableTaskCancelInFlight() async {
        enum ID: Hashable { case fetch }
        let collector = ValueCollector<Int>()

        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let e1 = Effect<Int>.cancellableTask(id: ID.fetch, cancelInFlight: true) {
            continuation.yield(())
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return 1
        }
        let e2 = Effect<Int>.cancellableTask(id: ID.fetch, cancelInFlight: true) { 2 }

        let tasks1 = e1.run { v in Task { await collector.append(v) } }
        for await _ in stream { break }  // wait for e1 task to start
        let tasks2 = e2.run { v in Task { await collector.append(v) } }

        for t in tasks2 { await t.value }
        try? await Task.sleep(nanoseconds: 10_000_000)

        let received = await collector.values
        #expect(received == [2])

        for t in tasks1 { t.cancel() }
    }

    @Test("cancel stops a running cancellable task")
    func cancelStopsTask() async {
        enum ID: Hashable { case run }
        let collector = ValueCollector<Int>()

        let (stream, continuation) = AsyncStream<Void>.makeStream()

        let runEffect = Effect<Int>.cancellableTask(id: ID.run, cancelInFlight: false) {
            continuation.yield(())
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            return 99
        }
        let cancelEffect = Effect<Int>.cancel(id: ID.run)

        let runTasks = runEffect.run { v in Task { await collector.append(v) } }
        for await _ in stream { break }  // wait for task to start
        let cancelTasks = cancelEffect.run { _ in }

        for t in cancelTasks { await t.value }
        try? await Task.sleep(nanoseconds: 10_000_000)

        let received = await collector.values
        #expect(received.isEmpty)

        for t in runTasks { t.cancel() }
    }
}
