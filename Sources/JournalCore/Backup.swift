import Foundation

public struct JournalError: LocalizedError, Equatable, Sendable {
    public var message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct BackupReport: Sendable {
    public var data: JournalData
    public var discarded: Int
    public var summary: String {
        "Оценок: \(data.grades.count) · пропусков: \(data.absences.count) · пометок: \(data.notes.count) · дней расписания: \(data.schedules.count)"
    }
}

private struct LossyList<Value: Decodable>: Decodable {
    var values: [Value] = []
    var discarded = 0
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        while !container.isAtEnd {
            let element = try container.superDecoder()
            do { values.append(try Value(from: element)) } catch { discarded += 1 }
        }
    }
}

public enum BackupCodec {
    public static let version = 3
    private struct Outgoing: Encodable {
        let app = "journal"
        let version = BackupCodec.version
        let settings: Settings
        let grades: [Grade]
        let absences: [Absence]
        let notes: [DayNote]
        let schedules: [Schedule]
    }
    private struct Incoming: Decodable {
        let app: String
        let version: Int
        let settings: Settings
        let grades: LossyList<Grade>
        let absences: LossyList<Absence>
        let notes: LossyList<DayNote>
        let schedules: LossyList<Schedule>
    }
    public static func encode(_ data: JournalData) throws -> Data {
        guard data.settings.isValid, data.grades.allSatisfy(\.isValid), data.absences.allSatisfy(\.isValid),
              data.notes.allSatisfy(\.isValid), data.schedules.allSatisfy(\.isValid) else {
            throw JournalError("Проверьте введённые данные и настройки.")
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(Outgoing(settings: data.settings, grades: data.grades, absences: data.absences, notes: data.notes, schedules: data.schedules))
    }
    public static func decode(_ bytes: Data) throws -> BackupReport {
        guard bytes.count <= 64 * 1024 * 1024 else { throw JournalError("Файл слишком большой. Максимум — 64 МБ.") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Check identity and version first, so older or newer formats get a useful error.
        struct Header: Decodable { var app: String; var version: Int }
        guard let header = try? decoder.decode(Header.self, from: bytes), header.app == "journal" else {
            throw JournalError("Это не резервная копия Journal.")
        }
        guard header.version == version else { throw JournalError("Эта версия резервной копии не поддерживается. Нужен формат \(version).") }
        let incoming: Incoming
        do { incoming = try decoder.decode(Incoming.self, from: bytes) }
        catch { throw JournalError("Не удалось прочитать копию. Файл неполный или повреждён.") }
        guard incoming.settings.isValid else { throw JournalError("Настройки в копии повреждены. Текущие данные не изменены.") }
        var result = JournalData()
        result.settings = incoming.settings
        var discarded = incoming.grades.discarded + incoming.absences.discarded + incoming.notes.discarded + incoming.schedules.discarded
        var gradeIDs: Set<UUID> = []
        for grade in incoming.grades.values {
            if grade.isValid && gradeIDs.insert(grade.id).inserted { result.grades.append(grade) } else { discarded += 1 }
        }
        for absence in incoming.absences.values {
            guard absence.isValid else { discarded += 1; continue }
            let oldCount = result.absences.count
            result.save(absence)
            if result.absences.count == oldCount { discarded += 1 }
        }
        for note in incoming.notes.values {
            guard note.isValid else { discarded += 1; continue }
            let oldCount = result.notes.count
            result.save(note)
            if result.notes.count == oldCount { discarded += 1 }
        }
        for schedule in incoming.schedules.values.sorted(by: { $0.fetchedAt < $1.fetchedAt }) {
            guard schedule.isValid else { discarded += 1; continue }
            let oldCount = result.schedules.count
            result.cache(schedule)
            if result.schedules.count == oldCount { discarded += 1 }
        }
        return BackupReport(data: result, discarded: discarded)
    }
}
