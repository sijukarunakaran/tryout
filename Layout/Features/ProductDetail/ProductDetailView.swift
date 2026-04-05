import StateKit
import SwiftUI

struct ProductDetailView: View {
    @ObservedObject var store: Store<ProductDetailState, ProductDetailAction>
    @ObservedObject var cartStore: Store<CartState, CartAction>

    var body: some View {
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
                }
                .padding(20)
            }
            .background(Color(red: 0.97, green: 0.96, blue: 0.93))
            .navigationTitle("Product")
        }
    }
}
