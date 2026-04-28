import Testing
@testable import StateKit

@Suite("Store scope")
@MainActor
struct StoreScopeTests {
    @Test("child store reflects parent state changes")
    @MainActor
    func childStoreSyncsOnParentChange() async {
        struct ParentState: Equatable, Sendable {
            var count = 0
            var name = "initial"
        }
        enum ParentAction: Sendable { case increment; case rename(String) }

        let reducer = Reducer<ParentState, ParentAction> { state, action in
            switch action {
            case .increment: state.count += 1; return .none
            case .rename(let n): state.name = n; return .none
            }
        }

        let parent = Store(initialState: ParentState(), reducer: reducer)
        let child = parent.scope(
            state: { $0.count },
            action: { (_: Never) -> ParentAction in }
        )

        #expect(child.state == 0)
        parent.send(.increment)
        await Task.yield()
        parent.send(.increment)
        await Task.yield()
        #expect(child.state == 2)
    }

    @Test("child store action forwards to parent")
    func childActionForwardsToParent() {
        struct ParentState: Equatable, Sendable { var count = 0 }
        enum ParentAction: Sendable { case increment }
        enum ChildAction: Sendable { case tap }

        let reducer = Reducer<ParentState, ParentAction> { state, action in
            state.count += 1; return .none
        }

        let parent = Store(initialState: ParentState(), reducer: reducer)
        let child = parent.scope(
            state: { $0.count },
            action: { (_: ChildAction) in ParentAction.increment }
        )

        child.send(.tap)
        #expect(parent.state.count == 1)
    }

    @Test("scoped child state does not update when unrelated parent field changes")
    func noSpuriousUpdateForUnrelatedField() {
        struct ParentState: Equatable, Sendable { var count = 0; var name = "a" }
        enum ParentAction: Sendable { case rename(String) }

        let reducer = Reducer<ParentState, ParentAction> { state, action in
            switch action { case .rename(let n): state.name = n; return .none }
        }

        let parent = Store(initialState: ParentState(), reducer: reducer)
        let child = parent.scope(
            state: { $0.count },
            action: { (_: Never) -> ParentAction in }
        )

        let initialState = child.state
        parent.send(.rename("b"))
        #expect(child.state == initialState)
    }
}
