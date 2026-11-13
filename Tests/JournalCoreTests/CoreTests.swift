import Foundation
import Testing
@testable import JournalCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct CalendarAndRulesTests {
    @Test func civilDaysAndLeapYears() throws {
        #expect(Day("2026-02-29") == nil)
        #expect(Day("2024-02-29") != nil)
        #expect(Day("2026-13-01") == nil)
        #expect(Day("2026-11-13")!.adding(18) == Day("2026-12-01"))
        #expect(Day("2026-11-15")!.isSunday)
        #expect(Day("2026-08-01")!.isVacation == false)
        #expect(Day("2026-08-02")!.isVacation)
        #expect(!validGroup("１２３４"))
        #expect(validGroup("1234"))
        #expect(!validGroup("12"))
    }
    @Test func semesterBoundariesAndExcusedHours() {
        var data = JournalData()
        data.settings.semesterSplits["2026"] = Day("2027-01-15")!
        data.save(Absence(day: Day("2027-01-14")!, lesson: 1, hours: 2))
        data.save(Absence(day: Day("2027-01-15")!, lesson: 1, hours: 1))
        data.save(Absence(day: Day("2027-01-15")!, lesson: 2, hours: 2, excused: true))
        #expect(data.semesterStatus(on: Day("2027-01-14")!).hours == 2)
        #expect(data.semesterStatus(on: Day("2027-01-15")!).hours == 1)
        #expect(data.monthStatus(on: Day("2027-01-15")!).hours == 3)
        #expect(data.monthStatus(on: Day("2027-02-01")!).hours == 0)
        #expect(Semester.current(on: Day("2027-08-01")!, settings: data.settings).number == 2)
        #expect(Semester.current(on: Day("2027-08-02")!, settings: data.settings).notStarted)
        #expect(Semester.current(on: Day("2027-09-01")!, settings: data.settings).year == 2027)
    }
    @Test func thresholdsAndDismissal() {
        var data = JournalData()
        for n in 1...4 { data.save(Absence(lesson: n)) }
        let status = data.monthStatus()
        #expect(status.hours == 8 && status.level == 1)
        data.settings.dismissed[status.key] = 1
        #expect(!status.isVisible(settings: data.settings))
        data.save(Absence(lesson: 5))
        #expect(data.monthStatus().level == 2)
        #expect(data.monthStatus().isVisible(settings: data.settings))
        data.settings.limits.month = 20
        #expect(data.monthStatus().remaining == 10)
    }
    @Test func uniqueAbsenceAndNotePerSlot() {
        var data = JournalData()
        data.save(Absence(lesson: 1, hours: 2))
        data.save(Absence(lesson: 1, hours: 1, excused: true))
        #expect(data.absences.count == 1 && data.absences[0].hours == 1)
        data.save(Absence(lesson: 0)); data.save(Absence(lesson: 0))
        #expect(data.absences.count == 3)
        data.save(DayNote(kind: .test)); data.save(DayNote(kind: .shortened))
        #expect(data.notes.count == 1 && data.bellKind(Day()) == .shortened)
    }
    @Test func gradeMeanAndDeterministicLast() {
        let values = [8, 10, 9].enumerated().map { Grade(day: Day("2026-11-13")!.adding($0.offset), subject: "Математика", value: $0.element) }
        #expect(GradeMath.average(values) == 9)
        #expect(GradeMath.change(values) == 0)
        #expect(GradeMath.formatted(8.5) == "8,50")
        #expect(GradeMath.average([]) == nil)
    }
    @Test(arguments: [(1,"час"),(2,"часа"),(5,"часов"),(11,"часов"),(21,"час"),(112,"часов")])
    func russianPlurals(_ value: (Int, String)) { #expect(plural(value.0, "час", "часа", "часов") == value.1) }
}

struct BellsTests {
    @Test func allPresetsAreValid() {
        for preset in [BellProfile.weekdayOne, .weekdayTwo, .saturday, .shortened] { #expect(preset.validationError == nil) }
        #expect(BellProfile.shortened.bell(1)?.start == 500)
        #expect(BellProfile.shortened.bell(6)?.end == 910)
    }
    @Test func overlapAndPartialBreakRejected() {
        #expect(BellProfile(slots: [Bell(1, 500, 600), Bell(2, 590, 700)]).validationError != nil)
        #expect(BellProfile(slots: [Bell(1, 500, 600, 550, nil)]).validationError != nil)
        #expect(BellProfile(slots: [Bell(1, 500, 600, 490, 510)]).validationError != nil)
        #expect(BellProfile(lunchAfter: 2).validationError != nil)
    }
    @Test func generatorCountsStudyAndBreakSeparately() {
        let profile = BellProfile.generated(count: 2, start: 500, studyMinutes: 90, gap: 10, internalBreak: 10, lunchAfter: 1, lunchMinutes: 30)
        #expect(profile.slots[0] == Bell(1, 500, 600, 545, 555))
        #expect(profile.slots[1].start == 630)
        #expect(profile.validationError == nil)
    }
    @Test func phaseAtBoundariesAndWindows() {
        let schedule = Schedule(day: Day(), group: "1234", lessons: [Lesson(number: 1, entries: [.init(subject: "A")]), Lesson(number: 3, entries: [.init(subject: "B")])])
        let profile = BellProfile.weekdayOne
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 499)?.minutes == 1)
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 500)?.title == "Идёт 1-я пара")
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 545)?.title == "Небольшой перерыв")
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 555)?.title == "Идёт 1-я пара")
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 600)?.title == "Свободное окно")
        #expect(DayPhase.current(schedule: schedule, profile: profile, minute: 840)?.isFinished == true)
    }
}

struct ParserAndBackupTests {
    @Test func wordSourceNewlinesAreNotRowBoundaries() throws {
        let html = """
        <html><head><meta content="text/html; charset=windows-1251"></head><body>
        <p>Расписание на пятницу <span>13.11.26</span>г.</p>
        <p><span>&#9474;1234&#9474;\r\n1&#9474;Математика</span>\r\n<span>&#9474;101&#9474;Преподаватель\r\nА.Б.&#9474;</span></p>
        <p>&#9474;    &#9474; 2&#9474;Информатика&#9474;102&#9474;Тест В.Г.&#9474;</p>
        <p>&#9474;    &#9474;  &#9474;Информатика&#9474;103&#9474;Тест Д.Е.&#9474;</p>
        <p>&#9474;2345&#9474;\r\n1&#9474;Физика\r\n&#9474;104&#9474;Тест&#9474;</p>
        </body></html>
        """
        let encoded = try #require(html.data(using: .windowsCP1251))
        let page = ScheduleParser.parse(try ScheduleParser.decode(encoded))
        #expect(page.groups == ["1234", "2345"])
        #expect(page.matches(Day("2026-11-13")!))
        let lessons = page.lessons(for: "1234")
        #expect(lessons.map(\.number) == [1, 2])
        #expect(lessons[0].entries[0].teacher == "Преподаватель А.Б.")
        #expect(lessons[1].entries.count == 2)
    }
    @Test func collegeFixture() throws {
        let url = try #require(Bundle.module.url(forResource: "college", withExtension: "htm", subdirectory: "Fixtures"))
        let page = ScheduleParser.parse(try ScheduleParser.decode(Data(contentsOf: url)))
        #expect(page.hasText)
        #expect(!page.rows.isEmpty)
        #expect(page.groups.count >= 2)
        #expect(page.dates.contains(Day("2026-10-30")!))
        #expect(!page.matches(Day("2027-10-30")!))
        #expect(page.rows.allSatisfy { !$0.entry.subject.contains("√") })
    }
    @Test func subgroupsEntitiesAndGroupReset() {
        let html = "<body><p>30.10.26</p><p>│1234│1│Англ&nbsp;яз│101│А&amp;Б│</p><p>│││Инф&#x43E;рм│102│Тест│</p><p>│2345││Нельзя наследовать пару│││</p><p>││2│√│││</p><p>││3│Право│││</p></body>"
        let page = ScheduleParser.parse(html)
        #expect(page.rows.count == 3)
        #expect(page.lessons(for: "1234").count == 1)
        #expect(page.lessons(for: "1234")[0].entries.count == 2)
        #expect(page.lessons(for: "1234")[0].entries[0].teacher == "А&Б")
        #expect(page.lessons(for: "2345")[0].number == 3)
    }
    @Test func backupIncludesArchiveAndSkipsBadRecords() throws {
        var data = JournalData()
        data.settings.group = "1234"
        data.save(Grade(subject: "Тест", value: 9))
        data.save(DayNote(kind: .shortened))
        data.cache(Schedule(day: Day(), group: "1234", lessons: [.init(number: 1, entries: [.init(subject: "Тест")])]))
        let bytes = try BackupCodec.encode(data)
        let report = try BackupCodec.decode(bytes)
        #expect(report.data.schedules.count == 1)
        #expect(report.data.grades.first?.value == 9)
        var raw = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        var grades = try #require(raw["grades"] as? [[String: Any]])
        var invalid = grades[0]; invalid["value"] = 11; grades.append(invalid); grades.append(["broken": true]); raw["grades"] = grades
        let recovered = try BackupCodec.decode(JSONSerialization.data(withJSONObject: raw))
        #expect(recovered.discarded == 2)
        #expect(recovered.data.grades.count == 1)
        raw["version"] = 999
        #expect(throws: JournalError.self) { try BackupCodec.decode(JSONSerialization.data(withJSONObject: raw)) }
    }
    @Test func backupPreservesOrderWithinTheSameSecond() throws {
        var data = JournalData()
        data.save(Grade(subject: "Тест", value: 5, createdAt: Date(timeIntervalSince1970: 1_700_000_000.125)))
        data.save(Grade(subject: "Тест", value: 10, createdAt: Date(timeIntervalSince1970: 1_700_000_000.875)))
        let restored = try BackupCodec.decode(BackupCodec.encode(data)).data
        #expect(GradeMath.ordered(restored.grades).last?.value == 10)
        #expect(restored.grades.first?.createdAt == data.grades.first?.createdAt)
    }
}

private actor RequestCounter {
    var count = 0
    func increment() { count += 1 }
}
struct NetworkTests {
    @Test func discoveryUsesMultilineWordParagraphs() async {
        let client = ScheduleClient { _ in
            (Data("<p>13.11.26</p><p>│1234│\r\n1│Математика\r\n│101│Тест│</p>".utf8), 200)
        }
        let result = await client.discoverGroups(today: Day("2026-11-13")!)
        #expect(result.groups == ["1234"])
        #expect(result.message == nil)
        if case .page(let page) = await client.page(Day("2026-11-13")!) {
            #expect(page.lessons(for: "1234").count == 1)
        } else { Issue.record("Manual group selection must use the same parsed page") }
    }
    @Test func deniedOrChangedPagesAreNotReportedAsMissing() async {
        for (code, body) in [(403, "Forbidden"), (200, "<p>Service temporarily unavailable</p>")] {
            let client = ScheduleClient { _ in (Data(body.utf8), code) }
            if case .failure = await client.page(Day("2026-11-13")!) {} else { Issue.record("A site failure is not an unpublished day") }
        }
    }
    @Test func sundayMakesNoRequestAndConcurrentRequestsDeduplicate() async {
        let counter = RequestCounter()
        let client = ScheduleClient { request in
            await counter.increment()
            try await Task.sleep(for: .milliseconds(50))
            return (Data("<p>13.11.26</p><p>│1234│1│Тест│101│Имя│</p>".utf8), 200)
        }
        if case .rest = await client.page(Day("2026-11-15")!) {} else { Issue.record("Sunday must be local") }
        #expect(await counter.count == 0)
        async let first = client.page(Day("2026-11-13")!)
        async let second = client.page(Day("2026-11-13")!)
        let (a, b) = await (first, second)
        if case .page = a {} else { Issue.record("Expected page") }
        if case .page = b {} else { Issue.record("Expected page") }
        #expect(await counter.count == 1)
    }
    @Test func wrongYearIsNeverPublished() async {
        let client = ScheduleClient { _ in (Data("<p>13.11.25</p><p>│1234│1│Тест│││</p>".utf8), 200) }
        if case .unpublished = await client.page(Day("2026-11-13")!) {} else { Issue.record("Must reject stale yearly URL") }
    }
}
