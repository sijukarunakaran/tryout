import StateKit
import SwiftUI

struct AppRootView: View {
    @State private var store = Store<AppState, AppAction>(
        initialState: AppState(),
        reducer: AppDomain.reducer
    )

    var body: some View {
        let loginStore = store.ifLet(
            state: \.navigation.login,
            action: AppAction.login
        )
        let shoppingListFlowStore = store.ifLet(
            state: \.navigation.shoppingListFlow,
            action: { AppAction.navigation(.shoppingListFlow($0)) }
        )
        let homeStore = store.scope(
            state: { @Sendable appState in
                appState.home
            },
            action: AppAction.home
        )
        let browseStore = store.scope(
            state: { @Sendable appState in
                appState.browse
            },
            action: AppAction.browse
        )
        let cartStore = store.scope(
            state: { @Sendable appState in
                appState.cart
            },
            action: AppAction.cart
        )
        let shoppingListStore = store.scope(
            state: { @Sendable appState in
                appState.shoppingList
            },
            action: AppAction.shoppingList
        )

        TabView(
            selection: store.binding(
                state: \.navigation.selectedTab,
                action: { AppAction.navigation(.selectTab($0)) }
            )
        ) {
            HomeView(store: homeStore)
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            BrowseView(store: browseStore)
            .tabItem {
                Label("Browse", systemImage: "square.grid.2x2.fill")
            }
            .tag(AppTab.browse)

            CartView(
                store: cartStore
            )
            .tabItem {
                Label("Cart", systemImage: "cart.fill")
            }
            .tag(AppTab.cart)
            .badge(cartItemCount)

            ShoppingListView(
                store: shoppingListStore
            )
            .tabItem {
                Label("Lists", systemImage: "list.bullet.clipboard")
            }
            .tag(AppTab.shoppingLists)
        }
        .tint(Color(red: 0.13, green: 0.39, blue: 0.28))
        .onOpenURL { url in
            store.send(.navigation(.openURL(url)))
        }
        .sheet(
            item: store.binding(state: \.navigation.login, action: .login(.cancelTapped))
        ) { _ in
            if let loginStore {
                LoginView(store: loginStore)
            }
        }
        .sheet(
            item: store.binding(
                state: \.navigation.shoppingListFlow,
                action: AppAction.navigation(.dismissShoppingListFlow)
            )
        ) { _ in
            if let shoppingListFlowStore {
                ShoppingListFlowSheet(store: shoppingListFlowStore)
            }
        }
    }

    private var cartItemCount: Int {
        store.state.cart.items.reduce(0) { $0 + $1.quantity }
    }
}

#Preview {
    AppRootView()
}
