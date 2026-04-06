import StateKit

struct BrowseState: Sendable {
    var products = Product.catalog
    var productDetail: ProductDetailState?
}

@CasePathable
enum BrowseAction: Sendable {
    case productTapped(Product.ID)
    case productDetail(ProductDetailAction)
}

let browseReducer = Reducer<BrowseState, BrowseAction>.combine(
    productDetailReducer.optional.scope(
        state: \.productDetail,
        action: BrowseAction.productDetail
    ),
    Reducer<BrowseState, BrowseAction> { state, action in
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

extension BrowseState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.productDetail == rhs.productDetail
    }
}
