import Testing
@testable import StateKit

@Suite("Reducer Scoping")
struct ReducerScopingTests {
    @Test("scope routes child action to child reducer")
    func scopeRoutesChildAction() {
        struct ChildState: Equatable, Sendable { var count = 0 }
        struct ParentState: Equatable, Sendable { var child = ChildState() }
        enum ChildAction: Sendable { case increment }

        @CasePathable
        enum ParentAction: Sendable {
            case child(ChildAction)
            case ignored
        }

        let childReducer = Reducer<ChildState, ChildAction> { state, action in
            switch action {
            case .increment: state.count += 1; return .none
            }
        }

        let reducer = childReducer.scope(state: \ParentState.child, action: ParentAction.child)
        var state = ParentState()
        _ = reducer.reduce(&state, ParentAction.child(.increment))

        #expect(state.child.count == 1)
    }

    @Test("scope ignores unrelated action")
    func scopeIgnoresUnrelated() {
        struct ChildState: Equatable, Sendable { var count = 0 }
        struct ParentState: Equatable, Sendable { var child = ChildState() }
        enum ChildAction: Sendable { case increment }

        @CasePathable
        enum ParentAction: Sendable {
            case child(ChildAction)
            case ignored
        }

        let childReducer = Reducer<ChildState, ChildAction> { state, action in
            switch action {
            case .increment: state.count += 1; return .none
            }
        }

        let reducer = childReducer.scope(state: \ParentState.child, action: ParentAction.child)
        var state = ParentState()
        _ = reducer.reduce(&state, ParentAction.ignored)

        #expect(state.child.count == 0)
    }

    @Test("generated CasePath embeds and extracts")
    func generatedCasePathEmbedsAndExtracts() {
        enum ChildAction: Equatable, Sendable { case increment }

        @CasePathable
        enum ParentAction: Equatable, Sendable {
            case child(ChildAction)
            case ignored
        }

        #expect(ParentAction.child.extract(.child(.increment)) == .increment)
        #expect(ParentAction.child.extract(.ignored) == nil)
        #expect(ParentAction.child.embed(.increment) == .child(.increment))
    }
}
