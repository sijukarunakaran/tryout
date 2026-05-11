import Foundation
import StateKit

@Feature
enum ShoppingListFlowDomain {
    @NonisolatedEquatable
    struct State: Identifiable, Sendable {
        @NonisolatedEquatable
        enum Mode: Sendable {
            case picker
            case create
        }

        let id: UUID
        var product: Product?
        var mode: Mode
        var draftListName = ""
        var availableLists: [ShoppingList] = []
    }

    @CasePathable
    enum Action: Sendable {
        case createNewListTapped
        case draftListNameChanged(String)
        case listSelected(ShoppingList.ID)
        case createListConfirmed
        case dismissed
    }

    static let reducer = Reducer<State, Action>.combine(
        .on(matching: { if case .createNewListTapped = $0 { return true }; return false }) { state in
            state.mode = .create
            state.draftListName = ""
            return .none
        },
        .on(Action.draftListNameChanged) { state, name in
            state.draftListName = name
            return .none
        }
    )
}

typealias ShoppingListFlowState = ShoppingListFlowDomain.State
typealias ShoppingListFlowAction = ShoppingListFlowDomain.Action

let shoppingListFlowReducer = ShoppingListFlowDomain.reducer

@Feature
enum ShoppingListDomain {
    @NonisolatedEquatable
    struct State: SharedLoginDomain.State, SharedCartDomain.State, Sendable {
        var isAuthenticated = false
        var lists: [ShoppingList] = []
        var cartQuantities: [Product.ID: Int] = [:]
    }

    enum Delegate: Sendable {
        case createListTapped
    }

    @CasePathable
    enum Action: Sendable {
        case authProjectionUpdated(SharedLoginDomain.Projection)
        case cartProjectionUpdated(SharedCartDomain.Projection)
        case createListButtonTapped
        case createList(name: String, product: Product?)
        case addProductToList(Product, ShoppingList.ID)
        case addToCartTapped(Product)
        case cartDelegate(SharedCartDomain.Delegate)
        case delegate(Delegate)
    }

    static var loginAdapter: SharedLoginDomain.ActionAdapter<Action> {
        SharedLoginDomain.ActionAdapter(projectionUpdated: Action.authProjectionUpdated)
    }

    static var cartAdapter: SharedCartDomain.ActionAdapter<Action> {
        SharedCartDomain.ActionAdapter(
            projectionUpdated: Action.cartProjectionUpdated,
            addToCartTapped: Action.addToCartTapped,
            delegate: Action.cartDelegate
        )
    }

    static let featureReducer = Reducer<State, Action>.combine(
        .on(matching: { if case .createListButtonTapped = $0 { return true }; return false }) { _ in
            .task { .delegate(.createListTapped) }
        },
        .on(
            extract: { if case let .createList(name, product) = $0 { return (name, product) }; return nil }
        ) { state, args in
            let (name, product) = args
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedName.isEmpty == false else { return .none }
            state.lists.append(
                ShoppingList(
                    id: UUID(),
                    name: trimmedName,
                    products: product.map { [$0] } ?? []
                )
            )
            return .none
        },
        .on(
            extract: { if case let .addProductToList(product, listID) = $0 { return (product, listID) }; return nil }
        ) { state, args in
            let (product, listID) = args
            guard let index = state.lists.firstIndex(where: { $0.id == listID }) else {
                return .none
            }
            if state.lists[index].products.contains(where: { $0.id == product.id }) == false {
                state.lists[index].products.append(product)
            }
            return .none
        }
    )

    static let reducer: Reducer<State, Action> = .combine(
        SharedLoginDomain.makeReducer(adapter: loginAdapter),
        SharedCartDomain.makeReducer(adapter: cartAdapter),
        featureReducer
    )
}

typealias ShoppingListState = ShoppingListDomain.State
typealias ShoppingListAction = ShoppingListDomain.Action

let shoppingListReducer = ShoppingListDomain.reducer
