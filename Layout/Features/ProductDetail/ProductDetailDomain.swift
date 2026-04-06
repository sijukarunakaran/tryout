import StateKit

enum ProductDetailAction: Sendable {
    case dismissed
}

struct ProductDetailState: Identifiable, Sendable {
    var product: Product

    var id: Product.ID {
        product.id
    }
}

let productDetailReducer = Reducer<ProductDetailState, ProductDetailAction> { _, _ in
    .none
}

extension ProductDetailState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product == rhs.product
    }
}
