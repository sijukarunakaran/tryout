import StateKit
import SwiftUI

struct HomeView: View {
    var store: Store<HomeState, HomeAction>

    var body: some View {
        NavigationStack(path: store.binding(state: \.navigationPath, action: HomeAction.setNavigationPath)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroSection

                    LazyVStack(spacing: 14) {
                        ForEach(store.state.products) { product in
                            let quantityInCart =
                                store.state.cartQuantities[product.id] ?? 0
                            ProductCard(
                                product: product,
                                quantityInCart: quantityInCart,
                                openDetail: {
                                    store.send(.setNavigationPath(store.state.navigationPath + [.productDetail(product)]))
                                },
                                addToCart: {
                                    store.send(.addToCartTapped(product))
                                },
                                addToList: {
                                    store.send(.addToListTapped(product))
                                }
                            )
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.96, green: 0.95, blue: 0.90))
            .navigationTitle("Home")
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case .productDetail(let product):
                    ProductDetailView(
                        product: product,
                        cartQuantity: store.state.cartQuantities[product.id] ?? 0,
                        onAddToCart: { store.send(.addToCartTapped(product)) },
                        onAddToList: { store.send(.addToListTapped(product)) }
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
    let addToList: () -> Void

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

            Button(action: addToList) {
                HStack {
                    Text("Add to List")
                    Spacer()
                    Image(systemName: "text.badge.plus")
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
