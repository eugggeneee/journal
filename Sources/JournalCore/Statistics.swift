import Foundation

public struct Semester: Equatable, Sendable {
    public var year: Int
    public var number: Int
    public var start: Day
    public var end: Day
    public var notStarted: Bool
    public var key: String { "s:\(year)-\(number)" }
    public var title: String { "\(number)-й семестр · \(year)/\(String(year + 1).suffix(2))" }
    public func contains(_ day: Day) -> Bool { day >= start && day <= end }
    public static func current(on day: Day, settings: Settings) -> Semester {
        if day.isVacation {
            return Semester(year: day.year, number: 1, start: Day("\(day.year)-09-01")!, end: Day("\(day.year + 1)-08-01")!, notStarted: true)
        }
        let year = day.academicYear
        let start = Day("\(year)-09-01")!
        let end = Day("\(year + 1)-08-01")!
        if let split = settings.semesterSplits[String(year)], split > start, split <= end {
            if day >= split { return Semester(year: year, number: 2, start: split, end: end, notStarted: false) }
            return Semester(year: year, number: 1, start: start, end: split.adding(-1), notStarted: false)
        }
        return Semester(year: year, number: 1, start: start, end: end, notStarted: false)
    }
}

public struct LimitStatus: Equatable, Sendable {
    public var key: String
    public var hours: Int
    public var limit: Int
    public var warning: Int
    public var level: Int { hours >= limit ? 2 : hours >= warning ? 1 : 0 }
    public var remaining: Int { max(0, limit - hours) }
    public var progress: Double { min(1, Double(hours) / Double(max(1, limit))) }
    public func isVisible(settings: Settings) -> Bool { level > (settings.dismissed[key] ?? 0) }
}

public extension JournalData {
    func monthStatus(on day: Day = Day()) -> LimitStatus {
        LimitStatus(key: "m:\(day.monthKey)", hours: absences.filter { !$0.excused && $0.day.monthKey == day.monthKey }.reduce(0) { $0 + $1.hours }, limit: settings.limits.month, warning: settings.limits.monthWarning)
    }
    func semesterStatus(on day: Day = Day()) -> LimitStatus {
        let semester = Semester.current(on: day, settings: settings)
        let hours = semester.notStarted ? 0 : absences.filter { !$0.excused && semester.contains($0.day) }.reduce(0) { $0 + $1.hours }
        return LimitStatus(key: semester.key, hours: hours, limit: settings.limits.semester, warning: settings.limits.semesterWarning)
    }
}

public enum GradeMath {
    public static func ordered(_ grades: [Grade]) -> [Grade] {
        grades.sorted { a, b in
            if a.day != b.day { return a.day < b.day }
            if a.createdAt != b.createdAt { return a.createdAt < b.createdAt }
            return a.id.uuidString < b.id.uuidString
        }
    }
    public static func average(_ grades: [Grade]) -> Double? {
        grades.isEmpty ? nil : Double(grades.reduce(0) { $0 + $1.value }) / Double(grades.count)
    }
    public static func change(_ grades: [Grade]) -> Double? {
        guard grades.count >= 2 else { return nil }
        let sorted = ordered(grades)
        return average(sorted)! - average(Array(sorted.dropLast()))!
    }
    public static func formatted(_ average: Double?) -> String {
        guard let average else { return "—" }
        return String(format: "%.2f", locale: Locale(identifier: "ru_RU"), average)
    }
}
