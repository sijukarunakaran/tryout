import Foundation
import StateKit

enum ProductDetailDomain: FeatureDomain {
    @CasePathable
    enum Action: Sendable {
        case dismissed
        case addToCartTapped(Product)
        case addToListTapped(Bool)
        case shoppingListFlow(ShoppingListFlowAction)
    }

    @NonisolatedEquatable
    struct State: Identifiable, Sendable {
        var product: Product
        var cartQuantity = 0
        var availableShoppingLists: [ShoppingList] = []
        var shoppingListFlow: ShoppingListFlowState?

        var id: Product.ID {
            product.id
        }
    }

    static let reducer = Reducer<State, Action>.combine(
        shoppingListFlowReducer.optional.scope(
            state: \.shoppingListFlow,
            action: Action.shoppingListFlow
        ),
        Reducer<State, Action> { state, action in
            switch action {
            case let .addToListTapped(hasExistingLists):
                state.shoppingListFlow = ShoppingListFlowState(
                    id: UUID(),
                    product: state.product,
                    mode: hasExistingLists ? .picker : .create,
                    availableLists: state.availableShoppingLists
                )
                return .none

            case .shoppingListFlow(.dismissed):
                state.shoppingListFlow = nil
                return .none

            case .dismissed, .addToCartTapped, .shoppingListFlow:
                return .none
            }
        }
    )
}

typealias ProductDetailState = ProductDetailDomain.State
typealias ProductDetailAction = ProductDetailDomain.Action

let productDetailReducer = ProductDetailDomain.reducer
