import Testing
@testable import StateKit

@Suite("Reducer variants")
struct ReducerVariantTests {
    @Test("intercept fires willDispatch before state change")
    func interceptWillDispatch() {
        struct S: Equatable, Sendable { var count = 0 }
        enum A: Sendable { case increment }

        var willCount = 0
        var didCount = 0

        let reducer = Reducer<S, A> { state, _ in
            state.count += 1; return .none
        }.intercept(
            willDispatch: { state, _ in willCount = state.count },  // before mutation
            didDispatch: { state, _ in didCount = state.count }      // after mutation
        )

        var state = S()
        _ = reducer.reduce(&state, .increment)

        #expect(willCount == 0)  // saw count before mutation
        #expect(didCount == 1)   // saw count after mutation
    }

    @Test("optional reducer ignores nil state")
    func optionalIgnoresNil() {
        struct S: Equatable, Sendable { var count = 0 }
        enum A: Sendable { case inc }

        let reducer = Reducer<S, A> { state, _ in
            state.count += 1; return .none
        }.optional

        var state: S? = nil
        _ = reducer.reduce(&state, .inc)
        #expect(state == nil)
    }

    @Test("optional reducer forwards non-nil state")
    func optionalForwardsNonNil() {
        struct S: Equatable, Sendable { var count = 0 }
        enum A: Sendable { case inc }

        let reducer = Reducer<S, A> { state, _ in
            state.count += 1; return .none
        }.optional

        var state: S? = S()
        _ = reducer.reduce(&state, .inc)
        #expect(state?.count == 1)
    }

    @Test("combine merges effects from all reducers")
    func combineRunsAllReducers() {
        struct S: Equatable, Sendable { var a = 0; var b = 0 }
        enum A: Sendable { case both }

        let ra = Reducer<S, A> { state, _ in state.a += 1; return .none }
        let rb = Reducer<S, A> { state, _ in state.b += 10; return .none }
        let combined = Reducer.combine(ra, rb)

        var state = S()
        _ = combined.reduce(&state, .both)

        #expect(state.a == 1)
        #expect(state.b == 10)
    }
}
