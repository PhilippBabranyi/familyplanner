import SwiftUI

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
