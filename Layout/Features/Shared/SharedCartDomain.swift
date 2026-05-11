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
        .combine(
            .on(adapter.projectionUpdated) { state, projection in
                state.cartQuantities = projection.cartQuantities
                return .none
            },
            .on(adapter.addToCartTapped) { _, product in
                .task { adapter.delegate.embed(.addToCart(product)) }
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
