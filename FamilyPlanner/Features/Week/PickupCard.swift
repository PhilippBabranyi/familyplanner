import SwiftUI

/// The pickup of one day: time, who picks up, and a change for this day only (like one changed occurrence
/// of a series).
struct PickupCard: View {
    @ObservedObject var model: WeekViewModel
    let day: Weekday

    @State private var editsTime = false
    @State private var newTime = Date()

    private var plan: WeekPlan { model.shownPlan }
    private var time: TimeOfDay? { plan.pickupTime(on: day) }
    private var override: PickupOverride? { plan.overrideByDay[day] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            HStack(spacing: 8) {
                if time != nil { driverMenu }
                changeMenu
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            highlighted ? Theme.butter : Theme.surfaceAlt,
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .sheet(isPresented: $editsTime) { timeSheet }
    }

    private var highlighted: Bool { override != nil }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "clock")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.text)
            VStack(alignment: .leading, spacing: 2) {
                Text("ABHOLUNG")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.muted)
                Text(time?.description ?? "Entfällt")
                    .font(Theme.display(26))
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            if override != nil {
                Text("Nur an diesem Tag geändert")
                    .font(.system(size: 13, weight: .semibold))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: 120, alignment: .trailing)
            }
        }
    }

    /// Who picks up on this day. Nobody is entered by default; the morning push asks for it.
    private var driverMenu: some View {
        let name = model.driverName(on: day)
        return Menu {
            ForEach(model.accounts) { member in
                Button(member.name) {
                    Task { _ = await model.setPickupDriver(day: day, memberId: member.id) }
                }
            }
            if name != nil {
                Button("Niemand", role: .destructive) {
                    Task { _ = await model.setPickupDriver(day: day, memberId: nil) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(name == nil ? Theme.pickupOpen : AssigneePalette.color(for: name))
                    .frame(width: 10, height: 10)
                Text(name.map { "\($0) holt ab" } ?? "Wer holt ab?")
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .chip()
        }
        .accessibilityIdentifier("pickup-driver")
    }

    private var changeMenu: some View {
        Menu {
            Button("Zeit nur an diesem Tag ändern") {
                newTime = FormDates.date(from: time ?? .at(15, 20))
                editsTime = true
            }
            if time != nil {
                Button("Pickup entfällt an diesem Tag") { apply(.cancelled) }
            }
            if override != nil {
                Button("Auf normale Zeit zurücksetzen") { apply(nil) }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                Text("Nur dieser Tag")
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .chip()
        }
        .accessibilityIdentifier("pickup-override")
    }

    private var timeSheet: some View {
        NavigationStack {
            Form {
                DatePicker("Pickup", selection: $newTime, displayedComponents: .hourAndMinute)
                    .accessibilityIdentifier("override-time")
            }
            .softFormStyle()
            .navigationTitle("Nur an diesem Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { editsTime = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        editsTime = false
                        apply(.time(FormDates.time(from: newTime)))
                    }
                    .accessibilityIdentifier("override-save")
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func apply(_ change: PickupOverride?) {
        Task { _ = await model.setPickupOverride(day: day, override: change) }
    }
}

private extension View {
    func chip() -> some View {
        font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Theme.surface, in: Capsule())
    }
}
