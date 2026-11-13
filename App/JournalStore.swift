import SwiftUI
import Observation
import JournalCore

enum DayLoadState {
    case loading
    case ready(String)
    case empty(String, String)
}

@MainActor @Observable
final class JournalStore {
    private(set) var data = JournalData()
    private(set) var states: [String: DayLoadState] = [:]
    var errorMessage: String?
    var recoveryMessage: String?
    private(set) var undoTitle: String?
    @ObservationIgnored private var history: [(String, JournalData)] = []
    @ObservationIgnored private let client = ScheduleClient()
    @ObservationIgnored private var loading: Set<String> = []
    @ObservationIgnored private var prefetching = false
    @ObservationIgnored private var lastGood: Data?
    @ObservationIgnored private var folder: URL?
    @ObservationIgnored let demo: Bool

    init(directory: URL? = nil) {
        #if DEBUG
        demo = ProcessInfo.processInfo.arguments.contains("--demo")
        #else
        demo = false
        #endif
        if demo { data = Self.demoData(); return }
        do {
            let directory = try directory ?? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Journal", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            folder = directory
            let file = directory.appendingPathComponent("journal.json")
            guard FileManager.default.fileExists(atPath: file.path) else { return }
            let original = try Data(contentsOf: file)
            do {
                let report = try BackupCodec.decode(original)
                data = report.data
                lastGood = try BackupCodec.encode(data)
                if report.discarded > 0 {
                    try preserve(original, in: directory)
                    recoveryMessage = "Пропущено повреждённых записей: \(report.discarded). Исходный файл сохранён в данных приложения. Остальные данные доступны."
                }
            } catch {
                try preserve(original, in: directory)
                let previous = try? Data(contentsOf: directory.appendingPathComponent("previous.json"))
                if let previous, let report = try? BackupCodec.decode(previous) {
                    data = report.data; lastGood = try BackupCodec.encode(data)
                    recoveryMessage = "Восстановлена последняя рабочая копия. Повреждённый файл сохранён в данных приложения."
                } else {
                    recoveryMessage = "Файл данных повреждён. Его исходная версия сохранена. Можно восстановить резервную копию в настройках."
                }
            }
        } catch {
            errorMessage = "Не удалось открыть хранилище: \(error.localizedDescription)"
        }
    }

    private func preserve(_ bytes: Data, in directory: URL) throws {
        let file = directory.appendingPathComponent("damaged-\(UUID().uuidString).json")
        try bytes.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    @discardableResult
    func change(_ title: String, undoable: Bool = true, _ body: (inout JournalData) -> Void) -> Bool {
        var next = data
        body(&next)
        guard next != data else { return true }
        do {
            try persist(next)
            if undoable {
                history.append((title, data))
                if history.count > 20 { history.removeFirst() }
                undoTitle = title
            }
            data = next
            return true
        } catch {
            errorMessage = "Изменение не сохранено. \(error.localizedDescription)"
            return false
        }
    }

    private func persist(_ next: JournalData) throws {
        let bytes = try BackupCodec.encode(next)
        guard !demo else { return }
        guard let folder else { throw JournalError("Хранилище недоступно. Перезапустите приложение.") }
        if let lastGood { try lastGood.write(to: folder.appendingPathComponent("previous.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]) }
        try bytes.write(to: folder.appendingPathComponent("journal.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        lastGood = bytes
    }

    func undo() {
        guard let (_, previous) = history.last else { return }
        // Network loads may have completed since the user's action. Keep that archive.
        var next = previous
        for schedule in data.schedules {
            if next.schedule(schedule.day, group: schedule.group).map({ $0.fetchedAt < schedule.fetchedAt }) ?? true { next.cache(schedule) }
        }
        do {
            try persist(next); data = next
            history.removeLast(); undoTitle = history.last?.0
        } catch { errorMessage = "Не удалось отменить действие: \(error.localizedDescription)" }
    }

    func undoTitleDismiss() { undoTitle = nil }

    var recoveryFiles: [URL] {
        guard let folder else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []).filter { $0.lastPathComponent.hasPrefix("damaged-") }
    }

    func state(_ day: Day) -> DayLoadState { states[key(day)] ?? .loading }
    private func key(_ day: Day, group: String? = nil) -> String { "\(group ?? data.settings.group)|\(day.rawValue)" }

    func load(_ day: Day, force: Bool = false) async {
        let group = data.settings.group
        guard validGroup(group) else { return }
        let key = key(day, group: group)
        if day.isSunday {
            states[key] = .empty("Выходной", "Воскресенье — время для себя. Занятий нет."); return
        }
        if day.isVacation {
            states[key] = .empty("Летняя пауза", "Каникулы · новый учебный год с 1 сентября."); return
        }
        let saved = data.schedule(day, group: group)
        if demo { states[key] = .ready("Демонстрационные данные"); return }
        if let saved, day < Day() || (!force && Date().timeIntervalSince(saved.fetchedAt) < 1200) {
            states[key] = saved.lessons.isEmpty ? .empty("Занятий нет", "На опубликованной странице для группы \(group) пар нет.") : .ready("Сохранено на устройстве")
            return
        }
        guard loading.insert(key).inserted else { return }
        defer { loading.remove(key) }
        states[key] = saved == nil ? .loading : .ready("Обновляем расписание…")
        let outcome = await client.page(day)
        switch outcome {
        case .page(let page):
            let schedule = Schedule(day: day, group: group, lessons: page.lessons(for: group))
            let stored = change("Расписание обновлено", undoable: false) { $0.cache(schedule) }
            states[key] = schedule.lessons.isEmpty ? .empty("Занятий нет", "На опубликованной странице для группы \(group) пар нет.") : .ready(stored ? "Обновлено · \(Date().formatted(date: .omitted, time: .shortened))" : "Не удалось сохранить обновление")
        case .rest: states[key] = .empty("Выходной", "В этот день занятий нет.")
        case .unpublished:
            states[key] = saved != nil ? .ready("На сайте нет актуальной страницы — показано сохранённое") : .empty("Расписание пока отсутствует", day < Day() ? "Этот день не был сохранён. Колледж удаляет старые расписания с сайта." : "Колледж публикует ближайшие дни постепенно. Потяните вниз, чтобы проверить ещё раз.")
        case .offline(let message), .failure(let message):
            states[key] = saved != nil ? .ready("\(message) Показано сохранённое расписание.") : .empty("Не удалось загрузить", message)
        }
    }

    func prefetch(force: Bool = false) async {
        guard !prefetching, data.settings.onboarded, force || data.settings.autoRefresh else { return }
        prefetching = true
        defer { prefetching = false }
        // Sequential requests limit pressure on the college site; include yesterday to preserve history.
        for offset in -1...4 {
            if Task.isCancelled { return }
            await load(Day().adding(offset), force: force)
        }
    }
    func groups() async -> (groups: [String], message: String?) {
        if demo { return (["1234", "2345", "3456"], nil) }
        return await client.discoverGroups()
    }
    func chooseGroup(_ group: String) {
        guard validGroup(group) else { return }
        if change("Группа изменена", { $0.settings.group = group }) { Task { await prefetch(force: true) } }
    }
    func restore(_ report: BackupReport) -> Bool {
        let changed = change("Данные восстановлены") { $0 = report.data }
        if changed { states = [:] }
        return changed
    }
    func save(_ grade: Grade) -> Bool { change("Оценка сохранена") { $0.save(grade) } }
    func save(_ absence: Absence) -> Bool { change("Пропуск сохранён") { $0.save(absence) } }
    func save(_ note: DayNote) -> Bool { change("Пометка сохранена") { $0.save(note) } }

    static func demoData() -> JournalData {
        var data = JournalData()
        data.settings.group = "1234"; data.settings.onboarded = true
        data.settings.bells = [BellKind.weekdays.rawValue: .weekdayOne, BellKind.saturday.rawValue: .saturday, BellKind.shortened.rawValue: .shortened]
        let today = Day()
        for offset in -6...4 where !today.adding(offset).isSunday {
            data.cache(Schedule(day: today.adding(offset), group: "1234", lessons: [
                Lesson(number: 1, entries: [LessonEntry(subject: "АнглЯз", room: "308", teacher: "Анна Сергеевна")]),
                Lesson(number: 2, entries: [LessonEntry(subject: "ЭкономикаОрган", room: "214", teacher: "Мария Ивановна")]),
                Lesson(number: 3, entries: [LessonEntry(subject: "ЭлКоммерция", room: "402", teacher: "Алексей Петрович")]),
                Lesson(number: 4, entries: [LessonEntry(subject: "ФизКул. и Здор", room: "Спортзал", teacher: "Ирина Андреевна")])
            ]))
        }
        for (i, value) in [8, 9, 7, 10, 9, 8, 10, 9, 8, 9, 10, 9].enumerated() {
            data.grades.append(Grade(day: today.adding(-12 + i), subject: ["АнглЯз", "ЭкономикаОрган", "ЭлКоммерция"][i % 3], value: value, kind: i % 3 == 0 ? "Практическая" : "Ответ"))
        }
        data.save(DayNote(day: today, lesson: 2, kind: .test))
        data.save(Absence(day: today.adding(-2), lesson: 1, subject: "АнглЯз", hours: 2, excused: true))
        data.save(Absence(day: today.adding(-3), lesson: 2, subject: "ЭкономикаОрган", hours: 2))
        return data
    }
}
