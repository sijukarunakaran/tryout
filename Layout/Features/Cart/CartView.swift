import StateKit
import SwiftUI

struct CartView: View {
    @ObservedObject var store: Store<CartState, CartAction>

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let checkoutNotice = store.state.checkoutNotice {
                    CheckoutNoticeCard(
                        notice: checkoutNotice,
                        dismiss: {
                            store.send(.dismissCheckoutNotice)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                Group {
                if store.state.items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(store.state.items) { item in
                                CartRow(
                                    item: item,
                                    increment: { store.send(.add(item.product)) },
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

            Button(action: {
                store.send(.checkoutTapped)
            }) {
                HStack {
                    if store.state.isCheckingOut {
                        ProgressView()
                            .tint(.white)
                        Text("Placing Order")
                    } else {
                        Text("Checkout")
                        Spacer()
                        Text(subtotal.formatted(.currency(code: "USD")))
                            .font(.subheadline.weight(.bold))
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    Color(red: 0.13, green: 0.39, blue: 0.28),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(store.state.isCheckingOut)
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

private struct CheckoutNoticeCard: View {
    let notice: CartState.CheckoutNotice
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: notice.tone == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(notice.tone == .success ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(notice.tone == .success ? "Order Confirmed" : "Checkout Failed")
                    .font(.headline)

                Text(notice.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.black.opacity(0.06), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
