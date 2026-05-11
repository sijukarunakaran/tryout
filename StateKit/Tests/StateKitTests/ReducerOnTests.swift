import Testing
@testable import StateKit

@Suite("Reducer.on factory")
struct ReducerOnTests {

    // MARK: - Helpers

    private struct S: Equatable, Sendable { var value = "" }

    /// Payload-only enum — safe to annotate with @CasePathable (no no-payload cases).
    @CasePathable
    private enum PayloadAction: Sendable {
        case setText(String)
        case setCount(Int)
    }

    /// Mixed enum with both payload and no-payload cases.
    private enum MixedAction: Sendable {
        case setText(String)
        case clear
    }

    // MARK: - on<Value> (payload cases)

    @Test("on with payload routes to the matching action")
    func onPayloadRoutes() {
        let reducer = Reducer<S, PayloadAction>.on(PayloadAction.setText) { state, text in
            state.value = text
            return .none
        }

        var state = S()
        _ = reducer.reduce(&state, .setText("hello"))
        #expect(state.value == "hello")
    }

    @Test("on with payload ignores non-matching action")
    func onPayloadIgnoresOther() {
        let reducer = Reducer<S, PayloadAction>.on(PayloadAction.setText) { state, text in
            state.value = text
            return .none
        }

        var state = S()
        _ = reducer.reduce(&state, .setCount(42))
        #expect(state.value == "")
    }

    @Test("on with payload returns .none effect for non-matching action")
    func onPayloadNonMatchingReturnsNone() {
        let reducer = Reducer<S, PayloadAction>.on(PayloadAction.setText) { state, text in
            state.value = text
            return .none
        }

        var state = S()
        let effect = reducer.reduce(&state, .setCount(1))
        #expect(effect.isEmpty)
    }

    // MARK: - on(matching:) (no-payload cases via predicate)

    @Test("on(matching:) routes to matching no-payload action")
    func onMatchingRoutes() {
        let reducer = Reducer<S, MixedAction>.on(
            matching: { if case .clear = $0 { return true }; return false }
        ) { state in
            state.value = "cleared"
            return .none
        }

        var state = S(value: "something")
        _ = reducer.reduce(&state, .clear)
        #expect(state.value == "cleared")
    }

    @Test("on(matching:) ignores non-matching action")
    func onMatchingIgnoresOther() {
        let reducer = Reducer<S, MixedAction>.on(
            matching: { if case .clear = $0 { return true }; return false }
        ) { state in
            state.value = "cleared"
            return .none
        }

        var state = S(value: "original")
        _ = reducer.reduce(&state, .setText("other"))
        #expect(state.value == "original")
    }

    @Test("on(matching:) returns .none effect for non-matching action")
    func onMatchingNonMatchingReturnsNone() {
        let reducer = Reducer<S, MixedAction>.on(
            matching: { if case .clear = $0 { return true }; return false }
        ) { state in
            return .none
        }

        var state = S()
        let effect = reducer.reduce(&state, .setText("hi"))
        #expect(effect.isEmpty)
    }

    // MARK: - combine of on reducers

    @Test("combine of on reducers each fire for their action, others are unaffected")
    func combineOnReducersFireIndependently() {
        struct Counter: Equatable, Sendable { var a = 0; var b = 0 }

        @CasePathable
        enum AB: Sendable { case valueA(Int); case valueB(String) }

        let reducer = Reducer<Counter, AB>.combine(
            .on(AB.valueA) { state, _ in state.a += 1; return .none },
            .on(AB.valueB) { state, _ in state.b += 1; return .none }
        )

        var state = Counter()
        _ = reducer.reduce(&state, .valueA(1))
        #expect(state.a == 1)
        #expect(state.b == 0)

        _ = reducer.reduce(&state, .valueB("x"))
        #expect(state.a == 1)
        #expect(state.b == 1)
    }

    @Test("combine of on reducers returns .none when no action matches")
    func combineReturnsNoneWhenNoMatch() {
        @CasePathable
        enum AB: Sendable { case a(Int); case b(Int) }
        struct T: Equatable, Sendable { var n = 0 }

        let reducer = Reducer<T, AB>.combine(
            .on(AB.a) { state, v in state.n = v; return .none }
        )

        var state = T()
        let effect = reducer.reduce(&state, .b(5))
        #expect(effect.isEmpty)
        #expect(state.n == 0)
    }
}
