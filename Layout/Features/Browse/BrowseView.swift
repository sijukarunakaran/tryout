import StateKit
import SwiftUI

struct BrowseView: View {
    var store: Store<BrowseState, BrowseAction>
    @Binding var navigationPath: [AppDestination]

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(ProductCategory.allCases, id: \.rawValue) { category in
                    let products = store.state.products.filter { $0.category == category }
                    if !products.isEmpty {
                        Section(category.title) {
                            ForEach(products) { product in
                                let quantityInCart =
                                    store.state.cartQuantities[product.id] ?? 0
                                BrowseRow(
                                    product: product,
                                    quantityInCart: quantityInCart,
                                    openDetail: {
                                        navigationPath.append(.productDetail(product))
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
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.94, green: 0.95, blue: 0.92))
            .navigationTitle("Browse")
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
}

private struct BrowseRow: View {
    let product: Product
    let quantityInCart: Int
    let openDetail: () -> Void
    let addToCart: () -> Void
    let addToList: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [product.accentColor.primary, product.accentColor.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        Text(product.name.prefix(1))
                            .font(.title.weight(.black))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(product.name)
                        .font(.headline)
                    Text(product.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(product.accentColor.primary)
                }

                Spacer()
            }

            HStack {
                Button("View Details", action: openDetail)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)

                Spacer()

                Button("Add to List", action: addToList)
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)

                Button(action: addToCart) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        if quantityInCart > 0 {
                            Text("\(quantityInCart)")
                                .font(.caption.weight(.bold))
                        } else {
                            Text("Add")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(product.accentColor.primary, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}
