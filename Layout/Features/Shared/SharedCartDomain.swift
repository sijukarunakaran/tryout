import Foundation
import StateKit

enum SharedCartDomain {
    enum Delegate: Sendable {
        case addToCart(Product)
    }

    struct Projection: Sendable {
        var cartQuantities: [Product.ID: Int]
    }

    protocol State: Sendable {
        var cartQuantities: [Product.ID: Int] { get set }
    }

    struct ActionAdapter<Action: Sendable> {
        var authProjectionUpdated: CasePath<Action, SharedLoginDomain.Projection>
        var projectionUpdated: CasePath<Action, Projection>
        var productTapped: CasePath<Action, Product>
        var addToCartTapped: CasePath<Action, Product>
        var productDetail: CasePath<Action, ProductDetailAction>
        var loginRequired: CasePath<Action, SharedLoginDomain.ProtectedAction>
        var delegate: CasePath<Action, Delegate>
    }

    static func makeReducer<
        State: SharedCartDomain.State & SharedLoginDomain.State & SharedShoppingListDomain.State,
        Action: Sendable
    >(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        func addToCart(_ product: Product, isAuthenticated: Bool) -> Effect<Action> {
            guard isAuthenticated else {
                return .task { adapter.loginRequired.embed(.addToCart(product)) }
            }
            return .task { adapter.delegate.embed(.addToCart(product)) }
        }

        return Reducer<State, Action>.combine(
            productDetailReducer.optional.scope(
                state: \.productDetail,
                action: adapter.productDetail
            ),
            Reducer<State, Action> { state, action in
                if let authProjection = adapter.authProjectionUpdated.extract(action) {
                    state.isAuthenticated = authProjection.isAuthenticated
                    return .none
                }

                if let projection = adapter.projectionUpdated.extract(action) {
                    state.cartQuantities = projection.cartQuantities

                    if var detail = state.productDetail {
                        detail.cartQuantity = projection.cartQuantities[detail.product.id] ?? 0
                        state.productDetail = detail
                    }
                    return .none
                }

                if let product = adapter.productTapped.extract(action) {
                    state.productDetail = ProductDetailState(
                        product: product,
                        cartQuantity: state.cartQuantities[product.id] ?? 0,
                        availableShoppingLists: state.availableShoppingLists
                    )
                    return .none
                }

                if let product = adapter.addToCartTapped.extract(action) {
                    return addToCart(product, isAuthenticated: state.isAuthenticated)
                }

                if let detailAction = adapter.productDetail.extract(action) {
                    switch detailAction {
                    case let .addToCartTapped(product):
                        return addToCart(product, isAuthenticated: state.isAuthenticated)

                    case .dismissed:
                        state.productDetail = nil
                        return .none

                    case .addToListTapped, .shoppingListFlow:
                        return .none
                    }
                }

                return .none
            }
        )
    }

    static func makeProjection(cart: CartState) -> Projection {
        Projection(
            cartQuantities: Dictionary(
                uniqueKeysWithValues: cart.items.map { ($0.product.id, $0.quantity) }
            )
        )
    }
}
