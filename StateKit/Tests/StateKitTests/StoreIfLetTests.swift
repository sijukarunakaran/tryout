import Testing
@testable import StateKit

@Suite("Store ifLet")
@MainActor
struct StoreIfLetTests {
    @Test("child store stops sending after parent state becomes nil")
    func childStoreStopsAfterNil() throws {
        struct ChildState: Equatable, Sendable { var count = 0 }
        struct ParentState: Equatable, Sendable {
            var child: ChildState?
            var childActionCount = 0
        }
        enum ChildAction: Sendable { case tapped }
        enum ParentAction: Sendable {
            case child(ChildAction)
            case dismissChild
        }

        let reducer = Reducer<ParentState, ParentAction> { state, action in
            switch action {
            case .child(.tapped):
                state.childActionCount += 1
                state.child?.count += 1
                return .none
            case .dismissChild:
                state.child = nil
                return .none
            }
        }

        let store = Store(initialState: ParentState(child: ChildState()), reducer: reducer)
        let childStore = try #require(store.ifLet(state: \.child, action: ParentAction.child))

        childStore.send(.tapped)
        #expect(store.state.childActionCount == 1)
        #expect(store.state.child?.count == 1)

        store.send(.dismissChild)
        #expect(store.state.child == nil)

        childStore.send(.tapped)
        #expect(store.state.childActionCount == 1)
        #expect(store.state.child == nil)
    }
}
