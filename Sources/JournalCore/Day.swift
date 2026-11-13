import Foundation

/// A college calendar date, independent of the phone's time zone or DST.
public struct Day: Hashable, Comparable, Codable, Sendable, Identifiable {
    public let rawValue: String
    public var id: String { rawValue }

    public static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Minsk")!
        calendar.locale = Locale(identifier: "ru_RU")
        return calendar
    }

    public init?(_ rawValue: String) {
        let parts = rawValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1900...2199).contains(parts[0]),
              let date = Self.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2])),
              Self.key(date) == rawValue else { return nil }
        self.rawValue = rawValue
    }

    public init(_ date: Date = Date()) { rawValue = Self.key(date) }
    public var date: Date {
        let parts = rawValue.split(separator: "-").map { Int($0)! }
        return Self.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))!
    }
    public var year: Int { Self.calendar.component(.year, from: date) }
    public var month: Int { Self.calendar.component(.month, from: date) }
    public var number: Int { Self.calendar.component(.day, from: date) }
    public var weekday: Int { Self.calendar.component(.weekday, from: date) }
    public var isSunday: Bool { weekday == 1 }
    public var isVacation: Bool { month == 8 && number >= 2 }
    public var academicYear: Int { month >= 9 ? year : year - 1 }
    public var monthKey: String { String(rawValue.prefix(7)) }
    public func adding(_ days: Int) -> Day {
        Day(Self.calendar.date(byAdding: .day, value: days, to: date)!)
    }
    public func formatted(_ template: String = "d MMMM") -> String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.timeZone = Self.calendar.timeZone
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }
    public static func minute(at date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
    private static func key(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    public init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        let value = try c.decode(String.self)
        guard let day = Day(value) else {
            throw DecodingError.dataCorruptedError(in: c, debugDescription: "Некорректная дата")
        }
        self = day
    }
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

public func plural(_ count: Int, _ one: String, _ few: String, _ many: String) -> String {
    let n = abs(count) % 100
    if (11...14).contains(n) { return many }
    switch n % 10 { case 1: return one; case 2...4: return few; default: return many }
}

public func durationText(_ minutes: Int) -> String {
    let n = max(0, minutes)
    if n < 60 { return "\(n) мин" }
    return n % 60 == 0 ? "\(n / 60) ч" : "\(n / 60) ч \(n % 60) мин"
}

public func timeText(_ minutes: Int) -> String {
    String(format: "%02d:%02d", minutes / 60, minutes % 60)
}
