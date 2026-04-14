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
    struct State: Sendable {
        var lists: [ShoppingList] = []
        var cartQuantities: [Product.ID: Int] = [:]
        var shoppingListFlow: ShoppingListFlowState?
    }

    @CasePathable
    enum Action: Sendable {
        case createListButtonTapped
        case createList(name: String, product: Product?)
        case addProductToList(Product, ShoppingList.ID)
        case addToCartTapped(Product)
        case shoppingListFlow(ShoppingListFlowAction)
    }

    static let reducer = Reducer<State, Action>.combine(
        shoppingListFlowReducer.optional.scope(
            state: \.shoppingListFlow,
            action: Action.shoppingListFlow
        ),
        Reducer<State, Action> { state, action in
            switch action {
            case .createListButtonTapped:
                state.shoppingListFlow = ShoppingListFlowState(
                    id: UUID(),
                    product: nil,
                    mode: .create,
                    availableLists: state.lists
                )
                return .none

            case let .createList(name, product):
                let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else {
                    return .none
                }

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
                else {
                    return .none
                }

                if state.lists[index].products.contains(where: { $0.id == product.id }) == false {
                    state.lists[index].products.append(product)
                }
                state.shoppingListFlow = nil
                return .none

            case .shoppingListFlow(.createListConfirmed):
                guard let flow = state.shoppingListFlow else {
                    return .none
                }

                let trimmedName = flow.draftListName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else {
                    return .none
                }

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

            case .addToCartTapped:
                return .none

            case .shoppingListFlow:
                return .none
            }
        }
    )
}

typealias ShoppingListState = ShoppingListDomain.State
typealias ShoppingListAction = ShoppingListDomain.Action

let shoppingListReducer = ShoppingListDomain.reducer
