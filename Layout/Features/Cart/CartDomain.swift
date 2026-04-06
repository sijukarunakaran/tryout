import StateKit

struct CartState: Sendable {
    var items: [CartItem] = []
}

enum CartAction: Sendable {
    case add(Product)
    case decrement(Product.ID)
    case remove(Product.ID)
    case clear
}

let cartReducer = Reducer<CartState, CartAction> { state, action in
    switch action {
    case let .add(product):
        if let index = state.items.firstIndex(where: { $0.product.id == product.id }) {
            state.items[index].quantity += 1
        } else {
            state.items.append(CartItem(product: product, quantity: 1))
        }
        return .none

    case let .decrement(productID):
        guard let index = state.items.firstIndex(where: { $0.product.id == productID }) else {
            return .none
        }

        if state.items[index].quantity == 1 {
            state.items.remove(at: index)
        } else {
            state.items[index].quantity -= 1
        }
        return .none

    case let .remove(productID):
        state.items.removeAll { $0.product.id == productID }
        return .none

    case .clear:
        state.items.removeAll()
        return .none
    }
}

extension CartState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items
    }
}
