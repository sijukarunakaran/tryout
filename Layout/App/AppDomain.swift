import Foundation
import StateKit

@Feature
enum AppDomain {
    @NonisolatedEquatable
    struct State: Sendable {
        var selectedTab: AppTab = .home
        var isAuthenticated = false
        var pendingProtectedAction: SharedLoginDomain.ProtectedAction?
        var login: LoginState?
        var browse = BrowseState()
        var home = HomeState()
        var cart = CartState()
        var shoppingList = ShoppingListState()
    }

    @CasePathable
    enum Action: Sendable {
        case selectedTabChanged(AppTab)
        case browse(BrowseAction)
        case home(HomeAction)
        case cart(CartAction)
        case shoppingList(ShoppingListAction)
        case login(LoginAction)
    }

    static let reducer = Reducer<State, Action>.combine(
        LoginDomain.reducer.optional.scope(
            state: \.login,
            action: Action.login
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
            case let .selectedTabChanged(tab):
                state.selectedTab = tab
                return .none

            case .shoppingList(.delegate(.createListTapped)):
                guard state.isAuthenticated else {
                    state.pendingProtectedAction = .startCreateList
                    if state.login == nil {
                        state.login = LoginState(id: UUID())
                    }
                    return .none
                }
                return .task { .shoppingList(.openShoppingListFlow) }

            case let .home(.cartDelegate(.addToCart(product))),
                let .browse(.cartDelegate(.addToCart(product))),
                let .shoppingList(.cartDelegate(.addToCart(product))):
                guard state.isAuthenticated else {
                    state.pendingProtectedAction = .addToCart(product)
                    if state.login == nil {
                        state.login = LoginState(id: UUID())
                    }
                    return .none
                }
                return .task { .cart(.add(product)) }

            case let .home(.shoppingListDelegate(delegate)),
                let .browse(.shoppingListDelegate(delegate)):
                guard state.isAuthenticated else {
                    let protectedAction = protectedAction(for: delegate)
                    state.pendingProtectedAction = protectedAction
                    if state.login == nil {
                        state.login = LoginState(id: UUID())
                    }
                    return .none
                }
                return .task {
                    shoppingListAction(for: delegate)
                }

            case .login(.delegate(.signedIn)):
                state.isAuthenticated = true
                state.login = nil
                let authActions = authProjectionActions(isAuthenticated: true)
                if let protectedAction = state.pendingProtectedAction {
                    state.pendingProtectedAction = nil
                    return .task {
                        authActions + [mapAction(for: protectedAction)]
                    }
                }
                return .task {
                    authActions
                }

            case .login(.delegate(.cancelled)):
                state.login = nil
                state.pendingProtectedAction = nil
                return .none

            case .cart:
                let projection = SharedCartDomain.makeProjection(cart: state.cart)
                return .task {
                    cartProjectionActions(for: projection)
                }

            case .shoppingList:
                let projection = SharedShoppingListDomain.makeProjection(
                    shoppingLists: state.shoppingList.lists
                )
                return .task {
                    shoppingListProjectionActions(for: projection)
                }

            case .browse, .home, .login:
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

        case .startCreateList:
            .shoppingList(.openShoppingListFlow)
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
