import SwiftUI

/// Conversions between the pickers' `Date` values and the plain strings and times of the models.
enum FormDates {
    static func iso(_ date: Date) -> String {
        WeekBuilder.isoString(date, calendar: WeekBuilder.calendar())
    }

    static func date(fromISO text: String?) -> Date? {
        text.flatMap { WeekBuilder.date(fromISO: $0, calendar: WeekBuilder.calendar()) }
    }

    static func time(from date: Date) -> TimeOfDay {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: parts.hour ?? 0, minute: parts.minute ?? 0) ?? .at(0, 0)
    }

    static func date(from time: TimeOfDay) -> Date {
        Calendar.current.date(bySettingHour: time.hour, minute: time.minute, second: 0, of: Date()) ?? Date()
    }

    /// "12,50" or "12.5" to cents. Empty or invalid input gives nil.
    static func cents(from text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard let value = Double(normalized), value >= 0 else { return nil }
        return Int((value * 100).rounded())
    }

    static func text(fromCents cents: Int?) -> String {
        guard let cents else { return "" }
        return cents % 100 == 0 ? "\(cents / 100)" : String(format: "%.2f", Double(cents) / 100)
            .replacingOccurrences(of: ".", with: ",")
    }
}

/// Round plus button that floats above the tab bar.
struct AddButton: View {
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Theme.surface)
                .frame(width: 58, height: 58)
                .background(Theme.accent, in: Circle())
                .shadow(color: Theme.shadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Neu")
        .accessibilityIdentifier(identifier)
    }
}

extension View {
    /// Places the round plus button at the lower right, above the floating tab bar.
    func addButton(identifier: String, action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            AddButton(identifier: identifier, action: action)
                .padding(.trailing, 20)
                .padding(.bottom, 96)
        }
    }

    /// Soft background for forms.
    func softFormStyle() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background)
            .environment(\.locale, Locale(identifier: "de_DE"))
    }
}

/// Picker for a family member. Nil means nobody in particular.
struct PersonPicker: View {
    let title: String
    let noneLabel: String
    let members: [Member]
    @Binding var selection: String?

    var body: some View {
        Picker(title, selection: $selection) {
            Text(noneLabel).tag(String?.none)
            ForEach(members) { member in
                Text(member.name).tag(Optional(member.id))
            }
        }
    }
}

/// A single form button row, e.g. "Löschen".
struct DestructiveRow: View {
    let title: String
    let identifier: String
    let confirmation: String
    let action: () async -> Void
    @State private var asking = false

    var body: some View {
        Button(title, role: .destructive) { asking = true }
            .accessibilityIdentifier(identifier)
            .confirmationDialog(confirmation, isPresented: $asking, titleVisibility: .visible) {
                Button(title, role: .destructive) { Task { await action() } }
                Button("Abbrechen", role: .cancel) {}
            }
    }
}
