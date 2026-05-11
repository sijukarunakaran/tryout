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
        .combine(
            .on(adapter.projectionUpdated) { state, projection in
                state.availableShoppingLists = projection.shoppingLists
                return .none
            },
            .on(adapter.addToListTapped) { state, product in
                let lists = state.availableShoppingLists
                return .task {
                    adapter.delegate.embed(.addToListRequested(product: product, availableLists: lists))
                }
            }
        )
    }

    static func makeProjection(shoppingLists: [ShoppingList]) -> Projection {
        Projection(shoppingLists: shoppingLists)
    }
}
