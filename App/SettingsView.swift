import SwiftUI
import UniformTypeIdentifiers
import JournalCore

struct SettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var groupPicker = false
    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image("AppArtwork").resizable().frame(width: 64, height: 64).clipShape(RoundedRectangle(cornerRadius: 16)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) { Text("Journal").font(.title2.bold()); Text("Учёба в своём ритме").foregroundStyle(.secondary) }
                }.padding(.vertical, 8)
                Button { groupPicker = true } label: { LabeledContent("Группа", value: store.data.settings.group) }
            }
            Section("Расписание") {
                NavigationLink("Звонки", value: SettingsRoute.bells)
                Toggle("Автообновление", isOn: setting(\.autoRefresh, "Автообновление изменено"))
                Button("Обновить ближайшие дни", systemImage: "arrow.clockwise") { Task { await store.prefetch(force: true) } }
            }
            Section("Пропуски") {
                Picker("Быстрая отметка", selection: setting(\.absenceHours, "Быстрая отметка изменена")) { Text("1 час").tag(1); Text("2 часа · пара").tag(2) }
                NavigationLink("Лимиты и семестры", value: SettingsRoute.semester)
            }
            Section {
                Toggle("Тактильный отклик", isOn: setting(\.haptics, "Тактильный отклик изменён"))
                NavigationLink("Названия предметов", value: SettingsRoute.subjects)
            }
            Section("Данные") {
                NavigationLink("Резервная копия", value: SettingsRoute.backup)
                NavigationLink("О приложении и конфиденциальность", value: SettingsRoute.about)
            }
            Section {
                Text("Версия \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")").font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Настройки").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        .navigationDestination(isPresented: $groupPicker) { GroupPicker(embedded: true) }
        .navigationDestination(for: SettingsRoute.self) { route in
            switch route {
            case .bells: BellsView()
            case .semester: SemesterSettingsView()
            case .subjects: SubjectSettingsView()
            case .backup: BackupView()
            case .about: AboutView()
            }
        }
    }
    private func setting<Value>(_ key: WritableKeyPath<Settings, Value>, _ title: String) -> Binding<Value> {
        Binding(get: { store.data.settings[keyPath: key] }, set: { value in _ = store.change(title) { $0.settings[keyPath: key] = value } })
    }
}

enum SettingsRoute: Hashable { case bells, semester, subjects, backup, about }

struct SemesterSettingsView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var limits = Limits()
    @State private var confirmation = false
    private var semester: Semester { Semester.current(on: Day(), settings: store.data.settings) }
    private var canSplit: Bool { !semester.notStarted && semester.number == 1 && Day() > semester.start }
    var body: some View {
        Form {
            Section {
                Text(semester.notStarted ? "Каникулы · с 1 сентября" : semester.title).font(.headline.bold())
                Text("\(semester.start.formatted("d MMMM yyyy")) — \(semester.end.formatted("d MMMM yyyy"))").foregroundStyle(.secondary)
                Button(semester.number == 2 ? "Вернуть первый семестр" : "Завершить первый семестр") { confirmation = true }
                    .disabled(semester.number != 2 && !canSplit)
            } header: { Text("Этот учебный год") } footer: { Text("При завершении второй семестр начинается сегодня. Старые пропуски остаются в журнале. Действие можно отменить.") }
            Section("Месяц · неуважительные часы") {
                Stepper("Лимит: \(limits.month) ч", value: $limits.month, in: 1...1000)
                Stepper("Предупреждать с \(limits.monthWarning) ч", value: $limits.monthWarning, in: 0...max(0, limits.month - 1))
            }
            Section("Семестр · неуважительные часы") {
                Stepper("Лимит: \(limits.semester) ч", value: $limits.semester, in: 1...1000)
                Stepper("Предупреждать с \(limits.semesterWarning) ч", value: $limits.semesterWarning, in: 0...max(0, limits.semester - 1))
            }
            Section {
                Button("Сохранить лимиты") {
                    _ = store.change("Лимиты изменены") { $0.settings.limits = limits; $0.settings.dismissed = [:] }
                }.disabled(!limits.isValid || limits == store.data.settings.limits)
                Button("Стандартные значения: 10 и 72 ч") { limits = Limits() }
            } footer: { Text("Лимиты — ваши ориентиры. Уточняйте действующие правила в колледже.") }
        }
        .navigationTitle("Лимиты и семестры").navigationBarTitleDisplayMode(.inline)
        .onAppear { limits = store.data.settings.limits }
        .onChange(of: limits.month) { _, value in limits.monthWarning = min(limits.monthWarning, value - 1) }
        .onChange(of: limits.semester) { _, value in limits.semesterWarning = min(limits.semesterWarning, value - 1) }
        .confirmationDialog(semester.number == 2 ? "Вернуть первый семестр?" : "Завершить первый семестр сегодня?", isPresented: $confirmation, titleVisibility: .visible) {
            Button(semester.number == 2 ? "Вернуть первый семестр" : "Начать второй семестр") {
                _ = store.change("Граница семестров изменена") { data in
                    if semester.number == 2 { data.settings.semesterSplits.removeValue(forKey: String(semester.year)) }
                    else if canSplit { data.settings.semesterSplits[String(semester.year)] = Day() }
                    data.settings.dismissed = data.settings.dismissed.filter { !$0.key.hasPrefix("s:") }
                }
            }
        } message: { Text("Оценки и пропуски сохранятся. Изменится период подсчёта лимита.") }
    }
}

struct SubjectSettingsView: View {
    @Environment(JournalStore.self) private var store
    @State private var selected: String?
    @State private var name = ""
    @State private var query = ""
    var body: some View {
        List {
            Section { Text("Можно изменить отображаемое название. Связь с расписанием и старыми записями сохранится.").foregroundStyle(.secondary) }
            ForEach(store.data.subjects.filter { query.isEmpty || store.data.name(for: $0).localizedCaseInsensitiveContains(query) }, id: \.self) { key in
                Button { selected = key; name = store.data.name(for: key) } label: {
                    VStack(alignment: .leading, spacing: 4) { Text(store.data.name(for: key)).foregroundStyle(.primary); Text(key).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .navigationTitle("Названия предметов").searchable(text: $query, prompt: "Найти предмет")
        .alert("Название предмета", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            TextField("Название", text: $name)
            Button("Сохранить") { if let key = selected { _ = store.change("Название предмета изменено") { $0.settings.subjectNames[key] = name.trimmingCharacters(in: .whitespacesAndNewlines) } }; selected = nil }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Вернуть исходное") { if let key = selected { _ = store.change("Название восстановлено") { $0.settings.subjectNames.removeValue(forKey: key) } }; selected = nil }
            Button("Отмена", role: .cancel) { selected = nil }
        }
    }
}

struct BackupFile: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var bytes: Data
    init(bytes: Data) { self.bytes = bytes }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw JournalError("Не удалось прочитать файл.") }
        bytes = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: bytes) }
}

struct BackupView: View {
    @Environment(JournalStore.self) private var store
    @State private var document: BackupFile?
    @State private var exporting = false
    @State private var importing = false
    @State private var report: BackupReport?
    @State private var preview = false
    @State private var message: String?
    var body: some View {
        Form {
            Section {
                Label("Всё важное в одном файле", systemImage: "externaldrive.badge.checkmark").font(.headline.bold())
                Text("Оценки, пропуски, пометки, звонки, настройки и вся сохранённая история расписания.").foregroundStyle(.secondary)
                Button("Сохранить копию в «Файлы»", systemImage: "square.and.arrow.up") {
                    do { document = BackupFile(bytes: try BackupCodec.encode(store.data)); exporting = true }
                    catch { store.errorMessage = error.localizedDescription }
                }
                Button("Восстановить из «Файлов»", systemImage: "square.and.arrow.down") { importing = true }
            } footer: { Text("Сохраняйте копию перед удалением приложения, сменой телефона или способа подписи. Автоматической синхронизации нет.") }
            Section {
                LabeledContent("Оценок", value: "\(store.data.grades.count)")
                LabeledContent("Пропусков", value: "\(store.data.absences.count)")
                LabeledContent("Пометок", value: "\(store.data.notes.count)")
                LabeledContent("Дней в архиве", value: "\(store.data.schedules.count)")
            }
            if let message { Section { Label(message, systemImage: "checkmark.circle").foregroundStyle(.secondary) } }
            if !store.recoveryFiles.isEmpty {
                Section("Файлы восстановления") {
                    ForEach(store.recoveryFiles, id: \.self) { url in ShareLink(item: url) { Label("Сохранить исходный файл", systemImage: "square.and.arrow.up") } }
                }
            }
        }
        .navigationTitle("Резервная копия").navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "Journal-\(Day().rawValue)") { result in
            switch result { case .success: message = "Копия сохранена."; case .failure(let error): store.errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            do {
                let url = try result.get()
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 64 * 1024 * 1024 else { throw JournalError("Копия больше 64 МБ.") }
                report = try BackupCodec.decode(Data(contentsOf: url)); preview = true
            } catch { store.errorMessage = error.localizedDescription }
        }
        .confirmationDialog("Заменить текущие данные?", isPresented: $preview, titleVisibility: .visible) {
            Button("Восстановить копию", role: .destructive) { if let report, store.restore(report) { message = "Данные восстановлены." }; report = nil }
            Button("Отмена", role: .cancel) { report = nil }
        } message: {
            if let report { Text(report.summary + (report.discarded > 0 ? "\nПовреждённых или повторных записей будет пропущено: \(report.discarded)." : "") + "\nТекущие данные будут заменены. После восстановления доступна отмена.") }
        }
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section("Для учёбы") {
                Text("Journal — неофициальный дневник студента МГТЭК. Расписание, оценки и пропуски в одном приложении.")
                Text("Расписание загружается с общедоступной страницы bseumtc.by. Колледж может изменить его после загрузки; сверяйте важные изменения.").foregroundStyle(.secondary)
            }
            Section("Ваши данные") {
                Text("Данные хранятся на iPhone. Journal не требует аккаунта, не показывает рекламу и не собирает аналитику.")
                Text("Приложение обращается только к сайту колледжа для загрузки расписания. Ссылки ниже открываются отдельно — в браузере.")
                Text("Загруженные дни, оценки, пропуски и пометки доступны без интернета. Чтобы не потерять их при переустановке, сохраните резервную копию.")
            }
            Section("Открытый проект") {
                Link("Исходный код и новые версии", destination: URL(string: "https://github.com/eugggeneee/journal")!)
                Link("Сообщить о проблеме", destination: URL(string: "https://github.com/eugggeneee/journal/issues/new/choose")!)
                Text("Автор: eugggeneee · лицензия MIT").foregroundStyle(.secondary)
            }
        }.navigationTitle("О Journal").navigationBarTitleDisplayMode(.inline)
    }
}
