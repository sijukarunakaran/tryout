import Foundation
import Splice
import StateKit

@Feature
enum CartDomain {
    @NonisolatedEquatable
    struct State: Sendable {
        @NonisolatedEquatable
        struct CheckoutNotice: Sendable {
            @NonisolatedEquatable
            enum Tone: Sendable {
                case success
                case failure
            }

            var tone: Tone
            var message: String
        }

        var items: [CartItem] = []
        var isCheckingOut = false
        var checkoutNotice: CheckoutNotice?
    }

    enum Action: Sendable {
        case add(Product)
        case decrement(Product.ID)
        case remove(Product.ID)
        case clear
        case checkoutTapped
        case checkoutSucceeded(orderNumber: String, subtotalText: String)
        case checkoutFailed(String)
        case dismissCheckoutNotice
    }

    private struct Dependencies {
        @Dependency(OrderClient.self) var orderClient
    }

    static let reducer = Reducer<State, Action> { state, action in
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
            state.checkoutNotice = nil
            return .none

        case .checkoutTapped:
            guard state.items.isEmpty == false, state.isCheckingOut == false else {
                return .none
            }

            state.isCheckingOut = true
            state.checkoutNotice = nil

            let subtotalText = subtotal(for: state.items).formatted(.currency(code: "USD"))
            let orderClient = Dependencies().orderClient

            return .task {
                do {
                    let orderNumber = try await orderClient.placeOrder()
                    return .checkoutSucceeded(
                        orderNumber: orderNumber,
                        subtotalText: subtotalText
                    )
                } catch {
                    return .checkoutFailed(
                        error.localizedDescription.isEmpty
                            ? "Unable to place your order right now."
                            : error.localizedDescription
                    )
                }
            }

        case let .checkoutSucceeded(orderNumber, subtotalText):
            state.isCheckingOut = false
            state.items.removeAll()
            state.checkoutNotice = State.CheckoutNotice(
                tone: .success,
                message: "Order placed #\(orderNumber) · \(subtotalText)"
            )
            return .none

        case let .checkoutFailed(message):
            state.isCheckingOut = false
            state.checkoutNotice = State.CheckoutNotice(
                tone: .failure,
                message: message
            )
            return .none

        case .dismissCheckoutNotice:
            state.checkoutNotice = nil
            return .none
        }
    }

    private static func subtotal(for items: [CartItem]) -> Decimal {
        items.reduce(0) { partial, item in
            partial + (item.product.price * Decimal(item.quantity))
        }
    }
}

typealias CartState = CartDomain.State
typealias CartAction = CartDomain.Action

let cartReducer = CartDomain.reducer
