import SwiftUI
import JournalCore

enum EditorRoute: Identifiable {
    case grade(Grade), absence(Absence), note(DayNote), lesson(Day, Lesson)
    var id: String {
        switch self {
        case .grade(let item): "grade:\(item.id)"
        case .absence(let item): "absence:\(item.id)"
        case .note(let item): "note:\(item.id)"
        case .lesson(let day, let lesson): "lesson:\(day.rawValue):\(lesson.number)"
        }
    }
}

struct EditorSheet: View {
    let route: EditorRoute
    var body: some View {
        NavigationStack {
            switch route {
            case .grade(let grade): GradeEditor(grade: grade)
            case .absence(let absence): AbsenceEditor(absence: absence)
            case .note(let note): NoteEditor(note: note)
            case .lesson(let day, let lesson): LessonDetail(day: day, lesson: lesson)
            }
        }
    }
}

struct GradeEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var grade: Grade
    @State private var added = 0
    private var existing: Bool { store.data.grades.contains { $0.id == grade.id } }
    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 20) {
                    Text("\(grade.value)").font(.largeTitle.bold()).foregroundStyle(JournalStyle.gradeColor(grade.value))
                    VStack(alignment: .leading, spacing: 4) { Text(grade.subject.isEmpty ? "Новая оценка" : store.data.name(for: grade.subject)).font(.headline.bold()); Text(grade.day.formatted("d MMMM yyyy")).font(.subheadline).foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
                Stepper("Оценка: \(grade.value)", value: $grade.value, in: 1...10).accessibilityIdentifier("grade-value")
                SubjectField(subject: $grade.subject, day: grade.day)
                DateField(day: $grade.day)
            }
            Section("Работа") {
                Picker("Тип", selection: $grade.kind) {
                    Text("Не указан").tag("")
                    ForEach(["Ответ", "Контрольная", "Лабораторная", "Практическая", "Самостоятельная", "Тест", "Зачёт", "Экзамен"], id: \.self) { Text($0).tag($0) }
                }
                TextField("Заметка — необязательно", text: $grade.note, axis: .vertical).lineLimit(3...6)
            }
            if grade.subject.isEmpty { Section { Text("Выберите предмет, чтобы сохранить оценку.").foregroundStyle(.secondary) } }
            if !existing {
                Section {
                    Button(added == 0 ? "Сохранить и добавить ещё" : "Добавить ещё · сохранено \(added)", systemImage: "plus") {
                        if store.save(grade) { added += 1; grade.id = UUID(); grade.createdAt = Date(); grade.note = "" }
                    }.disabled(!grade.isValid)
                }
            } else {
                Section { Button("Удалить оценку", role: .destructive) { if store.change("Оценка удалена", { $0.grades.removeAll { $0.id == grade.id } }) { dismiss() } } }
            }
        }
        .navigationTitle(existing ? "Изменить оценку" : "Новая оценка").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { if store.save(grade) { dismiss() } }.bold().disabled(!grade.isValid).accessibilityIdentifier("grade-save") }
        }
    }
}

struct AbsenceEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var absence: Absence
    private var existing: Bool { store.data.absences.contains { $0.id == absence.id } }
    var body: some View {
        Form {
            Section {
                DateField(day: $absence.day)
                Picker("Пара", selection: $absence.lesson) {
                    Text("Не указана").tag(0)
                    ForEach(1...7, id: \.self) { number in Text("\(number)-я пара").tag(number) }
                }
                SubjectField(subject: $absence.subject, day: absence.day)
                Picker("Часы", selection: $absence.hours) { Text("1 час").tag(1); Text("2 часа · пара").tag(2) }.pickerStyle(.segmented)
            } footer: { Text("Учитываются академические часы. Одна полная пара — 2 часа.") }
            Section {
                Toggle("Уважительная причина", isOn: $absence.excused)
                TextField("Заметка — необязательно", text: $absence.note, axis: .vertical).lineLimit(3...6)
            } footer: { Text("В лимитах учитываются только часы без уважительной причины.") }
            if let replacement = store.data.absence(absence.day, lesson: absence.lesson), replacement.id != absence.id {
                Section { Label("Прежняя отметка этой пары будет заменена. Действие можно отменить.", systemImage: "info.circle").foregroundStyle(.secondary) }
            }
            if existing { Section { Button("Удалить пропуск", role: .destructive) { if store.change("Пропуск удалён", { $0.absences.removeAll { $0.id == absence.id } }) { dismiss() } } } }
        }
        .navigationTitle(existing ? "Изменить пропуск" : "Новый пропуск").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { if store.save(absence) { dismiss() } }.bold().disabled(!absence.isValid) }
        }
        .onChange(of: absence.lesson) { _, _ in suggestSubject() }
        .onChange(of: absence.day) { _, _ in suggestSubject() }
    }
    private func suggestSubject() {
        if let entries = store.data.schedule(absence.day)?.lessons.first(where: { $0.number == absence.lesson })?.entries, entries.count == 1 { absence.subject = entries[0].subject }
    }
}

struct NoteEditor: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var note: DayNote
    private var existing: Bool { store.data.notes.contains { $0.id == note.id } }
    var body: some View {
        Form {
            Section {
                DateField(day: $note.day)
                Picker("Что это", selection: $note.kind) { ForEach(NoteKind.allCases, id: \.self) { Text($0.title).tag($0) } }
                if note.kind == .custom { TextField("Например, консультация", text: $note.text).accessibilityLabel("Название пометки") }
                if note.kind != .shortened {
                    Picker("К чему относится", selection: $note.lesson) {
                        Text("Весь день").tag(0)
                        ForEach(1...7, id: \.self) { Text("\($0)-я пара").tag($0) }
                    }
                }
            }
            if note.kind == .shortened {
                Section {
                    Text("Для этой даты будут применены сокращённые звонки. Их можно изменить в настройках → Звонки → Сокращённые.")
                    Text("Исходный пресет: 6 пар с 08:20 до 15:10, по 60 минут с перерывами по 10 минут.").foregroundStyle(.secondary)
                }
            }
            if let previous = store.data.note(note.day, lesson: note.lesson), previous.id != note.id {
                Section { Text("Пометка «\(previous.title)» будет заменена. Это можно отменить.").foregroundStyle(.secondary) }
            }
            if existing { Section { Button("Удалить пометку", role: .destructive) { if store.change("Пометка удалена", { $0.notes.removeAll { $0.id == note.id } }) { dismiss() } } } }
        }
        .navigationTitle(existing ? "Изменить пометку" : "Новая пометка").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Сохранить") {
                if note.kind == .shortened { note.lesson = 0 }
                let saved = store.change("Пометка сохранена") { data in
                    data.save(note)
                    if note.kind == .shortened && data.settings.bells[BellKind.shortened.rawValue] == nil { data.settings.bells[BellKind.shortened.rawValue] = .shortened }
                }
                if saved { dismiss() }
            }.bold().disabled(!note.isValid) }
        }
        .onChange(of: note.kind) { _, kind in if kind == .shortened { note.lesson = 0 } }
    }
}

struct LessonDetail: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let day: Day
    let lesson: Lesson
    @State private var editor: EditorRoute?
    var body: some View {
        List {
            if let bell = store.data.profile(day).bell(lesson.number) {
                Section {
                    LabeledContent("Время", value: "\(timeText(bell.start))–\(timeText(bell.end))")
                    if let a = bell.breakStart, let b = bell.breakEnd {
                        LabeledContent(b - a >= 20 ? "Обед" : "Перерыв", value: "\(timeText(a))–\(timeText(b))")
                        Text("\(bell.start < a ? durationText(a - bell.start) : "") + \(durationText(bell.end - b)) занятий").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            ForEach(Array(lesson.entries.enumerated()), id: \.offset) { _, entry in
                Section(lesson.entries.count > 1 ? "Вариант занятия" : "Занятие") {
                    Text(store.data.name(for: entry.subject)).font(.headline.bold())
                    if !entry.room.isEmpty { LabeledContent("Аудитория", value: entry.room) }
                    if !entry.teacher.isEmpty { LabeledContent("Преподаватель", value: entry.teacher) }
                    Button("Добавить оценку", systemImage: "plus.circle") { editor = .grade(Grade(day: day, subject: entry.subject)) }
                    Button("Отметить пропуск", systemImage: "person.crop.circle.badge.minus") {
                        editor = .absence(store.data.absence(day, lesson: lesson.number) ?? Absence(day: day, lesson: lesson.number, subject: entry.subject, hours: store.data.settings.absenceHours))
                    }
                }
            }
            Section { Button("Пометка к паре", systemImage: "note.text") { editor = .note(store.data.note(day, lesson: lesson.number) ?? DayNote(day: day, lesson: lesson.number)) } }
        }
        .navigationTitle("\(lesson.number)-я пара · \(day.formatted())").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        .sheet(item: $editor) { EditorSheet(route: $0) }
    }
}
