import Foundation
import Testing
@testable import Journal
import JournalCore

private actor LoadCounter {
    var count = 0
    func increment() { count += 1 }
}

@MainActor
struct JournalStorageTests {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("JournalTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func savesSurviveRelaunchAndUndoKeepsNewSchedule() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = JournalStore(directory: folder)
        #expect(first.save(Grade(subject: "Тест", value: 9)))
        let schedule = Schedule(day: Day(), group: "1234", lessons: [.init(number: 1, entries: [.init(subject: "Тест")])])
        #expect(first.change("Сеть", undoable: false, { $0.cache(schedule) }))
        first.undo()
        #expect(first.data.grades.isEmpty)
        #expect(first.data.schedules == [schedule])
        let relaunched = JournalStore(directory: folder)
        #expect(relaunched.data.grades.isEmpty)
        #expect(relaunched.data.schedules.count == 1)
        #expect(relaunched.errorMessage == nil)
    }

    @Test func corruptRootRecoversPreviousFileAndPreservesOriginal() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = JournalStore(directory: folder)
        #expect(store.save(Grade(subject: "Тест", value: 8)))
        #expect(store.save(Grade(subject: "Тест", value: 10)))
        let broken = Data("broken original".utf8)
        try broken.write(to: folder.appendingPathComponent("journal.json"))
        let recovered = JournalStore(directory: folder)
        #expect(recovered.data.grades.count == 1)
        #expect(recovered.data.grades.first?.value == 8)
        #expect(recovered.recoveryMessage != nil)
        let preserved = try #require(recovered.recoveryFiles.first)
        #expect(try Data(contentsOf: preserved) == broken)
    }

    @Test func unavailableStorageDoesNotPublishUnsavedChange() throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("not-a-directory")
        try Data("file".utf8).write(to: file)
        let store = JournalStore(directory: file)
        #expect(!store.save(Grade(subject: "Тест", value: 8)))
        #expect(store.data.grades.isEmpty)
        #expect(store.errorMessage != nil)
    }

    @Test func groupChangeDuringPrefetchStillArchivesNewGroup() async throws {
        let folder = try directory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let counter = LoadCounter()
        let client = ScheduleClient { _ in
            await counter.increment()
            try await Task.sleep(for: .milliseconds(100))
            return (Data("<p>│1234│1│А│101│Тест│</p><p>│2345│1│Б│102│Тест│</p>".utf8), 200)
        }
        let store = JournalStore(directory: folder, client: client)
        #expect(store.change("Настройка", undoable: false, { $0.settings.group = "1234"; $0.settings.onboarded = true }))
        let today = Day("2026-11-13")!
        let initial = Task { await store.prefetch(today: today) }
        while await counter.count == 0 { try await Task.sleep(for: .milliseconds(5)) }
        store.chooseGroup("2345")
        await initial.value
        for offset in -1...4 {
            let day = today.adding(offset)
            if !day.isSunday && !day.isVacation { #expect(store.data.schedule(day, group: "2345") != nil) }
        }
        #expect(store.data.settings.group == "2345")
    }
}
