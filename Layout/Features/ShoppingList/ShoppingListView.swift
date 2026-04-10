import StateKit
import SwiftUI

struct ShoppingListView: View {
    @ObservedObject var store: Store<ShoppingListState, ShoppingListAction>

    var body: some View {
        let shoppingListFlowStore = store.ifLet(
            state: \.shoppingListFlow,
            action: ShoppingListAction.shoppingListFlow
        )

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
                            shoppingListStore: store
                        )
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
        List {
            ForEach(store.state.lists) { list in
                ShoppingListSection(list: list)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
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

    var body: some View {
        Section {
            if list.products.isEmpty {
                Text("No products yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(list.products) { product in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        Text(product.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            Text(list.name)
        } footer: {
            Text("\(list.products.count) products")
        }
    }
}

struct ShoppingListFlowSheet: View {
    @ObservedObject var store: Store<ShoppingListFlowState, ShoppingListFlowAction>
    @ObservedObject var shoppingListStore: Store<ShoppingListState, ShoppingListAction>

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
                ForEach(shoppingListStore.state.lists) { list in
                    Button {
                        if let product = store.state.product {
                            shoppingListStore.send(.addProductToList(product, list.id))
                        }
                        store.send(.dismissed)
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
                        get: \.draftListName,
                        send: ShoppingListFlowAction.draftListNameChanged
                    )
                )

                Button("Create List") {
                    shoppingListStore.send(
                        .createList(
                            name: store.state.draftListName,
                            product: store.state.product
                        )
                    )
                    store.send(.dismissed)
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
