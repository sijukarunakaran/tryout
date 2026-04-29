import Foundation
import StateKit

enum SharedShoppingListDomain {
    enum Delegate: Sendable {
        case addProductToList(Product, ShoppingList.ID)
        case createList(name: String, product: Product?)
        case addToListRequested(product: Product, availableLists: [ShoppingList])
    }

    struct Projection: Sendable {
        var shoppingLists: [ShoppingList]
    }

    protocol State: Sendable {
        var availableShoppingLists: [ShoppingList] { get set }
    }

    struct ActionAdapter<Action: Sendable> {
        var projectionUpdated: CasePath<Action, Projection>
        var addToListTapped: CasePath<Action, Product>
        var delegate: CasePath<Action, Delegate>
    }

    static func makeReducer<State: SharedShoppingListDomain.State, Action: Sendable>(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer<State, Action> { state, action in
            if let projection = adapter.projectionUpdated.extract(action) {
                state.availableShoppingLists = projection.shoppingLists
                return .none
            }

            if let product = adapter.addToListTapped.extract(action) {
                let lists = state.availableShoppingLists
                return .task {
                    adapter.delegate.embed(.addToListRequested(product: product, availableLists: lists))
                }
            }

            return .none
        }
    }

    static func makeProjection(shoppingLists: [ShoppingList]) -> Projection {
        Projection(shoppingLists: shoppingLists)
    }
}
