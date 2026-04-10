import Foundation
import StateKit

struct BrowseState: Sendable {
    var products = Product.catalog
    var productDetail: ProductDetailState?
    var shoppingListFlow: ShoppingListFlowState?
}

@CasePathable
enum BrowseAction: Sendable {
    case productTapped(Product.ID)
    case addToListTapped(Product, hasExistingLists: Bool)
    case productDetail(ProductDetailAction)
    case shoppingListFlow(ShoppingListFlowAction)
}

let browseReducer = Reducer<BrowseState, BrowseAction>.combine(
    productDetailReducer.optional.scope(
        state: \.productDetail,
        action: BrowseAction.productDetail
    ),
    shoppingListFlowReducer.optional.scope(
        state: \.shoppingListFlow,
        action: BrowseAction.shoppingListFlow
    ),
    Reducer<BrowseState, BrowseAction> { state, action in
        switch action {
        case let .productTapped(productID):
            guard let product = state.products.first(where: { $0.id == productID }) else {
                return .none
            }
            state.productDetail = ProductDetailState(product: product)
            return .none

        case let .addToListTapped(product, hasExistingLists):
            state.shoppingListFlow = ShoppingListFlowState(
                id: UUID(),
                product: product,
                mode: hasExistingLists ? .picker : .create
            )
            return .none

        case .productDetail(.dismissed):
            state.productDetail = nil
            return .none

        case .shoppingListFlow(.dismissed):
            state.shoppingListFlow = nil
            return .none

        case .productDetail, .shoppingListFlow:
            return .none
        }
    }
)

extension BrowseState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.productDetail == rhs.productDetail
            && lhs.shoppingListFlow == rhs.shoppingListFlow
    }
}
