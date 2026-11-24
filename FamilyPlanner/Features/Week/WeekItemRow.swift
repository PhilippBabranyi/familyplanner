import SwiftUI

extension Person {
    var color: Color {
        switch self {
        case .alex: return Theme.peach
        case .sam: return Theme.blue
        case .helper: return Theme.sage
        case .everyone: return Theme.surfaceAlt
        }
    }
}

/// Formats cents as euros, e.g. 4000 -> "40 €".
func formattedEuros(cents: Int) -> String {
    cents % 100 == 0 ? "\(cents / 100) €" : String(format: "%.2f €", Double(cents) / 100)
}

struct WeekItemRow: View {
    let item: WeekItem

    var body: some View {
        HStack(spacing: 12) {
            Text(item.time.description)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 48, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let note = item.note {
                    Text(note)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                if let label = tagLabel {
                    Text(label.text)
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(label.color, in: Capsule())
                        .foregroundStyle(Theme.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.owner.initial)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 30, height: 30)
                .background(item.owner.color, in: Circle())
        }
        .padding(.leading, 18)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Theme.shadow.opacity(0.5), radius: 5, x: 0, y: 2)
    }

    private var tagLabel: (text: String, color: Color)? {
        switch item.tag {
        case .homeAssistant?:
            return ("Home Assistant", Theme.sage)
        case let .cash(cents)?:
            return ("Bargeld \(formattedEuros(cents: cents))", Theme.butter)
        case nil:
            return nil
        }
    }
}
