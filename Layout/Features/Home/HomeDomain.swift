import Foundation
import StateKit

@Feature
enum HomeDomain {
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
            shoppingListFlow: Action.shoppingListFlow,
            delegate: Action.shoppingListDelegate
        )
    }

    static let featureReducer = Reducer<State, Action>.combine(
        productDetailReducer.optional.scope(
            state: \.productDetail,
            action: Action.productDetail
        ),
        Reducer<State, Action> { state, action in
        switch action {
        case let .productTapped(product):
            state.productDetail = ProductDetailState(
                product: product,
                cartQuantity: state.cartQuantities[product.id] ?? 0,
                availableShoppingLists: state.availableShoppingLists
            )
            return .none

        case .productDetail(.dismissed):
            state.productDetail = nil
            return .none

        case .productDetail(.addToCartTapped(let product)):
            return .task { .addToCartTapped(product) }

        case let .cartProjectionUpdated(projection):
            if let id = state.productDetail?.product.id {
                state.productDetail?.cartQuantity = projection.cartQuantities[id] ?? 0
            }
            return .none

        case let .shoppingListProjectionUpdated(projection):
            state.productDetail?.availableShoppingLists = projection.shoppingLists
            state.productDetail?.shoppingListFlow?.availableLists = projection.shoppingLists
            return .none

        case .productDetail(.shoppingListFlow(.listSelected(let listID))):
            guard let product = state.productDetail?.shoppingListFlow?.product else {
                return .none
            }
            state.productDetail?.shoppingListFlow = nil
            return .task { .shoppingListDelegate(.addProductToList(product, listID)) }

        case .productDetail(.shoppingListFlow(.createListConfirmed)):
            guard let flow = state.productDetail?.shoppingListFlow else {
                return .none
            }
            state.productDetail?.shoppingListFlow = nil
            return .task { .shoppingListDelegate(.createList(name: flow.draftListName, product: flow.product)) }

        default:
            return .none
        }
    })

    static let reducer: Reducer<State, Action> = .combine(
        SharedLoginDomain.makeReducer(adapter: loginAdapter),
        SharedCartDomain.makeReducer(adapter: cartAdapter),
        SharedShoppingListDomain.makeReducer(adapter: shoppingListAdapter),
        featureReducer
    )
}

typealias HomeState = HomeDomain.State
typealias HomeAction = HomeDomain.Action

let homeReducer = HomeDomain.reducer
