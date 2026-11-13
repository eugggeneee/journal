import SwiftUI
import JournalCore

struct AbsencesView: View {
    @Environment(JournalStore.self) private var store
    @State private var mode = 0
    @State private var filter = 0
    @State private var editor: EditorRoute?
    @State private var subjectEditor: EditorRoute?
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
            Section("За всё время") {
                let total = store.data.absences.reduce(0) { $0 + $1.hours }
                let excused = store.data.absences.filter(\.excused).reduce(0) { $0 + $1.hours }
                LabeledContent("Всего пропущено", value: "\(total) \(plural(total, "час", "часа", "часов"))")
                LabeledContent("По уважительной", value: "\(excused) ч")
                LabeledContent("Без уважительной", value: "\(total - excused) ч")
            }
            Section {
                Picker("Вид списка", selection: $mode) { Text("Предметы").tag(0); Text("Журнал").tag(1) }.pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
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
                                    Text(subject.isEmpty ? "Без предмета" : store.data.name(for: subject)).font(.headline.bold())
                                    Text("\(values.count) \(plural(values.count, "запись", "записи", "записей")) · \(values.first?.day.formatted() ?? "")").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(values.reduce(0) { $0 + $1.hours }) ч").font(.title3.weight(.bold).monospacedDigit())
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }.padding(.vertical, 3)
                        }.buttonStyle(.plain)
                    }
                }
            } else {
                Section("Журнал") { ForEach(absences) { item in absenceRow(item) } }
            }
        }
        .navigationTitle("Пропуски")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Причина", selection: $filter) { Text("Все").tag(0); Text("Без уважительной").tag(1); Text("По уважительной").tag(2) }
                } label: { Image(systemName: filter == 0 ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") }
                    .accessibilityLabel("Причина пропуска: \(filter == 0 ? "все" : filter == 1 ? "без уважительной" : "по уважительной")")
                Button("Добавить пропуск", systemImage: "plus") { editor = .absence(Absence(hours: store.data.settings.absenceHours)) }
            }
        }
        .sheet(item: $editor) { EditorSheet(route: $0) }
        .sheet(isPresented: $semesterSettings) { NavigationStack { SemesterSettingsView() } }
        .sheet(isPresented: Binding(get: { selectedSubject != nil }, set: { if !$0 { selectedSubject = nil } })) {
            NavigationStack {
                List { ForEach(absences.filter { $0.subject == selectedSubject }) { item in absenceRow(item, nested: true) } }
                    .navigationTitle(selectedSubject == "" ? "Без предмета" : store.data.name(for: selectedSubject ?? ""))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { selectedSubject = nil } } }
                    .sheet(item: $subjectEditor) { EditorSheet(route: $0) }
            }
        }
    }
    private func absenceRow(_ item: Absence, nested: Bool = false) -> some View {
        Button { if nested { subjectEditor = .absence(item) } else { editor = .absence(item) } } label: {
            HStack(spacing: 12) {
                Image(systemName: item.excused ? "checkmark.shield" : "person.crop.circle.badge.minus").font(.title2).foregroundStyle(item.excused ? Color.blue : .orange).frame(width: 40).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.subject.isEmpty ? "Без предмета" : store.data.name(for: item.subject)).font(.headline.bold())
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Label(title, systemImage: status.key.hasPrefix("m:") ? "calendar" : "graduationcap.fill")
                    .font(.headline.bold())
                Spacer(minLength: 8)
                Text("\(status.hours) / \(status.limit) ч").font(.body.bold().monospacedDigit())
            }
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            ProgressView(value: status.progress).tint(color).accessibilityHidden(true)
            Text(status.hours > status.limit ? "Превышено на \(status.hours - status.limit) ч" : status.hours == status.limit ? "Лимит достигнут" : "До лимита осталось \(status.remaining) ч")
                .font(.subheadline).foregroundStyle(status.level > 0 ? color : .secondary)
        }.padding(.vertical, 7).accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(subtitle). \(status.hours) часов из \(status.limit). Осталось \(status.remaining) часов.")
            .accessibilityIdentifier(status.key.hasPrefix("m:") ? "month-limit" : "semester-limit")
    }
}
