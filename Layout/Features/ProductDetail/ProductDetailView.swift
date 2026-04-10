import StateKit
import SwiftUI

struct ProductDetailView: View {
    @ObservedObject var store: Store<ProductDetailState, ProductDetailAction>
    @ObservedObject var cartStore: Store<CartState, CartAction>
    @ObservedObject var shoppingListStore: Store<ShoppingListState, ShoppingListAction>

    var body: some View {
        let shoppingListFlowStore = store.ifLet(
            state: \.shoppingListFlow,
            action: ProductDetailAction.shoppingListFlow
        )
        let quantityInCart =
            cartStore.state.items.first(where: { $0.product.id == store.state.product.id })?.quantity ?? 0

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [store.state.product.accentColor.primary, store.state.product.accentColor.secondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 260)
                        .overlay(alignment: .bottomLeading) {
                            Text(store.state.product.name)
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(24)
                        }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(store.state.product.subtitle)
                            .font(.title3.weight(.semibold))

                        Text("Perfect for the week ahead. This detail page uses the same root-owned cart state as the Home tab, so the add-to-cart quantity always stays in sync.")
                            .font(.body)
                            .foregroundStyle(.secondary)

                        Text(store.state.product.price.formatted(.currency(code: "USD")))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(store.state.product.accentColor.primary)
                    }

                    Button(action: {
                        cartStore.send(.add(store.state.product))
                    }) {
                        HStack {
                            Text(quantityInCart == 0 ? "Add to Cart" : "Add Another")
                            Spacer()
                            if quantityInCart > 0 {
                                Text("\(quantityInCart)")
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
                        .background(store.state.product.accentColor.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        store.send(
                            .addToListTapped(shoppingListStore.state.lists.isEmpty == false)
                        )
                    }) {
                        HStack {
                            Text("Add to Shopping List")
                            Spacer()
                            Image(systemName: "text.badge.plus")
                        }
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("Product")
            .sheet(
                item: Binding(
                    get: { store.state.shoppingListFlow },
                    set: { newValue in
                        guard newValue == nil else { return }
                        store.send(.shoppingListFlow(.dismissed))
                    }
                )
            ) { _ in
                if let shoppingListFlowStore {
                    ShoppingListFlowSheet(
                        store: shoppingListFlowStore,
                        shoppingListStore: shoppingListStore
                    )
                }
            }
        }
    }
}
