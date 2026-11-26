import Foundation

// Database rows of the pickup tables: pickup_times, pickup_drivers and pickup_overrides.

struct PickupRow: Decodable {
    let weekday: Int
    let pickupTime: String

    enum CodingKeys: String, CodingKey {
        case weekday
        case pickupTime = "pickup_time"
    }
}

struct PickupWrite: Encodable {
    let familyId: UUID
    let weekday: Int
    let pickupTime: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case weekday
        case pickupTime = "pickup_time"
    }
}

struct PickupReminderRow: Decodable {
    let remindMinutes: Int

    enum CodingKeys: String, CodingKey {
        case remindMinutes = "remind_minutes"
    }
}

struct PickupDriverRow: Decodable {
    let day: String
    let driver: UUID

    /// The id the app uses for this member (UUID.uuidString, upper case), so that the name can be found.
    var driverId: String { driver.uuidString }
}

struct PickupDriverWrite: Encodable {
    let familyId: UUID
    let day: String
    let driver: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case day
        case driver
    }
}

struct PickupOverrideRow: Decodable {
    let day: String
    /// Nil means that there is no pickup on that day.
    let pickupTime: String?

    enum CodingKeys: String, CodingKey {
        case day
        case pickupTime = "pickup_time"
    }

    var override: PickupOverride {
        pickupTime.flatMap { TimeOfDay(databaseValue: $0) }.map { .time($0) } ?? .cancelled
    }
}

struct PickupOverrideWrite: Encodable {
    let familyId: UUID
    let day: String
    let pickupTime: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case day
        case pickupTime = "pickup_time"
    }

    /// A missing time is written as null: that is how "no pickup on this day" is stored.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(familyId, forKey: .familyId)
        try container.encode(day, forKey: .day)
        try container.encode(pickupTime, forKey: .pickupTime)
    }
}
