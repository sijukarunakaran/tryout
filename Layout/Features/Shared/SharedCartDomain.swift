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
        var projectionUpdated: CasePath<Action, Projection>
        var addToCartTapped: CasePath<Action, Product>
        var delegate: CasePath<Action, Delegate>
    }

    static func makeReducer<
        State: SharedCartDomain.State,
        Action: Sendable
    >(
        adapter: ActionAdapter<Action>
    ) -> Reducer<State, Action> {
        Reducer<State, Action> { state, action in
            if let projection = adapter.projectionUpdated.extract(action) {
                state.cartQuantities = projection.cartQuantities
                return .none
            }

            if let product = adapter.addToCartTapped.extract(action) {
                return .task { adapter.delegate.embed(.addToCart(product)) }
            }

            return .none
        }
    }

    static func makeProjection(cart: CartState) -> Projection {
        Projection(
            cartQuantities: Dictionary(
                uniqueKeysWithValues: cart.items.map { ($0.product.id, $0.quantity) }
            )
        )
    }
}
