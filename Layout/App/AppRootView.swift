import StateKit
import SwiftUI

struct AppRootView: View {
    @StateObject private var store = Store(
        initialState: AppState(),
        reducer: AppDomain.reducer
    )

    var body: some View {
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
                get: \.selectedTab,
                send: AppAction.selectedTabChanged
            )
        ) {
            HomeView(
                store: homeStore
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)
            
            BrowseView(
                store: browseStore
            )
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
    }

    private var cartItemCount: Int {
        store.state.cart.items.reduce(0) { $0 + $1.quantity }
    }
}

#Preview {
    AppRootView()
}
