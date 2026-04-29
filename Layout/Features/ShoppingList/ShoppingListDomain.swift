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

    enum Action: Sendable {
        case createNewListTapped
        case draftListNameChanged(String)
        case listSelected(ShoppingList.ID)
        case createListConfirmed
        case dismissed
    }

    static let reducer = Reducer<State, Action> { state, action in
        switch action {
        case .createNewListTapped:
            state.mode = .create
            state.draftListName = ""
            return .none

        case let .draftListNameChanged(name):
            state.draftListName = name
            return .none

        case .listSelected, .createListConfirmed, .dismissed:
            return .none
        }
    }
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
        var shoppingListFlow: ShoppingListFlowState?
    }

    enum Delegate: Sendable {
        case createListTapped
    }

    @CasePathable
    enum Action: Sendable {
        case authProjectionUpdated(SharedLoginDomain.Projection)
        case cartProjectionUpdated(SharedCartDomain.Projection)
        case createListButtonTapped
        case openShoppingListFlow
        case createList(name: String, product: Product?)
        case addProductToList(Product, ShoppingList.ID)
        case addToCartTapped(Product)
        case shoppingListFlow(ShoppingListFlowAction)
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
        shoppingListFlowReducer.optional.scope(
            state: \.shoppingListFlow,
            action: Action.shoppingListFlow
        ),
        Reducer<State, Action> { state, action in
            switch action {
            case .createListButtonTapped:
                return .task { .delegate(.createListTapped) }

            case .openShoppingListFlow:
                state.shoppingListFlow = ShoppingListFlowState(
                    id: UUID(),
                    product: nil,
                    mode: .create,
                    availableLists: state.lists
                )
                return .none

            case let .createList(name, product):
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { return .none }
                state.lists.append(
                    ShoppingList(
                        id: UUID(),
                        name: trimmedName,
                        products: product.map { [$0] } ?? []
                    )
                )
                state.shoppingListFlow = nil
                return .none

            case let .addProductToList(product, listID):
                guard let index = state.lists.firstIndex(where: { $0.id == listID }) else {
                    return .none
                }
                if state.lists[index].products.contains(where: { $0.id == product.id }) == false {
                    state.lists[index].products.append(product)
                }
                return .none

            case let .shoppingListFlow(.listSelected(listID)):
                guard
                    let product = state.shoppingListFlow?.product,
                    let index = state.lists.firstIndex(where: { $0.id == listID })
                else { return .none }
                if state.lists[index].products.contains(where: { $0.id == product.id }) == false {
                    state.lists[index].products.append(product)
                }
                state.shoppingListFlow = nil
                return .none

            case .shoppingListFlow(.createListConfirmed):
                guard let flow = state.shoppingListFlow else { return .none }
                let trimmedName = flow.draftListName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { return .none }
                state.lists.append(
                    ShoppingList(
                        id: UUID(),
                        name: trimmedName,
                        products: flow.product.map { [$0] } ?? []
                    )
                )
                state.shoppingListFlow = nil
                return .none

            case .shoppingListFlow(.dismissed):
                state.shoppingListFlow = nil
                return .none

            case .authProjectionUpdated, .cartProjectionUpdated, .addToCartTapped,
                 .cartDelegate, .delegate, .shoppingListFlow:
                return .none
            }
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
