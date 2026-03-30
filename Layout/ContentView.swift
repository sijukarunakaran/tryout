import StateKit
import SwiftUI

struct ContentView: View {
    @StateObject private var store = Store(
        initialState: AppState(),
        reducer: appReducer
    )

    var body: some View {
        TabView(
            selection: store.binding(
                get: \.selectedTab,
                send: AppAction.selectedTabChanged
            )
        ) {
            HomeView(
                store: store.scope(
                    state: { HomeViewState(appState: $0) },
                    action: AppAction.home
                )
            )
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppTab.home)

            CartView(
                store: store.scope(
                    state: { appState in
                        appState.cart
                    },
                    action: AppAction.cart
                )
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

private struct Product: Identifiable, Sendable {
    let id: UUID
    var name: String
    var subtitle: String
    var price: Decimal
    var accentColor: ColorToken
}

private struct CartItem: Identifiable, Sendable {
    var product: Product
    var quantity: Int

    var id: UUID {
        product.id
    }
}

private enum ColorToken: String, CaseIterable, Sendable {
    case citrus
    case sky
    case coral
    case mint
    case amber

    var primary: Color {
        switch self {
        case .citrus:
            Color(red: 0.61, green: 0.70, blue: 0.19)
        case .sky:
            Color(red: 0.20, green: 0.50, blue: 0.76)
        case .coral:
            Color(red: 0.84, green: 0.41, blue: 0.33)
        case .mint:
            Color(red: 0.18, green: 0.58, blue: 0.46)
        case .amber:
            Color(red: 0.78, green: 0.55, blue: 0.16)
        }
    }

    var secondary: Color {
        primary.opacity(0.18)
    }
}

private enum AppTab: Sendable {
    case home
    case cart
}

private struct CartState: Sendable {
    var items: [CartItem] = []
}

private struct HomeState: Sendable {
    var products = Product.catalog
    var selectedProductID: UUID?
}

private struct AppState: Sendable {
    var selectedTab: AppTab = .home
    var home = HomeState()
    var cart = CartState()
}

private struct HomeViewState: Sendable {
    struct ProductRow: Identifiable, Sendable {
        var product: Product
        var quantityInCart: Int

        var id: UUID {
            product.id
        }
    }

    var products: [ProductRow]
    var selectedProduct: ProductRow?

    nonisolated init(appState: AppState) {
        self.products = appState.home.products.map { product in
            let quantity = appState.cart.items.first(where: { $0.product.id == product.id })?.quantity ?? 0
            return ProductRow(product: product, quantityInCart: quantity)
        }
        self.selectedProduct = appState.home.selectedProductID.flatMap { selectedID in
            self.products.first(where: { $0.product.id == selectedID })
        }
    }
}

private enum HomeAction: Sendable {
    case productTapped(Product.ID)
    case detailDismissed
    case addToCartTapped(Product)
}

private enum CartAction: Sendable {
    case increment(Product)
    case decrement(Product.ID)
}

@CasePathable
private enum AppAction: Sendable {
    case selectedTabChanged(AppTab)
    case home(HomeAction)
    case cart(CartAction)
}

private let homeReducer = Reducer<HomeState, HomeAction> { _, _ in
    .none
}

private let cartReducer = Reducer<CartState, CartAction> { state, action in
    switch action {
    case let .increment(product):
        if let index = state.items.firstIndex(where: { $0.product.id == product.id }) {
            state.items[index].quantity += 1
        } else {
            state.items.append(CartItem(product: product, quantity: 1))
        }
        return .none

    case let .decrement(productID):
        guard let index = state.items.firstIndex(where: { $0.product.id == productID }) else {
            return .none
        }

        if state.items[index].quantity == 1 {
            state.items.remove(at: index)
        } else {
            state.items[index].quantity -= 1
        }
        return .none
    }
}

private let appReducer = Reducer<AppState, AppAction>.combine(
    homeReducer.scope(
        state: \AppState.home,
        action: AppAction.home
    ),
    cartReducer.scope(
        state: \AppState.cart,
        action: AppAction.cart
    ),
    Reducer<AppState, AppAction> { state, action in
        switch action {
        case let .selectedTabChanged(tab):
            state.selectedTab = tab
            return .none

        case let .home(.productTapped(productID)):
            state.home.selectedProductID = productID
            return .none

        case .home(.detailDismissed):
            state.home.selectedProductID = nil
            return .none

        case let .home(.addToCartTapped(product)):
            return cartReducer.reduce(&state.cart, .increment(product)).map(AppAction.cart)

        case .cart, .home:
            return .none
        }
    }
)

private struct HomeView: View {
    @ObservedObject var store: Store<HomeViewState, HomeAction>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection

                    LazyVStack(spacing: 14) {
                        ForEach(store.state.products) { row in
                            ProductCard(
                                row: row,
                                openDetail: {
                                    store.send(.productTapped(row.product.id))
                                },
                                addToCart: {
                                    store.send(.addToCartTapped(row.product))
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.90))
            .navigationTitle("Home")
            .sheet(
                item: store.binding(
                    get: \.selectedProduct,
                    send: { newValue in
                        if let newValue {
                            .productTapped(newValue.product.id)
                        } else {
                            .detailDismissed
                        }
                    }
                )
            ) { row in
                ProductDetailView(
                    row: row,
                    addToCart: {
                        store.send(.addToCartTapped(row.product))
                    }
                )
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekend Grocery Run")
                .font(.system(size: 30, weight: .black, design: .rounded))

            Text("Add fresh picks to the cart directly from the product rail. The quantity badge on each card stays in sync with the cart tab.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.86, blue: 0.67),
                            Color(red: 0.80, green: 0.88, blue: 0.73),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct ProductCard: View {
    let row: HomeViewState.ProductRow
    let openDetail: () -> Void
    let addToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [row.product.accentColor.primary, row.product.accentColor.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 130)
                .overlay(alignment: .bottomLeading) {
                    Text(row.product.name.prefix(1))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(18)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(row.product.name)
                    .font(.headline)

                Text(row.product.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(row.product.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(row.product.accentColor.primary)
            }

            Button(action: addToCart) {
                HStack {
                    Text(row.quantityInCart == 0 ? "Add to Cart" : "Add Another")
                    Spacer()
                    if row.quantityInCart > 0 {
                        Text("\(row.quantityInCart)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.22), in: Capsule())
                    } else {
                        Image(systemName: "plus")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .background(row.product.accentColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: openDetail) {
                HStack {
                    Text("View Details")
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 10)
    }
}

private struct ProductDetailView: View {
    let row: HomeViewState.ProductRow
    let addToCart: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [row.product.accentColor.primary, row.product.accentColor.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 260)
                        .overlay(alignment: .bottomLeading) {
                            Text(row.product.name)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(24)
                        }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(row.product.subtitle)
                            .font(.title3.weight(.semibold))

                        Text("Perfect for the week ahead. This detail page uses the same root-owned cart state as the Home tab, so the add-to-cart quantity always stays in sync.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text(row.product.price.formatted(.currency(code: "USD")))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(row.product.accentColor.primary)
                    }

                    Button(action: addToCart) {
                        HStack {
                            Text(row.quantityInCart == 0 ? "Add to Cart" : "Add Another")
                            Spacer()
                            if row.quantityInCart > 0 {
                                Text("\(row.quantityInCart)")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.22), in: Capsule())
                            } else {
                                Image(systemName: "plus")
                            }
                        }
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .background(row.product.accentColor.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("Product")
        }
    }
}

private struct CartView: View {
    @ObservedObject var store: Store<CartState, CartAction>

    var body: some View {
        NavigationStack {
            Group {
                if store.state.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(store.state.items) { item in
                                CartRow(
                                    item: item,
                                    increment: { store.send(.increment(item.product)) },
                                    decrement: { store.send(.decrement(item.product.id)) }
                                )
                            }

                            summaryCard
                        }
                        .padding(20)
                    }
                    .background(Color(red: 0.95, green: 0.96, blue: 0.98))
                }
            }
            .navigationTitle("Cart")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Your cart is empty")
                .font(.title3.weight(.semibold))

            Text("Add products from the Home tab and they will appear here immediately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 260)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.96, blue: 0.98))
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .font(.headline)

            HStack {
                Text("Items")
                Spacer()
                Text("\(store.state.items.reduce(0) { $0 + $1.quantity })")
            }

            HStack {
                Text("Subtotal")
                Spacer()
                Text(subtotal.formatted(.currency(code: "USD")))
                    .fontWeight(.bold)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var subtotal: Decimal {
        store.state.items.reduce(0) { partial, item in
            partial + (item.product.price * Decimal(item.quantity))
        }
    }
}

private struct CartRow: View {
    let item: CartItem
    let increment: () -> Void
    let decrement: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(item.product.accentColor.secondary)
                .frame(width: 72, height: 72)
                .overlay {
                    Text(item.product.name.prefix(1))
                        .font(.title.weight(.black))
                        .foregroundStyle(item.product.accentColor.primary)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.product.name)
                    .font(.headline)

                Text(item.product.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(item.product.price.formatted(.currency(code: "USD")))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: decrement) {
                    Image(systemName: "minus")
                        .frame(width: 32, height: 32)
                        .background(Color.secondary.opacity(0.12), in: Circle())
                }

                Text("\(item.quantity)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 20)

                Button(action: increment) {
                    Image(systemName: "plus")
                        .frame(width: 32, height: 32)
                        .background(item.product.accentColor.primary.opacity(0.16), in: Circle())
                }
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private extension Product {
    static let catalog: [Product] = [
        Product(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Avocados",
            subtitle: "Creamy, ripe, 4 pack",
            price: 6.50,
            accentColor: .mint
        ),
        Product(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Strawberries",
            subtitle: "Sweet morning harvest",
            price: 5.25,
            accentColor: .coral
        ),
        Product(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Sourdough",
            subtitle: "Fresh baked artisan loaf",
            price: 4.80,
            accentColor: .amber
        ),
        Product(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Cold Brew",
            subtitle: "Smooth roast, 1 liter",
            price: 7.40,
            accentColor: .sky
        ),
        Product(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            name: "Lemons",
            subtitle: "Bright citrus bag",
            price: 3.60,
            accentColor: .citrus
        ),
    ]
}

#Preview {
    ContentView()
}

extension Product: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.subtitle == rhs.subtitle
            && lhs.price == rhs.price
            && lhs.accentColor == rhs.accentColor
    }
}

extension CartItem: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product == rhs.product && lhs.quantity == rhs.quantity
    }
}

extension ColorToken: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

extension AppTab: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.cart, .cart):
            true
        default:
            false
        }
    }
}

extension CartState: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.items == rhs.items
    }
}

extension HomeState: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.selectedProductID == rhs.selectedProductID
    }
}

extension AppState: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectedTab == rhs.selectedTab
            && lhs.home == rhs.home
            && lhs.cart == rhs.cart
    }
}

extension HomeViewState.ProductRow: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.product == rhs.product && lhs.quantityInCart == rhs.quantityInCart
    }
}

extension HomeViewState: Equatable {
    fileprivate nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.products == rhs.products
            && lhs.selectedProduct == rhs.selectedProduct
    }
}
