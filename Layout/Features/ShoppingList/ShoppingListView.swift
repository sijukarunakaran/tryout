import StateKit
import SwiftUI

struct ShoppingListView: View {
    var store: Store<ShoppingListState, ShoppingListAction>

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Shopping Lists")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New List") {
                            store.send(.createListButtonTapped)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.state.lists.isEmpty {
            emptyState
        } else {
            shoppingListCollection
        }
    }

    private var shoppingListCollection: some View {
        ScrollView {
            VStack(spacing: 18) {
                ForEach(store.state.lists) { list in
                    ShoppingListSection(
                        list: list,
                        cartQuantities: store.state.cartQuantities,
                        addToCart: { product in
                            store.send(.addToCartTapped(product))
                        }
                    )
                }
            }
            .padding(20)
        }
        .background(Color(red: 0.95, green: 0.96, blue: 0.92))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No shopping lists yet")
                .font(.title3.weight(.semibold))

            Text("Create a list from here or add a product to a new list from Home, Browse, or Product Detail.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button("Create Your First List") {
                store.send(.createListButtonTapped)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.96, blue: 0.92))
    }
}

private struct ShoppingListSection: View {
    let list: ShoppingList
    let cartQuantities: [Product.ID: Int]
    let addToCart: (Product) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if list.products.isEmpty {
                Text("No products yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            } else {
                ForEach(list.products) { product in
                    ShoppingListProductRow(
                        product: product,
                        quantityInCart: cartQuantities[product.id] ?? 0,
                        addToCart: {
                            addToCart(product)
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 16, y: 8)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(list.name)
                .font(.title3.weight(.bold))

            Spacer()

            Text("\(list.products.count) products")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.06), in: Capsule())
        }
    }
}

private struct ShoppingListProductRow: View {
    let product: Product
    let quantityInCart: Int
    let addToCart: () -> Void

    var body: some View {
        HStack(spacing: 14) {
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
                        .foregroundStyle(.white.opacity(0.9))
                }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.headline)

                Text(product.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(product.accentColor.primary)

                    if quantityInCart > 0 {
                        Text("In cart: \(quantityInCart)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button(action: addToCart) {
                VStack(spacing: 4) {
                    Image(systemName: quantityInCart == 0 ? "plus" : "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    Text(quantityInCart == 0 ? "Add" : "Add More")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 70, height: 70)
                .background(product.accentColor.primary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ShoppingListFlowSheet: View {
    var store: Store<ShoppingListFlowState, ShoppingListFlowAction>

    var body: some View {
        NavigationStack {
            Group {
                switch store.state.mode {
                case .picker:
                    listPicker
                case .create:
                    createListForm
                }
            }
            .navigationTitle(sheetTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        store.send(.dismissed)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sheetTitle: String {
        switch store.state.mode {
        case .picker:
            "Add to List"
        case .create:
            "Create List"
        }
    }

    private var listPicker: some View {
        List {
            if let product = store.state.product {
                Section("Product") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Available Lists") {
                ForEach(store.state.availableLists) { list in
                    Button {
                        store.send(.listSelected(list.id))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(list.name)
                                    .font(.headline)
                                Text("\(list.products.count) products")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button("Create New List") {
                    store.send(.createNewListTapped)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var createListForm: some View {
        Form {
            if let product = store.state.product {
                Section("Adding Product") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("List Details") {
                TextField(
                    "Weekly staples",
                    text: store.binding(
                        state: \.draftListName,
                        action: ShoppingListFlowAction.draftListNameChanged
                    )
                )

                Button("Create List") {
                    store.send(.createListConfirmed)
                }
                .disabled(
                    store.state.draftListName
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                )
            }
        }
    }
}
