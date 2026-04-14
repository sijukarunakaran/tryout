import StateKit

enum AppDomain: FeatureDomain {
    @NonisolatedEquatable
    struct State: Sendable {
        var selectedTab: AppTab = .home
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
    }

    static let reducer = Reducer<State, Action>.combine(
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

            case let .home(.delegate(delegate)),
                let .browse(.delegate(delegate)):
                applyCatalogDelegate(delegate, to: &state)

            case let .shoppingList(.addToCartTapped(product)):
                _ = CartDomain.reducer.reduce(&state.cart, .add(product))

            case .browse, .home, .cart, .shoppingList:
                break
            }

            syncDerivedState(&state)
            return .none
        }
    )

    static func applyCatalogDelegate(
        _ delegate: CatalogFeatureDomain.Delegate,
        to state: inout State
    ) {
        switch delegate {
        case let .addToCart(product):
            _ = CartDomain.reducer.reduce(&state.cart, .add(product))

        case let .addProductToList(product, listID):
            _ = ShoppingListDomain.reducer.reduce(
                &state.shoppingList,
                .addProductToList(product, listID)
            )

        case let .createList(name, product):
            _ = ShoppingListDomain.reducer.reduce(
                &state.shoppingList,
                .createList(name: name, product: product)
            )
        }
    }

    private static func syncDerivedState(_ state: inout State) {
        let projection = CatalogFeatureDomain.makeProjection(
            cart: state.cart,
            shoppingLists: state.shoppingList.lists
        )

        HomeDomain.syncProjection(&state.home, projection: projection)
        BrowseDomain.syncProjection(&state.browse, projection: projection)
        state.shoppingList.cartQuantities = projection.cartQuantities
    }
}

typealias AppState = AppDomain.State
typealias AppAction = AppDomain.Action

let appReducer = AppDomain.reducer
