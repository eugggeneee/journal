import Foundation
import Testing
@testable import Journal
import JournalCore

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
}
