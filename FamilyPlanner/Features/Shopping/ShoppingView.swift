import SwiftUI

/// Shared shopping list. Tapping an item moves it into the basket.
struct ShoppingView: View {
    @ObservedObject var model: ShoppingViewModel
    @State private var draft = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Einkauf")
                        .font(Theme.display(36))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text("\(model.list.inBasketCount) von \(model.list.items.count) im Korb")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Theme.sage, in: Capsule())
                }

                if let message = model.errorMessage {
                    ErrorBanner(message: message)
                }

                addRow

                ForEach(model.list.sections) { section in
                    Text(section.title.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 8)
                        .padding(.top, 6)
                    ForEach(section.items) { item in
                        ShoppingRow(item: item) { Task { await model.toggle(item.id) } }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.load() }
        .task { await model.load() }
    }

    private var addRow: some View {
        HStack(spacing: 10) {
            TextField("Was fehlt?", text: $draft)
                .font(.system(size: 15))
                .submitLabel(.done)
                .onSubmit(addDraft)
                .padding(.horizontal, 20)
                .frame(height: 52)
                .background(Theme.surface, in: Capsule())
                .accessibilityIdentifier("shopping-input")
            Button(action: addDraft) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Theme.surface)
                    .frame(width: 52, height: 52)
                    .background(Theme.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hinzufügen")
            .accessibilityIdentifier("shopping-add")
        }
    }

    private func addDraft() {
        let name = draft
        draft = ""
        Task { await model.add(name: name) }
    }
}

private struct ShoppingRow: View {
    let item: ShoppingItem
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: item.isInBasket ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(item.isInBasket ? Theme.accent : Theme.seed)
                Text(item.name)
                    .font(.system(size: 15))
                    .strikethrough(item.isInBasket)
                    .foregroundStyle(item.isInBasket ? Theme.muted : Theme.text)
                Spacer()
                if let label = item.label {
                    Text(label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.butter, in: Capsule())
                }
                Text(item.quantity)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .background(Theme.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("item-\(item.id)")
    }
}
