import Foundation
import StateKit

enum SharedShoppingListDomain {
    enum Delegate: Sendable {
        case addProductToList(Product, ShoppingList.ID)
        case createList(name: String, product: Product?)
    }

    struct Projection: Sendable {
        var shoppingLists: [ShoppingList]
    }

    protocol State: Sendable {
        var availableShoppingLists: [ShoppingList] { get set }
        var shoppingListFlow: ShoppingListFlowState? { get set }
    }

    struct ActionAdapter<Action: Sendable> {
        var projectionUpdated: CasePath<Action, Projection>
        var addToListTapped: CasePath<Action, Product>
        var shoppingListFlow: CasePath<Action, ShoppingListFlowAction>
        var delegate: CasePath<Action, Delegate>
    }

    static func makeReducer<State: SharedShoppingListDomain.State, Action: Sendable>(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer<State, Action>.combine(
            shoppingListFlowReducer.optional.scope(
                state: \.shoppingListFlow,
                action: adapter.shoppingListFlow
            ),
            Reducer<State, Action> { state, action in
                if let projection = adapter.projectionUpdated.extract(action) {
                    state.availableShoppingLists = projection.shoppingLists
                    state.shoppingListFlow?.availableLists = projection.shoppingLists
                    return .none
                }

                if let product = adapter.addToListTapped.extract(action) {
                    state.shoppingListFlow = ShoppingListFlowState(
                        id: UUID(),
                        product: product,
                        mode: state.availableShoppingLists.isEmpty ? .create : .picker,
                        availableLists: state.availableShoppingLists
                    )
                    return .none
                }

                if let flowAction = adapter.shoppingListFlow.extract(action) {
                    switch flowAction {
                    case let .listSelected(listID):
                        guard let product = state.shoppingListFlow?.product else {
                            return .none
                        }
                        state.shoppingListFlow = nil
                        return .task {
                            adapter.delegate.embed(.addProductToList(product, listID))
                        }

                    case .createListConfirmed:
                        guard let flow = state.shoppingListFlow else {
                            return .none
                        }
                        state.shoppingListFlow = nil
                        return .task {
                            adapter.delegate.embed(.createList(name: flow.draftListName, product: flow.product))
                        }

                    case .dismissed:
                        state.shoppingListFlow = nil
                        return .none

                    case .createNewListTapped, .draftListNameChanged:
                        return .none
                    }
                }

                return .none
            }
        )
    }

    static func makeProjection(shoppingLists: [ShoppingList]) -> Projection {
        Projection(shoppingLists: shoppingLists)
    }
}
