import Foundation
import StateKit

@Feature
enum BrowseDomain {
    @NonisolatedEquatable
    struct State: SharedLoginDomain.State, SharedCartDomain.State, SharedShoppingListDomain.State, Sendable {
        var products = Product.catalog
        var isAuthenticated = false
        var cartQuantities: [Product.ID: Int] = [:]
        var availableShoppingLists: [ShoppingList] = []
        var productDetail: ProductDetailState?
        var shoppingListFlow: ShoppingListFlowState?
    }

    @CasePathable
    enum Action: Sendable {
        case authProjectionUpdated(SharedLoginDomain.Projection)
        case cartProjectionUpdated(SharedCartDomain.Projection)
        case shoppingListProjectionUpdated(SharedShoppingListDomain.Projection)
        case productTapped(Product)
        case addToCartTapped(Product)
        case addToListTapped(Product)
        case productDetail(ProductDetailAction)
        case shoppingListFlow(ShoppingListFlowAction)
        case loginRequired(SharedLoginDomain.ProtectedAction)
        case cartDelegate(SharedCartDomain.Delegate)
        case shoppingListDelegate(SharedShoppingListDomain.Delegate)
    }

    static var cartAdapter: SharedCartDomain.ActionAdapter<Action> {
        SharedCartDomain.ActionAdapter<Action>(
            authProjectionUpdated: Action.authProjectionUpdated,
            projectionUpdated: Action.cartProjectionUpdated,
            productTapped: Action.productTapped,
            addToCartTapped: Action.addToCartTapped,
            productDetail: Action.productDetail,
            loginRequired: Action.loginRequired,
            delegate: Action.cartDelegate
        )
    }

    static var shoppingListAdapter: SharedShoppingListDomain.ActionAdapter<Action> {
        SharedShoppingListDomain.ActionAdapter<Action>(
            projectionUpdated: Action.shoppingListProjectionUpdated,
            addToListTapped: Action.addToListTapped,
            productDetail: Action.productDetail,
            shoppingListFlow: Action.shoppingListFlow,
            delegate: Action.shoppingListDelegate
        )
    }

    static let reducer: Reducer<State, Action> = .combine(
        SharedCartDomain.makeReducer(adapter: cartAdapter),
        SharedShoppingListDomain.makeReducer(adapter: shoppingListAdapter)
    )
}

typealias BrowseState = BrowseDomain.State
typealias BrowseAction = BrowseDomain.Action

let browseReducer = BrowseDomain.reducer
