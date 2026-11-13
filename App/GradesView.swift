import SwiftUI
import Charts
import JournalCore

struct GradesView: View {
    @Environment(JournalStore.self) private var store
    @State private var mode = 0
    @State private var period = 0
    @State private var search = ""
    @State private var editor: EditorRoute?
    private var semester: Semester { Semester.current(on: Day(), settings: store.data.settings) }
    private var grades: [Grade] { store.data.grades.filter { period == 0 || (!semester.notStarted && semester.contains($0.day)) } }
    private var subjects: [String] { Array(Set(grades.map(\.subject))).filter { search.isEmpty || store.data.name(for: $0).localizedCaseInsensitiveContains(search) }.sorted { store.data.name(for: $0) < store.data.name(for: $1) } }
    private var journal: [Grade] { GradeMath.ordered(grades).reversed().filter { search.isEmpty || store.data.name(for: $0.subject).localizedCaseInsensitiveContains(search) || $0.note.localizedCaseInsensitiveContains(search) } }
    var body: some View {
        List {
            Section {
                HStack(alignment: .firstTextBaseline) {
                    Label("Средний балл", systemImage: "chart.bar.fill").font(.headline.bold()).foregroundStyle(JournalStyle.accent)
                    Spacer()
                    periodMenu
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(GradeMath.formatted(GradeMath.average(grades))).font(.largeTitle.bold()).monospacedDigit()
                    Text("из 10").foregroundStyle(.secondary)
                    Spacer()
                }.accessibilityIdentifier("grade-average")
                HStack {
                    Text("\(grades.count) \(plural(grades.count, "оценка", "оценки", "оценок"))")
                    Spacer()
                    Text("\(Set(grades.map(\.subject)).count) \(plural(Set(grades.map(\.subject)).count, "предмет", "предмета", "предметов"))")
                }.font(.subheadline).foregroundStyle(.secondary)
                if !grades.isEmpty {
                    Chart(1...10, id: \.self) { value in
                        BarMark(x: .value("Оценка", String(value)), y: .value("Количество", grades.filter { $0.value == value }.count))
                            .foregroundStyle(Color.orange).cornerRadius(3)
                    }.frame(height: 82).chartYAxis(.hidden)
                        .accessibilityLabel("Распределение оценок от 1 до 10")
                }
            } header: { Text("Сводка") }
            Section {
                Picker("Вид списка", selection: $mode) { Text("Предметы").tag(0); Text("Журнал").tag(1) }.pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
            }
            if grades.isEmpty {
                ContentUnavailableView("Пока без оценок", systemImage: "chart.bar.xaxis", description: Text("Добавьте первую оценку — Journal посчитает средний балл и покажет прогресс."))
                Button("Добавить оценку", systemImage: "plus") { add() }
            } else if mode == 0 {
                Section("Предметы") {
                    ForEach(subjects, id: \.self) { subject in
                        NavigationLink(value: subject) {
                            let values = grades.filter { $0.subject == subject }
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(store.data.name(for: subject)).font(.headline.bold())
                                    Text("\(values.count) \(plural(values.count, "оценка", "оценки", "оценок")) · последняя \(GradeMath.ordered(values).last?.value ?? 0)").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 4)
                                Text(GradeMath.formatted(GradeMath.average(values))).font(.title3.weight(.bold).monospacedDigit())
                            }.padding(.vertical, 3)
                        }
                    }
                }
            } else {
                Section("Последние оценки") {
                    ForEach(journal) { grade in
                        Button { editor = .grade(grade) } label: { GradeRow(grade: grade) }.buttonStyle(.plain)
                            .swipeActions { Button("Удалить", role: .destructive) { _ = store.change("Оценка удалена") { $0.grades.removeAll { $0.id == grade.id } } } }
                    }
                }
            }
        }
        .navigationTitle("Оценки").searchable(text: $search, prompt: "Предмет или заметка")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Добавить оценку", systemImage: "plus") { add() }.accessibilityIdentifier("add-grade") } }
        .navigationDestination(for: String.self) { SubjectDetail(subject: $0) }
        .sheet(item: $editor) { EditorSheet(route: $0) }
    }
    private var periodMenu: some View {
        Menu {
            Button("Всё время") { period = 0 }
            Button("Этот семестр") { period = 1 }
        } label: {
            Label(period == 0 ? "Всё время" : "Этот семестр", systemImage: "chevron.down")
                .font(.caption.weight(.regular)).fixedSize(horizontal: false, vertical: true).frame(minHeight: 44)
        }
    }
    private func add() { editor = .grade(Grade(subject: GradeMath.ordered(store.data.grades).last?.subject ?? "")) }
}

struct GradeRow: View {
    @Environment(JournalStore.self) private var store
    let grade: Grade
    var body: some View {
        HStack(spacing: 12) {
            GradeBadge(value: grade.value)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.data.name(for: grade.subject)).font(.headline.bold())
                Text([grade.day.formatted(), grade.kind].filter { !$0.isEmpty }.joined(separator: " · ")).font(.subheadline).foregroundStyle(.secondary)
                if !grade.note.isEmpty { Text(grade.note).font(.subheadline).foregroundStyle(.secondary) }
            }
        }.padding(.vertical, 4).accessibilityElement(children: .combine)
    }
}

struct SubjectDetail: View {
    @Environment(JournalStore.self) private var store
    let subject: String
    @State private var editor: EditorRoute?
    private var grades: [Grade] { GradeMath.ordered(store.data.grades.filter { $0.subject == subject }) }
    var body: some View {
        List {
            Section {
                Text(GradeMath.formatted(GradeMath.average(grades))).font(.largeTitle.bold()).monospacedDigit()
                if let change = GradeMath.change(grades) { Text(String(format: "%+.2f после последней оценки", locale: Locale(identifier: "ru_RU"), change)).foregroundStyle(change >= 0 ? .green : .orange) }
                if !grades.isEmpty {
                    Chart(Array(grades.enumerated()), id: \.element.id) { index, grade in
                        LineMark(x: .value("По порядку", index + 1), y: .value("Оценка", grade.value)).foregroundStyle(JournalStyle.accent)
                        PointMark(x: .value("По порядку", index + 1), y: .value("Оценка", grade.value)).foregroundStyle(JournalStyle.gradeColor(grade.value))
                    }.chartYScale(domain: 1...10).frame(height: 180)
                }
            } header: { Text("Средний балл за всё время") }
            Section("Все оценки") {
                ForEach(grades.reversed()) { grade in
                    Button { editor = .grade(grade) } label: { GradeRow(grade: grade) }.buttonStyle(.plain)
                        .swipeActions { Button("Удалить", role: .destructive) { _ = store.change("Оценка удалена") { $0.grades.removeAll { $0.id == grade.id } } } }
                }
            }
        }
        .navigationTitle(store.data.name(for: subject)).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Добавить оценку", systemImage: "plus") { editor = .grade(Grade(subject: subject)) } } }
        .sheet(item: $editor) { EditorSheet(route: $0) }
    }
}
