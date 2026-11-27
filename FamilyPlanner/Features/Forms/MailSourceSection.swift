import SwiftUI

/// Shows which mail an entry was created from: sender, subject and a way to find the mail again.
struct MailSourceSection: View {
    let source: MailSource
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section("Aus einer Mail") {
            VStack(alignment: .leading, spacing: 4) {
                if !source.sender.isEmpty {
                    Text("Von \(source.sender)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                }
                if !source.subject.isEmpty {
                    Text("Betreff: \(source.subject)")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                }
            }
            .accessibilityIdentifier("mail-source")
            if let link = source.link {
                Button {
                    // Gmail's app cannot open one single mail from a link, so the subject is copied
                    // for the search field there.
                    UIPasteboard.general.string = source.subject
                    openURL(link)
                } label: {
                    Label("Betreff kopieren und Gmail öffnen", systemImage: "envelope")
                }
                .accessibilityIdentifier("mail-source-open")
            }
        }
    }
}
