import Foundation
import StateKit

enum SharedLoginDomain {
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
