import StateKit
import SwiftUI

@NonisolatedEquatable
struct Product: Identifiable, Sendable {
    let id: UUID
    var category: ProductCategory
    var name: String
    var subtitle: String
    var price: Decimal
    var accentColor: ColorToken
}

@NonisolatedEquatable
struct CartItem: Identifiable, Sendable {
    var product: Product
    var quantity: Int

    var id: Product.ID {
        product.id
    }
}

@NonisolatedEquatable
struct ShoppingList: Identifiable, Sendable {
    let id: UUID
    var name: String
    var products: [Product]
}

enum ColorToken: String, CaseIterable, Sendable {
    case citrus
    case sky
    case coral
    case mint
    case amber

    var primary: Color {
        switch self {
        case .citrus:
            Color(red: 0.61, green: 0.70, blue: 0.19)
        case .sky:
            Color(red: 0.20, green: 0.50, blue: 0.76)
        case .coral:
            Color(red: 0.84, green: 0.41, blue: 0.33)
        case .mint:
            Color(red: 0.18, green: 0.58, blue: 0.46)
        case .amber:
            Color(red: 0.78, green: 0.55, blue: 0.16)
        }
    }

    var secondary: Color {
        primary.opacity(0.18)
    }
}

enum AppTab: Sendable {
    case home
    case browse
    case cart
    case shoppingLists
}

enum ProductCategory: String, CaseIterable, Sendable {
    case fruit
    case bakery
    case beverages

    var title: String {
        switch self {
        case .fruit:
            "Fruit"
        case .bakery:
            "Bakery"
        case .beverages:
            "Beverages"
        }
    }
}

extension Product {
    static let catalog: [Product] = [
        Product(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            category: .fruit,
            name: "Avocados",
            subtitle: "Creamy, ripe, 4 pack",
            price: 6.50,
            accentColor: .mint
        ),
        Product(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            category: .fruit,
            name: "Strawberries",
            subtitle: "Sweet morning harvest",
            price: 5.25,
            accentColor: .coral
        ),
        Product(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            category: .bakery,
            name: "Sourdough",
            subtitle: "Fresh baked artisan loaf",
            price: 4.80,
            accentColor: .amber
        ),
        Product(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            category: .beverages,
            name: "Cold Brew",
            subtitle: "Smooth roast, 1 liter",
            price: 7.40,
            accentColor: .sky
        ),
        Product(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            category: .fruit,
            name: "Lemons",
            subtitle: "Bright citrus bag",
            price: 3.60,
            accentColor: .citrus
        ),
    ]
}

extension ColorToken: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension AppTab: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.browse, .browse), (.cart, .cart), (.shoppingLists, .shoppingLists):
            true
        default:
            false
        }
    }
}

extension ProductCategory: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}
