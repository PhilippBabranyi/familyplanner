import SwiftUI

/// The bell's list: what the mails suggest. Each card can be accepted (opens the filled form),
/// dismissed, or the mail can be opened.
struct SuggestionsSheet: View {
    @ObservedObject var inbox: InboxViewModel
    @ObservedObject var tasks: TasksViewModel
    @ObservedObject var week: WeekViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var accepting: InboxSuggestion?
    @State private var members: [Member] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if let message = inbox.errorMessage {
                        ErrorBanner(message: message)
                    }
                    if inbox.suggestions.isEmpty {
                        Text("Nichts Neues. Die Mails sind alle erledigt. 🎉")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.muted)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 140)
                            .accessibilityIdentifier("suggestions-empty")
                    }
                    ForEach(inbox.suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            accept: { accepting = suggestion },
                            dismiss: { Task { await inbox.decide(suggestion.id, .dismissed) } },
                            openMail: {
                                // Gmail's app cannot open one single mail from a link, so the subject is copied
                                // for the search field there.
                                UIPasteboard.general.string = suggestion.subject
                                if let link = suggestion.link { openURL(link) }
                            }
                        )
                    }
                }
                .padding(20)
            }
            .background(Theme.background)
            .navigationTitle("Neu für euch")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                        .accessibilityIdentifier("suggestions-done")
                }
            }
            .refreshable { await inbox.load() }
        }
        .task {
            members = await tasks.members()
            await inbox.load()
        }
        .sheet(item: $accepting) { suggestion in
            acceptForm(for: suggestion)
        }
    }

    @ViewBuilder
    private func acceptForm(for suggestion: InboxSuggestion) -> some View {
        switch suggestion.kind {
        case .task:
            TaskFormView(
                existing: nil,
                members: members,
                prefill: SuggestionDrafts.task(from: suggestion),
                onSave: { draft in
                    let saved = await tasks.save(draft)
                    if saved { await inbox.decide(suggestion.id, .accepted) }
                    return saved
                },
                onDelete: { _ in false }
            )
        case .event:
            CalendarItemFormView(
                existing: nil,
                defaultDate: FormDates.date(fromISO: suggestion.date) ?? Date(),
                members: members,
                prefill: SuggestionDrafts.event(from: suggestion),
                onSave: { draft in
                    let saved = await week.save(draft)
                    if saved { await inbox.decide(suggestion.id, .accepted) }
                    return saved
                },
                onDelete: { _ in false }
            )
        }
    }
}

/// How a suggestion fills the forms. Amounts always go into the cash field, in euros.
enum SuggestionDrafts {
    static func task(from suggestion: InboxSuggestion) -> TaskDraft {
        TaskDraft(
            id: nil, title: suggestion.title, assigneeId: nil, dueOn: suggestion.date,
            cashCents: suggestion.amountCentsInEuro,
            dueTime: suggestion.date == nil ? nil : suggestion.time?.description
        )
    }

    static func event(from suggestion: InboxSuggestion) -> CalendarItemDraft {
        CalendarItemDraft(
            id: nil, title: suggestion.title, note: "",
            startsOn: suggestion.date ?? FormDates.iso(Date()), time: suggestion.time ?? .at(9, 0),
            weekdays: [], repeatUntil: nil, skipHolidays: false, assigneeId: nil,
            cashCents: suggestion.amountCentsInEuro
        )
    }
}

private struct SuggestionCard: View {
    let suggestion: InboxSuggestion
    let accept: () -> Void
    let dismiss: () -> Void
    let openMail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: suggestion.kind == .event ? "calendar" : "checkmark.square")
                    .foregroundStyle(Theme.accent)
                Text(suggestion.kind == .event ? "Termin" : "Aufgabe")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            Text(suggestion.title)
                .font(Theme.display(21))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if !facts.isEmpty {
                HStack(spacing: 8) {
                    ForEach(facts, id: \.self) { fact in
                        Text(fact)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 30)
                            .background(Theme.surface, in: Capsule())
                    }
                }
            }
            Text(suggestion.summary)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Von \(suggestion.sender)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Text("Betreff: \(suggestion.subject)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
            HStack(spacing: 8) {
                Button(action: accept) {
                    Text("Übernehmen")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.surface)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Theme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("suggestion-accept-\(suggestion.id)")
                Button(action: dismiss) {
                    Text("Brauche ich nicht")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(Theme.surface, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("suggestion-dismiss-\(suggestion.id)")
                Spacer(minLength: 0)
                if suggestion.link != nil {
                    Button(action: openMail) {
                        Image(systemName: "envelope")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 44, height: 44)
                            .background(Theme.surface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Betreff kopieren und Gmail öffnen")
                    .accessibilityIdentifier("suggestion-mail-\(suggestion.id)")
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Theme.sageLight, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    /// Date, time and amount as small chips.
    private var facts: [String] {
        [suggestion.whenText, suggestion.amountText].compactMap { $0 }
    }
}
