import Foundation

extension WeekViewModel {
    /// The day next to `day` (`delta` is 1 or -1). Leaving the week shows the neighbouring week.
    func moveDay(from day: Weekday, by delta: Int) -> Weekday {
        let raw = day.rawValue + delta
        if raw > 7 {
            showWeek(offsetBy: 1)
            return .monday
        }
        if raw < 1 {
            showWeek(offsetBy: -1)
            return .sunday
        }
        return Weekday(rawValue: raw) ?? day
    }
}
