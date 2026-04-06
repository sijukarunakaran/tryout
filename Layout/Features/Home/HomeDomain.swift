import StateKit

@CasePathable
enum HomeAction: Sendable {
    case productTapped(Product.ID)
    case productDetail(ProductDetailAction)
}

struct HomeState: Sendable {
    var products = Product.catalog
    var productDetail: ProductDetailState?
}

let homeReducer = Reducer<HomeState, HomeAction>.combine(
    productDetailReducer.optional.scope(
        state: \.productDetail,
        action: HomeAction.productDetail
    ),
    Reducer<HomeState, HomeAction> { state, action in
        switch action {
        case let .productTapped(productID):
            guard let product = state.products.first(where: { $0.id == productID }) else {
                return .none
            }
            state.productDetail = ProductDetailState(product: product)
            return .none

        case .productDetail(.dismissed):
            state.productDetail = nil
            return .none

        case .productDetail:
            return .none
        }
    }
)

extension HomeState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.productDetail == rhs.productDetail
    }
}
