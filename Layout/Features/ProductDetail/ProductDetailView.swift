import StateKit
import SwiftUI

struct ProductDetailView: View {
    let product: Product
    let cartQuantity: Int
    let onAddToCart: () -> Void
    let onAddToList: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [product.accentColor.primary, product.accentColor.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 260)
                    .overlay(alignment: .bottomLeading) {
                        Text(product.name)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(24)
                    }

                VStack(alignment: .leading, spacing: 12) {
                    Text(product.subtitle)
                        .font(.title3.weight(.semibold))

                    Text("Perfect for the week ahead. This detail page uses the same root-owned cart state as the Home tab, so the add-to-cart quantity always stays in sync.")
                        .font(.body)
                        .foregroundStyle(.secondary)

                    Text(product.price.formatted(.currency(code: "USD")))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(product.accentColor.primary)
                }

                Button(action: onAddToCart) {
                    HStack {
                        Text(cartQuantity == 0 ? "Add to Cart" : "Add Another")
                        Spacer()
                        if cartQuantity > 0 {
                            Text("\(cartQuantity)")
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
                    .background(product.accentColor.primary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)

                Button(action: onAddToList) {
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
        .navigationBarTitleDisplayMode(.inline)
    }
}
