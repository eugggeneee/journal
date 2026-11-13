import SwiftUI
import JournalCore

struct BellsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var kind: BellKind
    @State private var drafts: [String: BellProfile] = [:]
    @State private var generator = false
    @State private var loaded = false
    @State private var clearConfirmation = false
    init(initial: BellKind = .weekdays) { _kind = State(initialValue: initial) }
    private var profile: BellProfile { drafts[kind.rawValue] ?? BellProfile() }
    private var hasChanges: Bool { drafts != store.data.settings.bells }
    private var error: String? { drafts.values.compactMap(\.validationError).first }
    var body: some View {
        Form {
            Section {
                Picker("Вид дней", selection: $kind) { ForEach(BellKind.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            } footer: { Text(kind == .shortened ? "Применяются только к датам с пометкой «Сокращённый день». Время — по Минску." : "Расписание сайта содержит номера пар. Время задаётся здесь, по Минску.") }
            Section("Готовые расписания") {
                if kind == .weekdays {
                    preset("Обед после второй пары", detail: "11:50–12:20 · 7 пар", value: .weekdayOne)
                    preset("Обед внутри третьей пары", detail: "12:45–13:15 · 7 пар", value: .weekdayTwo)
                } else if kind == .saturday {
                    preset("Суббота · 6 пар", detail: "08:20–18:40", value: .saturday)
                    Text("Пресет из старой версии. Сверьте время с актуальным объявлением колледжа.").font(.footnote).foregroundStyle(.secondary)
                } else { preset("Сокращённый день · 6 пар", detail: "08:20–15:10 · по объявлению 06.11.2026", value: .shortened) }
            }
            Section {
                Button("Автозаполнение", systemImage: "wand.and.stars") { generator = true }
                if kind != .weekdays { Button("Скопировать из будней", systemImage: "doc.on.doc") { drafts[kind.rawValue] = drafts[BellKind.weekdays.rawValue] ?? BellProfile() } }
                Picker("Обед между парами", selection: Binding(get: { profile.lunchAfter }, set: { value in edit { $0.lunchAfter = value } })) {
                    Text("Не выделять").tag(0)
                    ForEach(profile.slots.sorted { $0.number < $1.number }) { Text("После \($0.number)-й пары").tag($0.number) }
                }
            }
            ForEach(1...7, id: \.self) { number in
                Section("\(number)-я пара") {
                    Toggle("Задать время", isOn: Binding(get: { profile.bell(number) != nil }, set: { enabled in
                        edit { p in
                            if enabled { let start = p.slots.filter { $0.number < number }.map(\.end).max().map { $0 + 10 } ?? 500; p.slots.append(Bell(number, min(start, 1340), min(start + 90, 1439))) }
                            else { p.slots.removeAll { $0.number == number }; if p.lunchAfter == number { p.lunchAfter = 0 } }
                        }
                    }))
                    if let bell = profile.bell(number) {
                        timeField("Начало", number: number, key: \.start, value: bell.start)
                        timeField("Конец", number: number, key: \.end, value: bell.end)
                        Toggle("Перерыв внутри пары", isOn: Binding(get: { profile.bell(number)?.breakStart != nil }, set: { enabled in
                            editBell(number) { b in
                                b.breakStart = enabled ? b.start + max(1, (b.end - b.start) / 2 - 5) : nil
                                b.breakEnd = enabled ? b.start + max(2, (b.end - b.start) / 2 + 5) : nil
                            }
                        }))
                        if let a = bell.breakStart, let b = bell.breakEnd {
                            optionalTimeField("Перерыв с", number: number, key: \.breakStart, value: a)
                            optionalTimeField("Перерыв до", number: number, key: \.breakEnd, value: b)
                            Text("\(durationText(max(0, a - bell.start))) + \(durationText(max(0, bell.end - b))) занятий").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let error { Section { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) } }
            Section {
                Button("Сохранить звонки") { save() }.disabled(!hasChanges || error != nil)
                Button("Очистить этот профиль", role: .destructive) { clearConfirmation = true }
            }
        }
        .navigationTitle("Звонки").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { if !hasChanges || save() { dismiss() } }.disabled(error != nil) } }
        .onAppear { if !loaded { drafts = store.data.settings.bells; loaded = true } }
        .interactiveDismissDisabled(hasChanges)
        .sheet(isPresented: $generator) { BellGenerator { drafts[kind.rawValue] = $0 } }
        .confirmationDialog("Очистить звонки для «\(kind.title)»?", isPresented: $clearConfirmation, titleVisibility: .visible) {
            Button("Очистить профиль", role: .destructive) { drafts.removeValue(forKey: kind.rawValue) }
        }
    }
    private func preset(_ title: String, detail: String, value: BellProfile) -> some View {
        Button { drafts[kind.rawValue] = value } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) { Text(title).foregroundStyle(.primary); Text(detail).font(.caption).foregroundStyle(.secondary) }
                Spacer(); if profile == value { Image(systemName: "checkmark.circle.fill").accessibilityLabel("Выбрано") }
            }.padding(.vertical, 4)
        }
    }
    private func edit(_ body: (inout BellProfile) -> Void) { var p = profile; body(&p); drafts[kind.rawValue] = p }
    private func editBell(_ number: Int, _ body: (inout Bell) -> Void) { edit { p in if let i = p.slots.firstIndex(where: { $0.number == number }) { body(&p.slots[i]) } } }
    private func timeField(_ title: String, number: Int, key: WritableKeyPath<Bell, Int>, value: Int) -> some View {
        DatePicker(title, selection: Binding(get: { Self.date(value) }, set: { date in editBell(number) { $0[keyPath: key] = Day.minute(at: date) } }), displayedComponents: .hourAndMinute)
    }
    private func optionalTimeField(_ title: String, number: Int, key: WritableKeyPath<Bell, Int?>, value: Int) -> some View {
        DatePicker(title, selection: Binding(get: { Self.date(value) }, set: { date in editBell(number) { $0[keyPath: key] = Day.minute(at: date) } }), displayedComponents: .hourAndMinute)
    }
    static func date(_ minute: Int) -> Date { Day.calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Day().date)! }
    @discardableResult private func save() -> Bool {
        guard error == nil else { return false }
        let normalized = drafts.filter { !$0.value.slots.isEmpty }
        let result = store.change("Звонки сохранены") { $0.settings.bells = normalized }
        if result { drafts = normalized }
        return result
    }
}

struct BellGenerator: View {
    @Environment(\.dismiss) private var dismiss
    let apply: (BellProfile) -> Void
    @State private var count = 7
    @State private var start = 500
    @State private var study = 90
    @State private var gap = 10
    @State private var internalBreak = 0
    @State private var lunchAfter = 0
    @State private var lunch = 30
    private var profile: BellProfile { .generated(count: count, start: start, studyMinutes: study, gap: gap, internalBreak: internalBreak, lunchAfter: lunchAfter, lunchMinutes: lunch) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Пар: \(count)", value: $count, in: 1...7)
                    DatePicker("Начало", selection: Binding(get: { BellsView.date(start) }, set: { start = Day.minute(at: $0) }), displayedComponents: .hourAndMinute)
                    Stepper("Учебное время: \(study) мин", value: $study, in: 30...180, step: 5)
                    Stepper("Между парами: \(gap) мин", value: $gap, in: 0...60, step: 5)
                    Stepper("Внутри пары: \(internalBreak) мин", value: $internalBreak, in: 0...20, step: 5)
                    Picker("Обед после", selection: $lunchAfter) { Text("Без обеда").tag(0); ForEach(1...count, id: \.self) { Text("\($0)-й пары").tag($0) } }
                    if lunchAfter > 0 { Stepper("Обед: \(lunch) мин", value: $lunch, in: 5...90, step: 5) }
                } footer: { Text("Внутренний перерыв прибавляется к учебному времени пары.") }
                Section("Предпросмотр") {
                    ForEach(profile.slots) { bell in LabeledContent("\(bell.number)-я пара", value: "\(timeText(bell.start))–\(timeText(bell.end))") }
                    if profile.slots.count < count { Text("Не все пары помещаются до полуночи. Измените время начала или длительность.").foregroundStyle(.red) }
                }
            }
            .navigationTitle("Автозаполнение").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Применить") { apply(profile); dismiss() }.disabled(profile.validationError != nil || profile.slots.count != count) }
            }
            .onChange(of: count) { _, value in lunchAfter = min(lunchAfter, value) }
        }
    }
}
