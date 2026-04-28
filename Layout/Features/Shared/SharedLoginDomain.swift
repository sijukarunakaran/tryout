import Foundation
import StateKit

enum SharedLoginDomain {
    protocol State: Sendable {
        var isAuthenticated: Bool { get set }
    }

    @NonisolatedEquatable
    struct Projection: Sendable {
        var isAuthenticated: Bool
    }
    
    @NonisolatedEquatable
    enum ProtectedAction: Sendable {
        case addToCart(Product)
        case addProductToList(Product, ShoppingList.ID)
        case createList(name: String, product: Product?)
        case startCreateList
    }
}
