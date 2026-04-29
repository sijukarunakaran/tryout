import Foundation

enum AppDestination: Sendable {
    case productDetail(Product)
}

extension AppDestination: Hashable {
    static func == (lhs: AppDestination, rhs: AppDestination) -> Bool {
        switch (lhs, rhs) {
        case (.productDetail(let a), .productDetail(let b)):
            a.id == b.id
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .productDetail(let product):
            hasher.combine(product.id)
        }
    }
}
