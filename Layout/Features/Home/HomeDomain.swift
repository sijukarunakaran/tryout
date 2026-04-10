import Foundation
import StateKit

@CasePathable
enum HomeAction: Sendable {
    case productTapped(Product.ID)
    case addToListTapped(Product, hasExistingLists: Bool)
    case productDetail(ProductDetailAction)
    case shoppingListFlow(ShoppingListFlowAction)
}

struct HomeState: Sendable {
    var products = Product.catalog
    var productDetail: ProductDetailState?
    var shoppingListFlow: ShoppingListFlowState?
}

let homeReducer = Reducer<HomeState, HomeAction>.combine(
    productDetailReducer.optional.scope(
        state: \.productDetail,
        action: HomeAction.productDetail
    ),
    shoppingListFlowReducer.optional.scope(
        state: \.shoppingListFlow,
        action: HomeAction.shoppingListFlow
    ),
    Reducer<HomeState, HomeAction> { state, action in
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

extension HomeState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.productDetail == rhs.productDetail
            && lhs.shoppingListFlow == rhs.shoppingListFlow
    }
}
