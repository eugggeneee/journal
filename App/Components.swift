import SwiftUI
import JournalCore

enum JournalStyle {
    static let accent = Color("AccentColor")
    static let page = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let warm = accent
    static func gradeColor(_ value: Int) -> Color {
        switch value { case 1...3: .red; case 4...5: .orange; case 6...7: .blue; default: .green }
    }
}

struct EmptyCard: View {
    let title: String
    let detail: String
    var symbol = "calendar.badge.clock"
    var body: some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }
}

struct GradeBadge: View {
    let value: Int
    var body: some View {
        Text("\(value)").font(.body.bold().monospacedDigit())
            .foregroundStyle(.primary)
            .frame(width: 36, height: 36)
            .background(JournalStyle.gradeColor(value).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Оценка \(value)")
    }
}

struct DateField: View {
    var title = "Дата"
    @Binding var day: Day
    var body: some View {
        DatePicker(title, selection: Binding(get: { day.date }, set: { day = Day($0) }), displayedComponents: .date)
    }
}

struct SubjectField: View {
    @Environment(JournalStore.self) private var store
    @Binding var subject: String
    var day: Day
    @State private var showing = false
    var body: some View {
        Button { showing = true } label: {
            LabeledContent("Предмет") {
                Text(subject.isEmpty ? "Выбрать" : store.data.name(for: subject)).foregroundStyle(subject.isEmpty ? .secondary : .primary).multilineTextAlignment(.trailing)
            }
        }
        .sheet(isPresented: $showing) { SubjectPicker(subject: $subject, day: day) }
    }
}

struct SubjectPicker: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var subject: String
    let day: Day
    @State private var query = ""
    private var todaySubjects: [String] { Array(Set(store.data.schedule(day)?.lessons.flatMap(\.entries).map(\.subject) ?? [])).sorted() }
    private func matches(_ key: String) -> Bool { query.isEmpty || store.data.name(for: key).localizedCaseInsensitiveContains(query) || key.localizedCaseInsensitiveContains(query) }
    var body: some View {
        NavigationStack {
            List {
                if !todaySubjects.isEmpty {
                    Section("В расписании на \(day.formatted())") { ForEach(todaySubjects.filter(matches), id: \.self) { row($0) } }
                }
                Section("Все предметы") { ForEach(store.data.subjects.filter { !todaySubjects.contains($0) && matches($0) }, id: \.self) { row($0) } }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !store.data.subjects.contains(trimmed) {
                    Button("Добавить «\(trimmed)»", systemImage: "plus") {
                        if store.change("Предмет добавлен", { $0.settings.extraSubjects.append(trimmed) }) { subject = trimmed; dismiss() }
                    }
                }
            }
            .searchable(text: $query, prompt: "Найти или добавить предмет")
            .navigationTitle("Предмет")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } }
        }
    }
    private func row(_ key: String) -> some View {
        Button { subject = key; dismiss() } label: {
            HStack { Text(store.data.name(for: key)).foregroundStyle(.primary); Spacer(); if subject == key { Image(systemName: "checkmark") } }
        }.frame(minHeight: 44)
    }
}

struct GroupPicker: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var groups: [String] = []
    @State private var message: String?
    @State private var busy = true
    var embedded = false
    var body: some View {
        if embedded { picker }
        else { NavigationStack { picker.toolbar { ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() } } } } }
    }
    private var picker: some View {
            List {
                if busy { HStack { ProgressView(); Text("Ищем группы на сайте…") } }
                if let message { Section { Text(message).foregroundStyle(.secondary); Button("Повторить") { Task { await fetch() } }.disabled(busy) } }
                Section(query.isEmpty ? "Группы на сайте · \(groups.count)" : "Найденные группы") {
                    ForEach(groups.filter { query.isEmpty || $0.contains(query) }, id: \.self) { group in
                        Button { select(group) } label: {
                            HStack { Text(group).foregroundStyle(.primary); Spacer(); if group == store.data.settings.group { Image(systemName: "checkmark") } }
                        }.frame(minHeight: 44).accessibilityIdentifier("group-option-\(group)")
                    }
                }
                if validGroup(query) && !groups.contains(query) { Button("Использовать группу \(query)") { select(query) }.frame(minHeight: 44) }
                Section { Text("Не нашли свою группу? Введите её номер: от 3 до 5 цифр.").font(.footnote).foregroundStyle(.secondary) }
            }
            .searchable(text: $query, prompt: "Номер группы")
            .onChange(of: query) { _, value in query = String(value.filter { $0.isASCII && $0.isNumber }.prefix(5)) }
            .navigationTitle("Ваша группа")
            .task { await fetch() }
    }
    private func select(_ group: String) { store.chooseGroup(group); if store.data.settings.group == group { dismiss() } }
    private func fetch() async { busy = true; defer { busy = false }; let result = await store.groups(); groups = result.groups; message = result.message }
}
