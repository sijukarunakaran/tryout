import Foundation
import StateKit

@Feature
enum ProductDetailDomain {
    @CasePathable
    enum Action: Sendable {
        case dismissed
        case addToCartTapped(Product)
        case addToListTapped
    }

    @NonisolatedEquatable
    struct State: Identifiable, Sendable {
        var product: Product
        var cartQuantity = 0
        var availableShoppingLists: [ShoppingList] = []

        var id: Product.ID {
            product.id
        }
    }

    static let reducer = Reducer<State, Action> { _, _ in .none }
}

typealias ProductDetailState = ProductDetailDomain.State
typealias ProductDetailAction = ProductDetailDomain.Action

let productDetailReducer = ProductDetailDomain.reducer
