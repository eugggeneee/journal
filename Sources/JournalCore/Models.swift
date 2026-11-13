import Foundation

public struct LessonEntry: Codable, Hashable, Sendable {
    public var subject: String
    public var room: String
    public var teacher: String
    public init(subject: String, room: String = "", teacher: String = "") {
        self.subject = subject; self.room = room; self.teacher = teacher
    }
}

public struct Lesson: Codable, Hashable, Sendable, Identifiable {
    public var number: Int
    public var entries: [LessonEntry]
    public var id: Int { number }
    public init(number: Int, entries: [LessonEntry]) { self.number = number; self.entries = entries }
}

public struct Schedule: Codable, Equatable, Sendable, Identifiable {
    public var day: Day
    public var group: String
    public var lessons: [Lesson]
    public var fetchedAt: Date
    public var id: String { "\(group)|\(day.rawValue)" }
    public init(day: Day, group: String, lessons: [Lesson], fetchedAt: Date = Date()) {
        self.day = day; self.group = group; self.lessons = lessons; self.fetchedAt = fetchedAt
    }
    public var isValid: Bool {
        validGroup(group) && lessons.count <= 7 && Set(lessons.map(\.number)).count == lessons.count &&
        lessons.allSatisfy { (1...7).contains($0.number) && !$0.entries.isEmpty &&
            $0.entries.allSatisfy { !$0.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } }
    }
}

public func validGroup(_ value: String) -> Bool {
    (3...5).contains(value.count) && value.utf8.allSatisfy { (48...57).contains($0) }
}

public struct Grade: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var day: Day
    public var subject: String
    public var value: Int
    public var kind: String
    public var note: String
    public var createdAt: Date
    public init(id: UUID = UUID(), day: Day = Day(), subject: String = "", value: Int = 8,
                kind: String = "", note: String = "", createdAt: Date = Date()) {
        self.id = id; self.day = day; self.subject = subject; self.value = value
        self.kind = kind; self.note = note; self.createdAt = createdAt
    }
    public var isValid: Bool { (1...10).contains(value) && !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

public struct Absence: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var day: Day
    public var lesson: Int
    public var subject: String
    public var hours: Int
    public var excused: Bool
    public var note: String
    public init(id: UUID = UUID(), day: Day = Day(), lesson: Int = 0, subject: String = "",
                hours: Int = 2, excused: Bool = false, note: String = "") {
        self.id = id; self.day = day; self.lesson = lesson; self.subject = subject
        self.hours = hours; self.excused = excused; self.note = note
    }
    public var isValid: Bool { (0...7).contains(lesson) && (1...2).contains(hours) }
}

public enum NoteKind: String, Codable, CaseIterable, Sendable {
    case custom, test, credit, practice, shortened
    public var title: String {
        switch self {
        case .custom: "Своя пометка"
        case .test: "ОКР"
        case .credit: "Зачёт"
        case .practice: "Практика"
        case .shortened: "Сокращённый день"
        }
    }
}

public struct DayNote: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var day: Day
    public var lesson: Int
    public var kind: NoteKind
    public var text: String
    public init(id: UUID = UUID(), day: Day = Day(), lesson: Int = 0, kind: NoteKind = .custom, text: String = "") {
        self.id = id; self.day = day; self.lesson = lesson; self.kind = kind; self.text = text
    }
    public var title: String { kind == .custom ? text : kind.title }
    public var isValid: Bool { (0...7).contains(lesson) && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (kind != .shortened || lesson == 0) }
}

public struct Limits: Codable, Equatable, Sendable {
    public var month = 10
    public var monthWarning = 7
    public var semester = 72
    public var semesterWarning = 62
    public init() {}
    public var isValid: Bool {
        (1...1000).contains(month) && (0..<month).contains(monthWarning) &&
        (1...1000).contains(semester) && (0..<semester).contains(semesterWarning)
    }
}

public struct Settings: Codable, Equatable, Sendable {
    public var group = ""
    public var onboarded = false
    public var autoRefresh = true
    public var haptics = true
    public var absenceHours = 2
    public var bells: [String: BellProfile] = [:]
    public var semesterSplits: [String: Day] = [:]
    public var dismissed: [String: Int] = [:]
    public var extraSubjects: [String] = []
    public var subjectNames: [String: String] = [:]
    public var limits = Limits()
    public init() {}
    public var isValid: Bool {
        (group.isEmpty || validGroup(group)) && (1...2).contains(absenceHours) && limits.isValid &&
        bells.allSatisfy { BellKind(rawValue: $0.key) != nil && $0.value.validationError == nil } &&
        semesterSplits.allSatisfy { key, day in
            guard let year = Int(key), let start = Day("\(year)-09-01"), let end = Day("\(year + 1)-08-01") else { return false }
            return day > start && day <= end
        }
    }
}

public struct JournalData: Codable, Equatable, Sendable {
    public var settings = Settings()
    public var grades: [Grade] = []
    public var absences: [Absence] = []
    public var notes: [DayNote] = []
    public var schedules: [Schedule] = []
    public init() {}
    public func name(for key: String) -> String { settings.subjectNames[key] ?? SubjectNames.builtin[key] ?? key }
    public var subjects: [String] {
        var keys = Set(settings.extraSubjects + grades.map(\.subject) + absences.map(\.subject))
        for schedule in schedules where schedule.group == settings.group {
            keys.formUnion(schedule.lessons.flatMap(\.entries).map(\.subject))
        }
        return keys.filter { !$0.isEmpty }.sorted { name(for: $0).localizedStandardCompare(name(for: $1)) == .orderedAscending }
    }
    public func schedule(_ day: Day, group: String? = nil) -> Schedule? {
        schedules.first { $0.day == day && $0.group == (group ?? settings.group) }
    }
    public func absence(_ day: Day, lesson: Int) -> Absence? {
        absences.first { $0.day == day && $0.lesson == lesson && lesson > 0 }
    }
    public func note(_ day: Day, lesson: Int = 0) -> DayNote? { notes.first { $0.day == day && $0.lesson == lesson } }
    public func bellKind(_ day: Day) -> BellKind {
        if notes.contains(where: { $0.day == day && $0.kind == .shortened }) { return .shortened }
        return day.weekday == 7 ? .saturday : .weekdays
    }
    public func profile(_ day: Day) -> BellProfile {
        guard !day.isSunday else { return BellProfile() }
        return settings.bells[bellKind(day).rawValue] ?? BellProfile()
    }
    public mutating func save(_ grade: Grade) {
        grades.removeAll { $0.id == grade.id }; grades.append(grade)
    }
    public mutating func save(_ absence: Absence) {
        absences.removeAll { $0.id == absence.id || (absence.lesson > 0 && $0.day == absence.day && $0.lesson == absence.lesson) }
        absences.append(absence)
    }
    public mutating func save(_ note: DayNote) {
        notes.removeAll { $0.id == note.id || ($0.day == note.day && $0.lesson == note.lesson) }; notes.append(note)
    }
    public mutating func cache(_ schedule: Schedule) {
        schedules.removeAll { $0.id == schedule.id }; schedules.append(schedule)
    }
}

public enum SubjectNames {
    public static let builtin: [String: String] = [
        "ТоварПродТов": "Товароведение продовольственных товаров", "ТоварНепрТов": "Товароведение непродовольственных товаров",
        "ЭлКоммерция": "Электронная коммерция", "ЭкономикаОрган": "Экономика организации", "Ценообразован": "Ценообразование",
        "ОргТехнТорг": "Организация и технология торговли", "КоммерчДеят": "Коммерческая деятельность",
        "ДелКоммун": "Деловые коммуникации", "ВЭД": "Внешнеэкономическая деятельность", "ФинансыИКредит": "Финансы и кредит",
        "ОхранаТруда": "Охрана труда", "АнглЯз": "Английский язык", "РусЯз": "Русский язык", "РусЛит": "Русская литература",
        "БелЛит": "Белорусская литература", "ИстБелГос": "История Беларуси", "ФизКул. и Здор": "Физическая культура и здоровье",
        "ФаФизКулИздор.": "Физическая культура и здоровье", "ИнформТехнол": "Информационные технологии",
        "УголовноеПраво": "Уголовное право", "ГраждПраво": "Гражданское право"
    ]
}
