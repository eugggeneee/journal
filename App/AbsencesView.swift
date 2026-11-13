import SwiftUI
import JournalCore

struct AbsencesView: View {
    @Environment(JournalStore.self) private var store
    @State private var mode = 0
    @State private var filter = 0
    @State private var editor: EditorRoute?
    @State private var semesterSettings = false
    @State private var selectedSubject: String?
    private var absences: [Absence] {
        store.data.absences.filter { filter == 0 || (filter == 1 ? !$0.excused : $0.excused) }.sorted { $0.day != $1.day ? $0.day > $1.day : $0.lesson < $1.lesson }
    }
    private var subjects: [String] { Array(Set(absences.map(\.subject))).sorted { store.data.name(for: $0) < store.data.name(for: $1) } }
    var body: some View {
        List {
            Section {
                LimitCard(title: "За месяц", subtitle: Day().formatted("LLLL yyyy").capitalized, status: store.data.monthStatus())
                Button { semesterSettings = true } label: {
                    let semester = Semester.current(on: Day(), settings: store.data.settings)
                    LimitCard(title: "За семестр", subtitle: semester.notStarted ? "Каникулы · с 1 сентября" : semester.title, status: store.data.semesterStatus())
                }.buttonStyle(.plain)
            } footer: { Text("Лимиты учитывают только часы без уважительной причины.") }
            ForEach([store.data.monthStatus(), store.data.semesterStatus()].filter { $0.isVisible(settings: store.data.settings) }, id: \.key) { status in
                Section {
                    HStack(alignment: .top) {
                        Label(status.hours >= status.limit ? "Лимит достигнут: \(status.hours) из \(status.limit) ч" : "До лимита осталось \(status.remaining) ч", systemImage: "exclamationmark.circle")
                            .foregroundStyle(status.level == 2 ? .red : .orange)
                        Spacer(minLength: 0)
                        Button { dismiss(status) } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }.accessibilityLabel("Скрыть предупреждение о лимите")
                    }
                }
            }
            Section {
                let total = store.data.absences.reduce(0) { $0 + $1.hours }
                let excused = store.data.absences.filter(\.excused).reduce(0) { $0 + $1.hours }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Всего за всё время").font(.subheadline).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(total)").font(.system(.largeTitle, design: .rounded, weight: .bold)).monospacedDigit()
                        Text(plural(total, "час", "часа", "часов")).foregroundStyle(.secondary)
                    }
                    LabeledContent("По уважительной", value: "\(excused) ч")
                    LabeledContent("Без уважительной", value: "\(total - excused) ч")
                    Text("≈ \(String(format: "%g", locale: Locale(identifier: "ru_RU"), Double(total) / 2)) пары").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }
            Section {
                Picker("Вид списка", selection: $mode) { Text("Предметы").tag(0); Text("Журнал").tag(1) }.pickerStyle(.segmented)
                Picker("Причина", selection: $filter) { Text("Все").tag(0); Text("Без уважительной").tag(1); Text("По уважительной").tag(2) }
            }
            if absences.isEmpty {
                ContentUnavailableView("Записей нет", systemImage: "checkmark.circle", description: Text(store.data.absences.isEmpty ? "Пропуски можно отмечать прямо в расписании или добавлять вручную." : "По выбранному фильтру пропусков нет."))
            } else if mode == 0 {
                Section("Часы по предметам") {
                    ForEach(subjects, id: \.self) { subject in
                        Button { selectedSubject = subject } label: {
                            let values = absences.filter { $0.subject == subject }
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(subject.isEmpty ? "Без предмета" : store.data.name(for: subject)).font(.headline)
                                    Text("\(values.count) \(plural(values.count, "запись", "записи", "записей")) · \(values.first?.day.formatted() ?? "")").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(values.reduce(0) { $0 + $1.hours }) ч").font(.title3.weight(.bold).monospacedDigit())
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(.vertical, 8)
                        }.buttonStyle(.plain)
                    }
                }
            } else {
                Section("Журнал") { ForEach(absences) { item in absenceRow(item) } }
            }
        }
        .navigationTitle("Пропуски")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Добавить пропуск", systemImage: "plus") { editor = .absence(Absence(hours: store.data.settings.absenceHours)) } } }
        .sheet(item: $editor) { EditorSheet(route: $0) }
        .sheet(isPresented: $semesterSettings) { NavigationStack { SemesterSettingsView() } }
        .sheet(isPresented: Binding(get: { selectedSubject != nil }, set: { if !$0 { selectedSubject = nil } })) {
            NavigationStack {
                List { ForEach(absences.filter { $0.subject == selectedSubject }) { item in absenceRow(item) } }
                    .navigationTitle(selectedSubject == "" ? "Без предмета" : store.data.name(for: selectedSubject ?? ""))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { selectedSubject = nil } } }
                    .sheet(item: $editor) { EditorSheet(route: $0) }
            }
        }
    }
    private func absenceRow(_ item: Absence) -> some View {
        Button { editor = .absence(item) } label: {
            HStack(spacing: 14) {
                Image(systemName: item.excused ? "checkmark.shield" : "person.crop.circle.badge.minus").font(.title2).foregroundStyle(item.excused ? Color.blue : .orange).frame(width: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.subject.isEmpty ? "Без предмета" : store.data.name(for: item.subject)).font(.headline)
                    Text("\(item.day.formatted())\(item.lesson > 0 ? " · \(item.lesson)-я пара" : "")").font(.subheadline).foregroundStyle(.secondary)
                    Text(item.excused ? "По уважительной" : "Без уважительной").font(.caption).foregroundStyle(.secondary)
                    if !item.note.isEmpty { Text(item.note).font(.subheadline).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 4)
                Text("\(item.hours) ч").font(.headline.monospacedDigit())
            }.padding(.vertical, 6)
        }.buttonStyle(.plain).accessibilityElement(children: .combine)
            .swipeActions { Button("Удалить", role: .destructive) { _ = store.change("Пропуск удалён") { $0.absences.removeAll { $0.id == item.id } } } }
    }
    private func dismiss(_ status: LimitStatus) {
        _ = store.change("Предупреждение скрыто") { data in
            let prefix = String(status.key.prefix(2))
            data.settings.dismissed = data.settings.dismissed.filter { !$0.key.hasPrefix(prefix) || $0.key == status.key }
            data.settings.dismissed[status.key] = status.level
        }
    }
}

struct LimitCard: View {
    let title: String
    let subtitle: String
    let status: LimitStatus
    private var color: Color { status.level == 2 ? .red : status.level == 1 ? .orange : .blue }
    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(color.opacity(0.12), lineWidth: 7)
                Circle().trim(from: 0, to: status.progress).stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(status.hours)").font(.title2.weight(.bold).monospacedDigit())
            }.frame(width: 64, height: 64).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                Text(status.hours > status.limit ? "Превышено на \(status.hours - status.limit) ч" : status.hours == status.limit ? "Лимит достигнут" : "Осталось \(status.remaining) из \(status.limit) ч").font(.subheadline.weight(.medium)).foregroundStyle(color)
            }
        }.padding(.vertical, 12).accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(subtitle). \(status.hours) часов из \(status.limit). Осталось \(status.remaining) часов.")
    }
}
