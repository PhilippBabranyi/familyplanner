import SwiftUI

extension View {
    /// Asks "really delete?" for the item that is set in `item`; deleting is only done on the red button.
    func confirmDelete<Item>(
        _ item: Binding<Item?>,
        title: String,
        name: @escaping (Item) -> String,
        onDelete: @escaping (Item) -> Void
    ) -> some View {
        confirmationDialog(
            title,
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: item.wrappedValue
        ) { entry in
            Button("Löschen", role: .destructive) { onDelete(entry) }
            Button("Abbrechen", role: .cancel) {}
        } message: { entry in
            Text(name(entry))
        }
    }
}
