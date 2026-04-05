import StateKit

@CasePathable
enum HomeAction: Sendable {
    case productTapped(Product.ID)
    case productDetail(ProductDetailAction)
}

enum ProductDetailAction: Sendable {
    case dismissed
}

@CasePathable
enum AppAction: Sendable {
    case selectedTabChanged(AppTab)
    case home(HomeAction)
    case cart(CartAction)
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

let productDetailReducer = Reducer<ProductDetailState, ProductDetailAction> { _, _ in
    .none
}

let appReducer = Reducer<AppState, AppAction>.combine(
    homeReducer.scope(
        state: \.home,
        action: AppAction.home
    ),
    cartReducer.scope(
        state: \.cart,
        action: AppAction.cart
    ),
    Reducer<AppState, AppAction> { state, action in
        switch action {
        case let .selectedTabChanged(tab):
            state.selectedTab = tab
            return .none

        case .cart:
            return .none

        case .home:
            return .none
        }
    }
)
