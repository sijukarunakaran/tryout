//
//  ContentView.swift
//  Layout
//
//  Created by Siju Karunakaran on 15/03/26.
//

import SwiftUI

struct ContentView: View {
    @State private var maxItemHeight: CGFloat = 0

    private let items: [Item] = [
        Item(color: .red, title: "Short", detail: "One line."),
        Item(color: .orange, title: "Medium Title", detail: "A couple of lines of supporting text for this card."),
        Item(color: .yellow, title: "Longer Title Example", detail: "This one has a much longer description to force the height to grow based on its content size."),
        Item(color: .green, title: "Tiny", detail: "Small."),
        Item(color: .blue, title: "Another Example", detail: "More text here to push the height a bit further than the shorter cards."),
        Item(color: .indigo, title: "Tallest Card Title", detail: "A long block of text that should make this the tallest card in the row so the scroll view grows to the max height."),
        Item(color: .purple, title: "Compact", detail: "Short.")
    ]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .bottom, spacing: 16) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(width: 200, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(item.color.gradient)
                    )
                    .foregroundStyle(.white)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: MaxHeightPreferenceKey.self, value: proxy.size.height)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .contentMargins(.vertical, 16, for: .scrollContent)
        .frame(minHeight: maxItemHeight)
        .background(.blue.opacity(0.4))
        .onPreferenceChange(MaxHeightPreferenceKey.self) { newValue in
            maxItemHeight = max(maxItemHeight, newValue)
        }
    }
}

#Preview {
    ContentView()
}
private struct Item: Identifiable {
    let id = UUID()
    let color: Color
    let title: String
    let detail: String
}

private struct MaxHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

