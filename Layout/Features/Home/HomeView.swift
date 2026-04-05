import StateKit
import SwiftUI

struct HomeView: View {
    @ObservedObject var store: Store<HomeState, HomeAction>
    @ObservedObject var cartStore: Store<CartState, CartAction>

    var body: some View {
        let productDetailStore = store.ifLet(
            state: \.productDetail,
            action: HomeAction.productDetail
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection

                    LazyVStack(spacing: 14) {
                        ForEach(store.state.products) { product in
                            let quantityInCart =
                                cartStore.state.items.first(where: { $0.product.id == product.id })?.quantity ?? 0
                            ProductCard(
                                product: product,
                                quantityInCart: quantityInCart,
                                openDetail: {
                                    store.send(.productTapped(product.id))
                                },
                                addToCart: {
                                    cartStore.send(.add(product))
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
                item: Binding(
                    get: { store.state.productDetail },
                    set: { newValue in
                        guard newValue == nil else { return }
                        store.send(.productDetail(.dismissed))
                    }
                )
            ) { _ in
                if let productDetailStore {
                    ProductDetailView(
                        store: productDetailStore,
                        cartStore: cartStore
                    )
                }
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
    let product: Product
    let quantityInCart: Int
    let openDetail: () -> Void
    let addToCart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [product.accentColor.primary, product.accentColor.secondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 130)
                .overlay(alignment: .bottomLeading) {
                    Text(product.name.prefix(1))
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(18)
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.headline)

                Text(product.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(product.price.formatted(.currency(code: "USD")))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(product.accentColor.primary)
            }

            Button(action: addToCart) {
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
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .background(product.accentColor.primary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
