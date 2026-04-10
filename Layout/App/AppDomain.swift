import StateKit

struct AppState: Sendable {
    var selectedTab: AppTab = .home
    var browse = BrowseState()
    var home = HomeState()
    var cart = CartState()
    var shoppingList = ShoppingListState()
}

@CasePathable
enum AppAction: Sendable {
    case selectedTabChanged(AppTab)
    case browse(BrowseAction)
    case home(HomeAction)
    case cart(CartAction)
    case shoppingList(ShoppingListAction)
}

let appReducer = Reducer<AppState, AppAction>.combine(
    browseReducer.scope(
        state: \.browse,
        action: AppAction.browse
    ),
    homeReducer.scope(
        state: \.home,
        action: AppAction.home
    ),
    cartReducer.scope(
        state: \.cart,
        action: AppAction.cart
    ),
    shoppingListReducer.scope(
        state: \.shoppingList,
        action: AppAction.shoppingList
    ),
    Reducer<AppState, AppAction> { state, action in
        switch action {
        case let .selectedTabChanged(tab):
            state.selectedTab = tab
            return .none

        case .browse, .cart, .shoppingList:
            return .none

        case .home:
            return .none
        }
    }
)

extension AppState: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.browse == rhs.browse
            && lhs.home == rhs.home
            && lhs.cart == rhs.cart
            && lhs.shoppingList == rhs.shoppingList
    }
}
