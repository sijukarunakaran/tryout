import StateKit
import SwiftUI

struct BrowseView: View {
    @ObservedObject var store: Store<BrowseState, BrowseAction>
    @ObservedObject var cartStore: Store<CartState, CartAction>
    @ObservedObject var shoppingListStore: Store<ShoppingListState, ShoppingListAction>

    var body: some View {
        let productDetailStore = store.ifLet(
            state: \.productDetail,
            action: BrowseAction.productDetail
        )
        let shoppingListFlowStore = store.ifLet(
            state: \.shoppingListFlow,
            action: BrowseAction.shoppingListFlow
        )

        NavigationStack {
            List {
                ForEach(ProductCategory.allCases, id: \.rawValue) { category in
                    let products = store.state.products.filter { $0.category == category }
                    if !products.isEmpty {
                        Section(category.title) {
                            ForEach(products) { product in
                                let quantityInCart =
                                    cartStore.state.items.first(where: { $0.product.id == product.id })?.quantity ?? 0
                                BrowseRow(
                                    product: product,
                                    quantityInCart: quantityInCart,
                                    openDetail: {
                                        store.send(.productTapped(product.id))
                                    },
                                    addToCart: {
                                        cartStore.send(.add(product))
                                    },
                                    addToList: {
                                        store.send(
                                            .addToListTapped(
                                                product,
                                                hasExistingLists: shoppingListStore.state.lists.isEmpty == false
                                            )
                                        )
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
                        cartStore: cartStore,
                        shoppingListStore: shoppingListStore
                    )
                }
            }
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
