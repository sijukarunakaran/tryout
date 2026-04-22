import Foundation
import StateKit

@Feature
enum BrowseDomain {
    @NonisolatedEquatable
    struct State: SharedCartDomain.State, SharedShoppingListDomain.State, Sendable {
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
        case productTapped(Product.ID)
        case addToCartTapped(Product)
        case addToListTapped(Product, hasExistingLists: Bool)
        case productDetail(ProductDetailAction)
        case shoppingListFlow(ShoppingListFlowAction)
        case loginRequired(SharedLoginDomain.ProtectedAction)
        case cartDelegate(SharedCartDomain.Delegate)
        case shoppingListDelegate(SharedShoppingListDomain.Delegate)
    }

    static var cartAdapter: SharedCartDomain.ActionAdapter<Action> {
        SharedCartDomain.ActionAdapter<Action>(
            authProjectionUpdated: {
                guard case let .authProjectionUpdated(projection) = $0 else {
                    return nil
                }
                return projection
            },
            projectionUpdated: {
                guard case let .cartProjectionUpdated(projection) = $0 else {
                    return nil
                }
                return projection
            },
            productTapped: {
                guard case let .productTapped(productID) = $0 else {
                    return nil
                }
                return productID
            },
            addToCartTapped: {
                guard case let .addToCartTapped(product) = $0 else {
                    return nil
                }
                return product
            },
            productDetail: Action.productDetail,
            loginRequired: Action.loginRequired,
            delegate: Action.cartDelegate
        )
    }

    static var shoppingListAdapter: SharedShoppingListDomain.ActionAdapter<Action> {
        SharedShoppingListDomain.ActionAdapter<Action>(
            projectionUpdated: {
                guard case let .shoppingListProjectionUpdated(projection) = $0 else {
                    return nil
                }
                return projection
            },
            addToListTapped: {
                guard case let .addToListTapped(product, hasExistingLists) = $0 else {
                    return nil
                }
                return (product, hasExistingLists)
            },
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
