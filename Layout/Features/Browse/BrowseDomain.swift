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
        var navigationPath: [AppDestination] = []
    }

    @CasePathable
    enum Action: Sendable {
        case authProjectionUpdated(SharedLoginDomain.Projection)
        case cartProjectionUpdated(SharedCartDomain.Projection)
        case shoppingListProjectionUpdated(SharedShoppingListDomain.Projection)
        case addToCartTapped(Product)
        case addToListTapped(Product)
        case setNavigationPath([AppDestination])
        case cartDelegate(SharedCartDomain.Delegate)
        case shoppingListDelegate(SharedShoppingListDomain.Delegate)
    }

    static var loginAdapter: SharedLoginDomain.ActionAdapter<Action> {
        SharedLoginDomain.ActionAdapter(projectionUpdated: Action.authProjectionUpdated)
    }

    static var cartAdapter: SharedCartDomain.ActionAdapter<Action> {
        SharedCartDomain.ActionAdapter(
            projectionUpdated: Action.cartProjectionUpdated,
            addToCartTapped: Action.addToCartTapped,
            delegate: Action.cartDelegate
        )
    }

    static var shoppingListAdapter: SharedShoppingListDomain.ActionAdapter<Action> {
        SharedShoppingListDomain.ActionAdapter(
            projectionUpdated: Action.shoppingListProjectionUpdated,
            addToListTapped: Action.addToListTapped,
            delegate: Action.shoppingListDelegate
        )
    }

    static let featureReducer = Reducer<State, Action> { state, action in
        switch action {
        case .setNavigationPath(let path):
            state.navigationPath = path
            return .none
        default:
            return .none
        }
    }

    static let reducer: Reducer<State, Action> = .combine(
        SharedLoginDomain.makeReducer(adapter: loginAdapter),
        SharedCartDomain.makeReducer(adapter: cartAdapter),
        SharedShoppingListDomain.makeReducer(adapter: shoppingListAdapter),
        featureReducer
    )
}

typealias BrowseState = BrowseDomain.State
typealias BrowseAction = BrowseDomain.Action

let browseReducer = BrowseDomain.reducer
