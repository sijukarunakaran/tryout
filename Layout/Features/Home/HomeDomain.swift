import Foundation
import StateKit

enum HomeDomain: FeatureDomain {
    @NonisolatedEquatable
    struct State: CatalogFeatureDomain.State {
        var products = Product.catalog
        var cartQuantities: [Product.ID: Int] = [:]
        var availableShoppingLists: [ShoppingList] = []
        var productDetail: ProductDetailState?
        var shoppingListFlow: ShoppingListFlowState?
    }

    @CasePathable
    enum Action: Sendable {
        case productTapped(Product.ID)
        case addToCartTapped(Product)
        case addToListTapped(Product, hasExistingLists: Bool)
        case productDetail(ProductDetailAction)
        case shoppingListFlow(ShoppingListFlowAction)
        case delegate(CatalogFeatureDomain.Delegate)
    }

    static var catalogAdapter: CatalogFeatureDomain.ActionAdapter<Action> {
        CatalogFeatureDomain.ActionAdapter<Action>(
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
            addToListTapped: {
                guard case let .addToListTapped(product, hasExistingLists) = $0 else {
                    return nil
                }
                return (product, hasExistingLists)
            },
            productDetail: Action.productDetail,
            shoppingListFlow: Action.shoppingListFlow,
            delegate: Action.delegate
        )
    }

    static let reducer: Reducer<State, Action> = CatalogFeatureDomain.makeReducer(
        adapter: catalogAdapter
    )

    static func syncProjection(
        _ state: inout State,
        projection: CatalogFeatureDomain.Projection
    ) {
        state.cartQuantities = projection.cartQuantities
        state.availableShoppingLists = projection.shoppingLists
        CatalogFeatureDomain.syncProductDetail(
            &state.productDetail,
            projection: projection
        )
        CatalogFeatureDomain.syncShoppingListFlow(
            &state.shoppingListFlow,
            shoppingLists: projection.shoppingLists
        )
    }
}

typealias HomeState = HomeDomain.State
typealias HomeAction = HomeDomain.Action

let homeReducer = HomeDomain.reducer
