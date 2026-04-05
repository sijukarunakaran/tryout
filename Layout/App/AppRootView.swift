import StateKit
import SwiftUI

struct AppRootView: View {
    @StateObject private var store = Store(
        initialState: AppState(),
        reducer: appReducer
    )

    var body: some View {
        let homeStore = store.scope(
            state: { @Sendable appState in
                appState.home
            },
            action: AppAction.home
        )
        let cartStore = store.scope(
            state: { @Sendable appState in
                appState.cart
            },
            action: AppAction.cart
        )

        TabView(
            selection: store.binding(
                get: \.selectedTab,
                send: AppAction.selectedTabChanged
            )
        ) {
            HomeView(
                store: homeStore,
                cartStore: cartStore
            )
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(AppTab.home)

            CartView(
                store: cartStore
            )
            .tabItem {
                Label("Cart", systemImage: "cart.fill")
            }
            .tag(AppTab.cart)
            .badge(cartItemCount)
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
