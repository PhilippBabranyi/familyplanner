import SwiftUI

/// Chips above the day's items: Alle / Ich / the others / Familie.
struct ItemFilterBar: View {
    @Binding var selection: ItemFilter
    /// Names of the other accounts of the family.
    let others: [String]

    private var chips: [(title: String, filter: ItemFilter)] {
        [("Alle", .all), ("Ich", .mine)] + others.map { ($0, .person($0)) } + [("Familie", .family)]
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(chips, id: \.title) { chip in
                    Button { selection = chip.filter } label: {
                        Text(chip.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 14)
                            .frame(height: 34)
                            .background(selection == chip.filter ? Theme.sage : Theme.surface, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("filter-\(chip.title)")
                    .accessibilityAddTraits(selection == chip.filter ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// Small avatar of the person an item is for; a group symbol when it is for the whole family.
struct AssigneeBadge: View {
    let assignee: String?

    var body: some View {
        Group {
            if let assignee {
                Text(String(assignee.prefix(1)).uppercased())
                    .font(.system(size: 12, weight: .bold))
            } else {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .accessibilityLabel("Familie")
            }
        }
        .foregroundStyle(Theme.text)
        .frame(width: 30, height: 30)
        .background(AssigneePalette.color(for: assignee), in: Circle())
    }
}
