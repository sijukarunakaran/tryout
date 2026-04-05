struct HomeState: Sendable {
    var products = Product.catalog
    var productDetail: ProductDetailState?
}

struct ProductDetailState: Identifiable, Sendable {
    var product: Product

    var id: Product.ID {
        product.id
    }
}

struct AppState: Sendable {
    var selectedTab: AppTab = .home
    var home = HomeState()
    var cart = CartState()
}

extension HomeState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.productDetail == rhs.productDetail
    }
}

extension ProductDetailState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product == rhs.product
    }
}

extension AppState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.home == rhs.home
            && lhs.cart == rhs.cart
    }
}
