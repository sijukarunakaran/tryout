import Foundation
import StateKit

enum SharedLoginDomain {
    protocol State: Sendable {
        var isAuthenticated: Bool { get set }
    }

    @NonisolatedEquatable
    struct Projection: Sendable {
        var isAuthenticated: Bool
    }

    @NonisolatedEquatable
    enum ProtectedAction: Sendable {
        case addToCart(Product)
        case addProductToList(Product, ShoppingList.ID)
        case createList(name: String, product: Product?)
        case startCreateList
    }

    struct ActionAdapter<Action: Sendable> {
        var projectionUpdated: CasePath<Action, Projection>
    }

    static func makeReducer<State: SharedLoginDomain.State, Action: Sendable>(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer { state, action in
            if let projection = adapter.projectionUpdated.extract(action) {
                state.isAuthenticated = projection.isAuthenticated
            }
            return .none
        }
    }
}
