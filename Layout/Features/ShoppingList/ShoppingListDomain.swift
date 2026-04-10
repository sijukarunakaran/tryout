import Foundation
import StateKit

struct ShoppingListFlowState: Identifiable, Sendable {
    enum Mode: Sendable {
        case picker
        case create
    }

    let id: UUID
    var product: Product?
    var mode: Mode
    var draftListName = ""
}

enum ShoppingListFlowAction: Sendable {
    case createNewListTapped
    case draftListNameChanged(String)
    case dismissed
}

let shoppingListFlowReducer = Reducer<ShoppingListFlowState, ShoppingListFlowAction> { state, action in
    switch action {
    case .createNewListTapped:
        state.mode = .create
        state.draftListName = ""
        return .none

    case let .draftListNameChanged(name):
        state.draftListName = name
        return .none

    case .dismissed:
        return .none
    }
}

struct ShoppingListState: Sendable {
    var lists: [ShoppingList] = []
    var shoppingListFlow: ShoppingListFlowState?
}

@CasePathable
enum ShoppingListAction: Sendable {
    case createListButtonTapped
    case createList(name: String, product: Product?)
    case addProductToList(Product, ShoppingList.ID)
    case shoppingListFlow(ShoppingListFlowAction)
}

let shoppingListReducer = Reducer<ShoppingListState, ShoppingListAction>.combine(
    shoppingListFlowReducer.optional.scope(
        state: \.shoppingListFlow,
        action: ShoppingListAction.shoppingListFlow
    ),
    Reducer<ShoppingListState, ShoppingListAction> { state, action in
        switch action {
        case .createListButtonTapped:
            state.shoppingListFlow = ShoppingListFlowState(
                id: UUID(),
                product: nil,
                mode: .create
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

        case .shoppingListFlow(.dismissed):
            state.shoppingListFlow = nil
            return .none

        case .shoppingListFlow:
            return .none
        }
    }
)

extension ShoppingListState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.lists == rhs.lists
            && lhs.shoppingListFlow == rhs.shoppingListFlow
    }
}

extension ShoppingListFlowState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.product == rhs.product
            && lhs.mode == rhs.mode
            && lhs.draftListName == rhs.draftListName
    }
}

extension ShoppingListFlowState.Mode: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.picker, .picker), (.create, .create):
            true
        default:
            false
        }
    }
}
