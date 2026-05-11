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
        // MARK: - Navigation path bridging (feature → NavigationDomain) + flow modal + stack sync
        .on(Action.navigation) { state, navAction in
            if case .shoppingListFlow(.listSelected(let listID)) = navAction {
                guard let product = state.navigation.shoppingListFlow?.product else { return .none }
                state.navigation.shoppingListFlow = nil
                return .task { [product] in [
                    .shoppingList(.addProductToList(product, listID)),
                    .navigation(.dismissShoppingListFlow)
                ]}
            }
            if case .shoppingListFlow(.createListConfirmed) = navAction {
                guard let flow = state.navigation.shoppingListFlow else { return .none }
                state.navigation.shoppingListFlow = nil
                return .task { [flow] in [
                    .shoppingList(.createList(name: flow.draftListName, product: flow.product)),
                    .navigation(.dismissShoppingListFlow)
                ]}
            }
            // Sync navigation stacks back to feature domains so views
            // driven by their scoped stores stay in sync (e.g. deep links).
            state.home.navigationPath = state.navigation.homeStack
            state.browse.navigationPath = state.navigation.browseStack
            return .none
        },

        // MARK: - Home action cross-domain handling
        .on(Action.home) { state, homeAction in
            if case let .setNavigationPath(path) = homeAction {
                state.navigation.homeStack = path
                return .none
            }
            if case let .shoppingListDelegate(.addToListRequested(product, lists)) = homeAction {
                return handleAddToListRequested(&state, product: product, availableLists: lists)
            }
            if case let .shoppingListDelegate(delegate) = homeAction {
                return handleShoppingListDelegate(&state, delegate: delegate)
            }
            if case let .cartDelegate(.addToCart(product)) = homeAction {
                return handleAddToCart(&state, product: product)
            }
            return .none
        },

        // MARK: - Browse action cross-domain handling
        .on(Action.browse) { state, browseAction in
            if case let .setNavigationPath(path) = browseAction {
                state.navigation.browseStack = path
                return .none
            }
            if case let .shoppingListDelegate(.addToListRequested(product, lists)) = browseAction {
                return handleAddToListRequested(&state, product: product, availableLists: lists)
            }
            if case let .shoppingListDelegate(delegate) = browseAction {
                return handleShoppingListDelegate(&state, delegate: delegate)
            }
            if case let .cartDelegate(.addToCart(product)) = browseAction {
                return handleAddToCart(&state, product: product)
            }
            return .none
        },

        // MARK: - Shopping list: create list from tab + projection fanout
        .on(Action.shoppingList) { state, shoppingListAction in
            if case .delegate(.createListTapped) = shoppingListAction {
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
            }
            let projection = SharedShoppingListDomain.makeProjection(
                shoppingLists: state.shoppingList.lists
            )
            return .task { shoppingListProjectionActions(for: projection) }
        },

        // MARK: - Cart projection fanout
        .on(Action.cart) { state, _ in
            let projection = SharedCartDomain.makeProjection(cart: state.cart)
            return .task { cartProjectionActions(for: projection) }
        },

        // MARK: - Login delegates
        .on(Action.login) { state, loginAction in
            if case .delegate(.signedIn) = loginAction {
                state.isAuthenticated = true
                state.navigation.login = nil
                let authActions = authProjectionActions(isAuthenticated: true)
                if let pendingAction = state.pendingProtectedAction {
                    state.pendingProtectedAction = nil
                    switch pendingAction {
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
                        return .task { authActions + [mapAction(for: pendingAction)] }
                    }
                }
                return .task { authActions }
            }
            if case .delegate(.cancelled) = loginAction {
                state.navigation.login = nil
                state.pendingProtectedAction = nil
                return .none
            }
            return .none
        }
    )

    private static func handleAddToListRequested(
        _ state: inout State,
        product: Product,
        availableLists: [ShoppingList]
    ) -> Effect<Action> {
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
            mode: availableLists.isEmpty ? .create : .picker,
            availableLists: availableLists
        )
        return .none
    }

    private static func handleShoppingListDelegate(
        _ state: inout State,
        delegate: SharedShoppingListDomain.Delegate
    ) -> Effect<Action> {
        guard state.isAuthenticated else {
            let action = protectedAction(for: delegate)
            state.pendingProtectedAction = action
            if state.navigation.login == nil {
                state.navigation.login = LoginState(id: UUID())
            }
            return .none
        }
        return .task { shoppingListAction(for: delegate) }
    }

    private static func handleAddToCart(_ state: inout State, product: Product) -> Effect<Action> {
        guard state.isAuthenticated else {
            state.pendingProtectedAction = .addToCart(product)
            if state.navigation.login == nil {
                state.navigation.login = LoginState(id: UUID())
            }
            return .none
        }
        return .task { .cart(.add(product)) }
    }

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
