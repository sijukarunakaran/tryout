import Foundation
import StateKit

@Feature
enum AppDomain {
    @NonisolatedEquatable
    struct State: Sendable {
        var navigation = NavigationState()
        var isAuthenticated = false
        var pendingProtectedAction: SharedLoginDomain.ProtectedAction?
        var browse = BrowseState()
        var home = HomeState()
        var cart = CartState()
        var shoppingList = ShoppingListState()
    }

    @CasePathable
    enum Action: Sendable {
        case navigation(NavigationAction)
        case browse(BrowseAction)
        case home(HomeAction)
        case cart(CartAction)
        case shoppingList(ShoppingListAction)
        case login(LoginAction)
    }

    static let reducer = Reducer<State, Action>.combine(
        LoginDomain.reducer.optional.scope(
            state: \.navigation.login,
            action: Action.login
        ),
        NavigationDomain.reducer.scope(
            state: \.navigation,
            action: Action.navigation
        ),
        BrowseDomain.reducer.scope(
            state: \.browse,
            action: Action.browse
        ),
        HomeDomain.reducer.scope(
            state: \.home,
            action: Action.home
        ),
        CartDomain.reducer.scope(
            state: \.cart,
            action: Action.cart
        ),
        ShoppingListDomain.reducer.scope(
            state: \.shoppingList,
            action: Action.shoppingList
        ),
        Reducer<State, Action> { state, action in
            switch action {

            // MARK: - Shopping list flow delegate (add to list from Home/Browse)

            case let .home(.shoppingListDelegate(.addToListRequested(product, lists))),
                let .browse(.shoppingListDelegate(.addToListRequested(product, lists))):
                guard state.isAuthenticated else {
                    state.pendingProtectedAction = .addToList(product)
                    if state.navigation.login == nil {
                        state.navigation.login = LoginState(id: UUID())
                    }
                    return .none
                }
                state.navigation.shoppingListFlow = ShoppingListFlowState(
                    id: UUID(),
                    product: product,
                    mode: lists.isEmpty ? .create : .picker,
                    availableLists: lists
                )
                return .none

            case let .home(.shoppingListDelegate(delegate)),
                let .browse(.shoppingListDelegate(delegate)):
                guard state.isAuthenticated else {
                    let protectedAction = protectedAction(for: delegate)
                    state.pendingProtectedAction = protectedAction
                    if state.navigation.login == nil {
                        state.navigation.login = LoginState(id: UUID())
                    }
                    return .none
                }
                return .task { shoppingListAction(for: delegate) }

            // MARK: - Create list from ShoppingList tab

            case .shoppingList(.delegate(.createListTapped)):
                guard state.isAuthenticated else {
                    state.pendingProtectedAction = .startCreateList
                    if state.navigation.login == nil {
                        state.navigation.login = LoginState(id: UUID())
                    }
                    return .none
                }
                state.navigation.shoppingListFlow = ShoppingListFlowState(
                    id: UUID(),
                    product: nil,
                    mode: .create,
                    availableLists: state.shoppingList.lists
                )
                return .none

            // MARK: - Shopping list flow modal actions

            case .navigation(.shoppingListFlow(.listSelected(let listID))):
                guard let product = state.navigation.shoppingListFlow?.product else { return .none }
                state.navigation.shoppingListFlow = nil
                return .task { [product] in [
                    .shoppingList(.addProductToList(product, listID)),
                    .navigation(.dismissShoppingListFlow)
                ]}

            case .navigation(.shoppingListFlow(.createListConfirmed)):
                guard let flow = state.navigation.shoppingListFlow else { return .none }
                state.navigation.shoppingListFlow = nil
                return .task { [flow] in [
                    .shoppingList(.createList(name: flow.draftListName, product: flow.product)),
                    .navigation(.dismissShoppingListFlow)
                ]}

            // MARK: - Cart delegates

            case let .home(.cartDelegate(.addToCart(product))),
                let .browse(.cartDelegate(.addToCart(product))),
                let .shoppingList(.cartDelegate(.addToCart(product))):
                guard state.isAuthenticated else {
                    state.pendingProtectedAction = .addToCart(product)
                    if state.navigation.login == nil {
                        state.navigation.login = LoginState(id: UUID())
                    }
                    return .none
                }
                return .task { .cart(.add(product)) }

            // MARK: - Login delegates

            case .login(.delegate(.signedIn)):
                state.isAuthenticated = true
                state.navigation.login = nil
                let authActions = authProjectionActions(isAuthenticated: true)
                if let protectedAction = state.pendingProtectedAction {
                    state.pendingProtectedAction = nil
                    switch protectedAction {
                    case .startCreateList:
                        state.navigation.shoppingListFlow = ShoppingListFlowState(
                            id: UUID(),
                            product: nil,
                            mode: .create,
                            availableLists: state.shoppingList.lists
                        )
                        return .task { authActions }

                    case .addToList(let product):
                        let lists = state.shoppingList.lists
                        state.navigation.shoppingListFlow = ShoppingListFlowState(
                            id: UUID(),
                            product: product,
                            mode: lists.isEmpty ? .create : .picker,
                            availableLists: lists
                        )
                        return .task { authActions }

                    default:
                        return .task { authActions + [mapAction(for: protectedAction)] }
                    }
                }
                return .task { authActions }

            case .login(.delegate(.cancelled)):
                state.navigation.login = nil
                state.pendingProtectedAction = nil
                return .none

            // MARK: - Projection fanout

            case .cart:
                let projection = SharedCartDomain.makeProjection(cart: state.cart)
                return .task { cartProjectionActions(for: projection) }

            case .shoppingList:
                let projection = SharedShoppingListDomain.makeProjection(
                    shoppingLists: state.shoppingList.lists
                )
                return .task { shoppingListProjectionActions(for: projection) }

            case .browse, .home, .login, .navigation:
                return .none
            }
        }
    )

    nonisolated static func shoppingListAction(
        for delegate: SharedShoppingListDomain.Delegate
    ) -> Action {
        switch delegate {
        case let .addProductToList(product, listID):
            .shoppingList(.addProductToList(product, listID))

        case let .createList(name, product):
            .shoppingList(.createList(name: name, product: product))

        case .addToListRequested:
            // Handled inline above (requires state access)
            fatalError("addToListRequested must be handled inline in the combined reducer")
        }
    }

    nonisolated static func protectedAction(
        for delegate: SharedShoppingListDomain.Delegate
    ) -> SharedLoginDomain.ProtectedAction {
        switch delegate {
        case let .addProductToList(product, listID):
            .addProductToList(product, listID)

        case let .createList(name, product):
            .createList(name: name, product: product)

        case .addToListRequested:
            fatalError("addToListRequested must be handled inline in the combined reducer")
        }
    }

    nonisolated static func mapAction(
        for protectedAction: SharedLoginDomain.ProtectedAction
    ) -> Action {
        switch protectedAction {
        case let .addToCart(product):
            .cart(.add(product))

        case let .addProductToList(product, listID):
            .shoppingList(.addProductToList(product, listID))

        case let .createList(name, product):
            .shoppingList(.createList(name: name, product: product))

        case .startCreateList, .addToList:
            // Handled inline in the combined reducer (requires state access)
            fatalError("startCreateList / addToList must be handled inline in the combined reducer")
        }
    }

    nonisolated static func cartProjectionActions(
        for projection: SharedCartDomain.Projection
    ) -> [Action] {
        [
            .home(.cartProjectionUpdated(projection)),
            .browse(.cartProjectionUpdated(projection)),
            .shoppingList(.cartProjectionUpdated(projection))
        ]
    }

    nonisolated static func authProjectionActions(
        isAuthenticated: Bool
    ) -> [Action] {
        let projection = SharedLoginDomain.Projection(isAuthenticated: isAuthenticated)
        return [
            .home(.authProjectionUpdated(projection)),
            .browse(.authProjectionUpdated(projection)),
            .shoppingList(.authProjectionUpdated(projection))
        ]
    }

    nonisolated static func shoppingListProjectionActions(
        for projection: SharedShoppingListDomain.Projection
    ) -> [Action] {
        [
            .home(.shoppingListProjectionUpdated(projection)),
            .browse(.shoppingListProjectionUpdated(projection))
        ]
    }

}

typealias AppState = AppDomain.State
typealias AppAction = AppDomain.Action

let appReducer = AppDomain.reducer
