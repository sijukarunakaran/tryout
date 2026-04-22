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
        var products: [Product] { get set }
        var isAuthenticated: Bool { get set }
        var cartQuantities: [Product.ID: Int] { get set }
        var availableShoppingLists: [ShoppingList] { get }
        var productDetail: ProductDetailState? { get set }
    }

    struct ActionAdapter<Action: Sendable> {
        var authProjectionUpdated: @Sendable (Action) -> SharedLoginDomain.Projection?
        var projectionUpdated: @Sendable (Action) -> Projection?
        var productTapped: @Sendable (Action) -> Product.ID?
        var addToCartTapped: @Sendable (Action) -> Product?
        var productDetail: CasePath<Action, ProductDetailAction>
        var loginRequired: @Sendable (SharedLoginDomain.ProtectedAction) -> Action
        var delegate: @Sendable (Delegate) -> Action
    }

    static func makeReducer<State: SharedCartDomain.State, Action: Sendable>(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer<State, Action>.combine(
            productDetailReducer.optional.scope(
                state: \.productDetail,
                action: adapter.productDetail
            ),
            Reducer<State, Action> { state, action in
                if let authProjection = adapter.authProjectionUpdated(action) {
                    state.isAuthenticated = authProjection.isAuthenticated
                    return .none
                }

                if let projection = adapter.projectionUpdated(action) {
                    state.cartQuantities = projection.cartQuantities

                    if var detail = state.productDetail {
                        detail.cartQuantity = projection.cartQuantities[detail.product.id] ?? 0
                        state.productDetail = detail
                    }
                    return .none
                }

                if let productID = adapter.productTapped(action) {
                    guard let product = state.products.first(where: { $0.id == productID }) else {
                        return .none
                    }
                    state.productDetail = ProductDetailState(
                        product: product,
                        cartQuantity: state.cartQuantities[product.id] ?? 0,
                        availableShoppingLists: state.availableShoppingLists
                    )
                    return .none
                }

                if let product = adapter.addToCartTapped(action) {
                    guard state.isAuthenticated else {
                        return .task {
                            adapter.loginRequired(.addToCart(product))
                        }
                    }
                    return .task {
                        adapter.delegate(.addToCart(product))
                    }
                }

                if let detailAction = adapter.productDetail.extract(action) {
                    switch detailAction {
                    case let .addToCartTapped(product):
                        guard state.isAuthenticated else {
                            return .task {
                                adapter.loginRequired(.addToCart(product))
                            }
                        }
                        return .task {
                            adapter.delegate(.addToCart(product))
                        }

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
