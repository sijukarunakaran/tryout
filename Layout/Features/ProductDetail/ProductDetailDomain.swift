import Foundation
import StateKit

@CasePathable
enum ProductDetailAction: Sendable {
    case dismissed
    case addToListTapped(Bool)
    case shoppingListFlow(ShoppingListFlowAction)
}

struct ProductDetailState: Identifiable, Sendable {
    var product: Product
    var shoppingListFlow: ShoppingListFlowState?

    var id: Product.ID {
        product.id
    }
}

let productDetailReducer = Reducer<ProductDetailState, ProductDetailAction>.combine(
    shoppingListFlowReducer.optional.scope(
        state: \.shoppingListFlow,
        action: ProductDetailAction.shoppingListFlow
    ),
    Reducer<ProductDetailState, ProductDetailAction> { state, action in
        switch action {
        case let .addToListTapped(hasExistingLists):
            state.shoppingListFlow = ShoppingListFlowState(
                id: UUID(),
                product: state.product,
                mode: hasExistingLists ? .picker : .create
            )
            return .none

        case .shoppingListFlow(.dismissed):
            state.shoppingListFlow = nil
            return .none

        case .dismissed, .shoppingListFlow:
            return .none
        }
    }
)

extension ProductDetailState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product == rhs.product
            && lhs.shoppingListFlow == rhs.shoppingListFlow
    }
}
