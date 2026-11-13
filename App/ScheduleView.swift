import SwiftUI
import JournalCore

struct ScheduleView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var day = Day()
    @State private var lastToday = Day()
    @State private var datePicker = false
    @State private var groupPicker = false
    @State private var bells = false
    @State private var editor: EditorRoute?
    @State private var wholeDayReason = false
    @State private var wholeDayConfirmation = false
    private var schedule: Schedule? { store.data.schedule(day) }
    private var title: String {
        if day == Day() { return "Сегодня" }
        if day == Day().adding(1) { return "Завтра" }
        if day == Day().adding(-1) { return "Вчера" }
        return day.formatted("EEEE").capitalized
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.formatted("d MMMM · EEEE")).font(.subheadline).foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Button { groupPicker = true } label: { Text(store.data.settings.group).font(.subheadline.weight(.semibold)).padding(.horizontal, 14).frame(minHeight: 44).journalGlass() }
                        .accessibilityLabel("Группа \(store.data.settings.group). Сменить группу")
                }
                dateStrip
                if let note = store.data.note(day) { noteCard(note) }
                if let schedule, !schedule.lessons.isEmpty, !day.isSunday, !day.isVacation {
                    summary(schedule)
                    if day == Day() {
                        TimelineView(.periodic(from: .now, by: 30)) { timeline in
                            if let phase = DayPhase.current(schedule: schedule, profile: store.data.profile(day), minute: Day.minute(at: store.displayTime(timeline.date))) {
                                NowCard(phase: phase, schedule: schedule)
                            }
                        }
                    }
                    SectionHeading(title: "Пары", detail: "\(schedule.lessons.count) \(plural(schedule.lessons.count, "пара", "пары", "пар"))")
                    ForEach(Array(schedule.lessons.enumerated()), id: \.element.id) { index, lesson in
                        lessonCard(lesson)
                        if index + 1 < schedule.lessons.count { breakLabel(after: lesson, next: schedule.lessons[index + 1]) }
                    }
                    switch store.state(day) {
                    case .ready(let status): Text(status).font(.footnote).foregroundStyle(.secondary)
                    case .empty(_, let message): Text(message).font(.footnote).foregroundStyle(.secondary)
                    case .loading: ProgressView("Обновляем расписание…")
                    }
                } else {
                    switch store.state(day) {
                    case .loading: Surface { HStack(spacing: 12) { ProgressView(); Text("Загружаем расписание…").foregroundStyle(.secondary) }.padding(.vertical, 24) }
                    case .empty(let title, let message):
                        EmptyCard(title: title, detail: message, symbol: day.isSunday || day.isVacation ? "sun.max" : "calendar.badge.clock")
                    case .ready: EmptyCard(title: "Занятий нет", detail: "Для выбранной группы на этот день пар нет.", symbol: "sun.max")
                    }
                    if !day.isSunday && !day.isVacation { Button("Проверить ещё раз", systemImage: "arrow.clockwise") { Task { await store.load(day, force: true) } }.frame(minHeight: 44) }
                    if day.isSunday { weeklySummary }
                    if let next = nextSaved {
                        Button { day = next.day } label: {
                            Surface { HStack { VStack(alignment: .leading, spacing: 4) { Text("Дальше · \(next.day.formatted())").font(.headline); Text("\(next.lessons.count) \(plural(next.lessons.count, "пара", "пары", "пар"))").foregroundStyle(.secondary) }; Spacer(); Image(systemName: "arrow.right") } }
                        }.foregroundStyle(.primary)
                    }
                }
                ForEach(store.data.notes.filter { note in note.day == day && note.lesson > 0 && !(schedule?.lessons.contains { $0.number == note.lesson } ?? false) }) { note in noteCard(note) }
                if store.data.note(day) == nil {
                    Button("Пометка на день", systemImage: "note.text.badge.plus") { editor = .note(DayNote(day: day)) }.frame(minHeight: 44)
                }
                Text("Время занятий — по Минску").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.top, 8)
            }.padding(.horizontal, 20).padding(.bottom, 24)
        }
        .background(JournalStyle.page)
        .navigationTitle(title)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if day != Day() { Button("Сегодня") { day = Day() } }
                Button("Выбрать дату", systemImage: "calendar") { datePicker = true }
                Menu {
                    Button("Добавить оценку", systemImage: "plus.circle") { editor = .grade(Grade(day: day, subject: store.data.grades.sorted { $0.day > $1.day }.first?.subject ?? "")) }
                    Button("Добавить пропуск", systemImage: "person.crop.circle.badge.minus") { editor = .absence(Absence(day: day, hours: store.data.settings.absenceHours)) }
                    Button("Добавить пометку", systemImage: "note.text") { editor = .note(store.data.note(day) ?? DayNote(day: day)) }
                    Divider()
                    Button("Звонки", systemImage: "clock") { bells = true }
                    Button("Обновить расписание", systemImage: "arrow.clockwise") { Task { await store.load(day, force: true); await store.prefetch(force: true) } }
                } label: { Image(systemName: "plus") }.accessibilityLabel("Добавить и другие действия")
            }
        }
        .sheet(isPresented: $datePicker) {
            NavigationStack {
                DatePicker("Выбрать дату", selection: Binding(get: { day.date }, set: { day = Day($0) }), in: Day().adding(-120).date...Day().adding(90).date, displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("Дата").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { datePicker = false } } }
            }.presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $groupPicker) { GroupPicker() }
        .sheet(isPresented: $bells) { NavigationStack { BellsView(initial: store.data.bellKind(day)) } }
        .sheet(item: $editor) { EditorSheet(route: $0) }
        .confirmationDialog("Заменить отметки пропусков на весь день?", isPresented: $wholeDayConfirmation, titleVisibility: .visible) {
            Button("Отметить весь день") { if let schedule { markWholeDay(schedule, excused: wholeDayReason) } }
        } message: { Text("Уже отмеченные пары получат выбранную причину и количество часов. Действие можно отменить.") }
        .refreshable { await store.load(day, force: true) }
        .task(id: "\(day.rawValue)|\(store.data.settings.group)") { await store.load(day) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && Day() != lastToday { lastToday = Day(); day = Day() }
        }
    }

    private var dateStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 6) {
                    ForEach((-120...90).map { Day().adding($0) }) { date in
                        Button { day = date } label: {
                            VStack(spacing: 8) {
                                Text(date.formatted("EE").uppercased()).font(.caption2.weight(.semibold))
                                Text("\(date.number)").font(.title3.weight(.semibold).monospacedDigit())
                                Circle().fill(store.data.notes.contains { $0.day == date } || store.data.absences.contains { $0.day == date } ? (day == date ? Color(uiColor: .systemBackground) : Color.primary) : Color.clear).frame(width: 4, height: 4)
                            }
                            .foregroundStyle(day == date ? Color(uiColor: .systemBackground) : date.isSunday ? .secondary : .primary)
                            .frame(minWidth: 46, minHeight: 82)
                            .background(day == date ? Color.primary : Color.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(date == Day() && date != day ? Color.orange : .clear, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain).id(date)
                        .accessibilityLabel(date.formatted("EEEE d MMMM"))
                        .accessibilityAddTraits(day == date ? [.isSelected] : [])
                    }
                }.padding(.vertical, 4)
            }.scrollIndicators(.hidden)
                .onAppear { proxy.scrollTo(day, anchor: .center) }
                .onChange(of: day) { _, value in proxy.scrollTo(value, anchor: .center) }
        }
    }
    private func summary(_ schedule: Schedule) -> some View {
        let profile = store.data.profile(day)
        let slots = schedule.lessons.compactMap { profile.bell($0.number) }
        let missed = store.data.absences.filter { $0.day == day }.reduce(0) { $0 + $1.hours }
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                if let first = slots.first, let last = slots.last { Text("\(timeText(first.start)) — \(timeText(last.end))").font(.title2.weight(.bold).monospacedDigit()) }
                else { Button("Добавить время пар", systemImage: "clock") { bells = true }.font(.headline).frame(minHeight: 44) }
                if missed > 0 { Text("Пропущено \(missed) \(plural(missed, "час", "часа", "часов"))").font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
            Menu {
                Button("Весь день · без уважительной") { requestWholeDay(schedule, excused: false) }
                Button("Весь день · по уважительной") { requestWholeDay(schedule, excused: true) }
                Button("Снять все пропуски дня", role: .destructive) { _ = store.change("Пропуски дня сняты") { data in data.absences.removeAll { $0.day == day } } }
                Button("Сокращённый день", systemImage: "clock.badge.checkmark") { editor = .note(DayNote(day: day, kind: .shortened)) }
            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44).journalGlass() }.accessibilityLabel("Действия со всем днём")
        }.padding(.vertical, 8)
    }
    private func lessonCard(_ lesson: Lesson) -> some View {
        let bell = store.data.profile(day).bell(lesson.number)
        let absence = store.data.absence(day, lesson: lesson.number)
        return Surface(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 6) {
                    Text("\(lesson.number)").font(.title2.weight(.semibold).monospacedDigit()).foregroundStyle(.orange)
                    if let bell { Text(timeText(bell.start)).font(.caption.weight(.medium).monospacedDigit()); Text(timeText(bell.end)).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                }.frame(minWidth: 44).accessibilityHidden(true)
                Button { editor = .lesson(day, lesson) } label: {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(lesson.entries.enumerated()), id: \.offset) { _, entry in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.data.name(for: entry.subject)).font(.headline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                if !entry.room.isEmpty { Label(entry.room.contains(where: \.isNumber) ? "ауд. \(entry.room)" : entry.room, systemImage: "door.left.hand.open").font(.subheadline).foregroundStyle(.secondary) }
                                if !entry.teacher.isEmpty { Text(entry.teacher).font(.subheadline).foregroundStyle(.secondary) }
                            }
                        }
                        if let note = store.data.note(day, lesson: lesson.number) { Label(note.title, systemImage: "note.text").font(.subheadline.weight(.medium)).foregroundStyle(.orange) }
                        if let absence { Label("\(absence.hours) ч · \(absence.excused ? "уважительная" : "без уважительной")", systemImage: "person.crop.circle.badge.minus").font(.caption).foregroundStyle(absence.excused ? Color.secondary : Color.red) }
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityLabel("\(lesson.number)-я пара. \(lesson.entries.map { store.data.name(for: $0.subject) }.joined(separator: ", ")). \(bell.map { timeText($0.start) + "–" + timeText($0.end) } ?? "Время не задано"). Подробнее")
                Menu {
                    if let absence {
                        Button("Изменить пропуск") { editor = .absence(absence) }
                        Button("Снять пропуск", role: .destructive) { _ = store.change("Пропуск снят") { $0.absences.removeAll { $0.id == absence.id } } }
                    } else {
                        ForEach(Array(lesson.entries.enumerated()), id: \.offset) { _, entry in
                            Section(store.data.name(for: entry.subject)) {
                                Button("Без уважительной причины") { quickAbsence(lesson, entry: entry, excused: false) }
                                Button("По уважительной причине") { quickAbsence(lesson, entry: entry, excused: true) }
                            }
                        }
                    }
                } label: { Image(systemName: absence == nil ? "person.crop.circle.badge.minus" : "checkmark.circle.fill").font(.title3).foregroundStyle(absence == nil ? Color.secondary : .orange).frame(width: 44, height: 44) }
                    .accessibilityLabel(absence == nil ? "Отметить пропуск \(lesson.number)-й пары" : "Изменить или снять пропуск \(lesson.number)-й пары")
            }
        }
    }
    @ViewBuilder private func breakLabel(after lesson: Lesson, next: Lesson) -> some View {
        let profile = store.data.profile(day)
        if let a = profile.bell(lesson.number), let b = profile.bell(next.number), b.start > a.end {
            Label("\(next.number - lesson.number > 1 ? "Окно" : profile.lunchAfter == lesson.number ? "Обед" : "Перерыв") · \(durationText(b.start - a.end))", systemImage: next.number - lesson.number > 1 ? "clock" : "cup.and.saucer")
                .font(.caption).foregroundStyle(.secondary).padding(.leading, 72)
        }
    }
    private func noteCard(_ note: DayNote) -> some View {
        Button { editor = .note(note) } label: {
            HStack { Label(note.title, systemImage: note.kind == .shortened ? "clock.badge.checkmark" : "note.text").font(.subheadline.weight(.semibold)); Spacer(); Image(systemName: "chevron.right").font(.caption) }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
        }.foregroundStyle(.primary)
    }
    private var nextSaved: Schedule? { store.data.schedules.filter { $0.group == store.data.settings.group && $0.day > day && $0.day <= day.adding(7) && !$0.lessons.isEmpty }.sorted { $0.day < $1.day }.first }
    private var weeklySummary: some View {
        let lessons = store.data.schedules.filter { $0.group == store.data.settings.group && $0.day >= day.adding(-6) && $0.day <= day }.reduce(0) { $0 + $1.lessons.count }
        let hours = store.data.absences.filter { $0.day >= day.adding(-6) && $0.day <= day }.reduce(0) { $0 + $1.hours }
        return Surface { VStack(alignment: .leading, spacing: 8) { Text("Неделя позади").font(.headline); Text("\(lessons) \(plural(lessons, "пара", "пары", "пар")) в сохранённом расписании · \(hours == 0 ? "без пропусков" : "пропущено \(hours) ч")").foregroundStyle(.secondary) } }
    }
    private func quickAbsence(_ lesson: Lesson, entry: LessonEntry, excused: Bool) { _ = store.save(Absence(day: day, lesson: lesson.number, subject: entry.subject, hours: store.data.settings.absenceHours, excused: excused)) }
    private func requestWholeDay(_ schedule: Schedule, excused: Bool) {
        if store.data.absences.contains(where: { $0.day == day && $0.lesson > 0 }) {
            wholeDayReason = excused; wholeDayConfirmation = true
        } else { markWholeDay(schedule, excused: excused) }
    }
    private func markWholeDay(_ schedule: Schedule, excused: Bool) {
        _ = store.change("Пропуски дня сохранены") { data in
            for lesson in schedule.lessons {
                data.save(Absence(day: day, lesson: lesson.number, subject: lesson.entries.count == 1 ? lesson.entries[0].subject : "", hours: data.settings.absenceHours, excused: excused))
            }
        }
    }
}

struct NowCard: View {
    @Environment(JournalStore.self) private var store
    let phase: DayPhase
    let schedule: Schedule
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Label(phase.title, systemImage: phase.isFinished ? "checkmark.circle" : "clock").font(.subheadline.weight(.semibold)); Spacer() }
            if phase.isFinished { Text("Хорошего отдыха.").font(.title3.weight(.semibold)) }
            else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(durationText(phase.minutes)).font(.largeTitle.weight(.bold).monospacedDigit())
                    Text("осталось").font(.subheadline)
                }
                if let number = phase.lesson, let entry = schedule.lessons.first(where: { $0.number == number })?.entries.first {
                    Text(store.data.name(for: entry.subject)).font(.headline).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !phase.isFinished { Text(phase.detail).font(.subheadline) }
            if !phase.isFinished { ProgressView(value: phase.progress).tint(.primary).accessibilityLabel("Прогресс текущего периода") }
        }
        .foregroundStyle(Color(uiColor: .label))
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay { RoundedRectangle(cornerRadius: 28).fill(LinearGradient(colors: [.orange.opacity(0.34), .yellow.opacity(0.15), .orange.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)) }
        }
        .accessibilityElement(children: .combine)
    }
}
