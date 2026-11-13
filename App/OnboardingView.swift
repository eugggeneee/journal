import SwiftUI
import JournalCore

/// System sheet with the familiar welcome / What's New structure.
struct OnboardingView: View {
    @Environment(JournalStore.self) private var store
    let firstRun: Bool
    var completed: () -> Void
    @State private var groupPicker = false
    @State private var bells = false
    @State private var setup = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 16) {
                        Image("AppArtwork").resizable().frame(width: 76, height: 76)
                            .clipShape(RoundedRectangle(cornerRadius: 17)).accessibilityHidden(true)
                        Text(firstRun ? "Добро пожаловать\nв Journal" : "Новое в Journal")
                            .font(.largeTitle.bold()).multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(firstRun ? "Ваше расписание, оценки и пропуски — в одном месте." : "Больше ясности. Меньше лишнего.")
                            .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.top, 16)
                    VStack(alignment: .leading, spacing: 24) {
                        feature("calendar", "Расписание под рукой", firstRun ? "Выберите группу. Пары, кабинеты и преподаватели появятся автоматически." : "Исправлена загрузка групп и занятий со страниц колледжа.")
                        feature("chart.bar.fill", "Всё по порядку", "Плотное расписание, понятные показатели и привычные элементы iOS.")
                        feature("externaldrive.fill", "Ваши записи с вами", "Оценки и пропуски хранятся на iPhone. Полную копию можно сохранить в «Файлы».")
                    }
                    Text("Неофициальное приложение МГТЭК. Источник расписания — сайт колледжа. Личные записи остаются на вашем устройстве.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 28).padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button { if firstRun || !validGroup(store.data.settings.group) { setup = true } else { finish() } } label: {
                        Text("Продолжить").font(.body.bold()).frame(maxWidth: .infinity).frame(minHeight: 44)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("welcome-continue")
                    if firstRun {
                        Button("Настроить позже") { finish() }.frame(minHeight: 44)
                            .accessibilityIdentifier("welcome-later")
                    }
                }.padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 12)
                    .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemBackground))
            .navigationDestination(isPresented: $setup) { setupView }
        }
    }
    private var setupView: some View {
        Form {
            Section {
                Button { groupPicker = true } label: {
                    HStack {
                        Label("Группа", systemImage: "person.2.fill")
                        Spacer()
                        Text(validGroup(store.data.settings.group) ? store.data.settings.group : "Выбрать").foregroundStyle(.secondary)
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }.frame(minHeight: 44)
                }.accessibilityIdentifier("onboarding-group")
            } header: { Text("Ваше расписание") } footer: {
                Text("Выберите группу из списка колледжа или введите её номер. Личные оценки и пропуски сохранятся при смене группы.")
            }
            Section {
                Button { bells = true } label: {
                    HStack { Label("Звонки", systemImage: "clock.fill"); Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary) }.frame(minHeight: 44)
                }
            } footer: { Text("Проверьте выбранное время занятий. Звонки можно изменить в настройках в любой момент.") }
        }
        .navigationTitle("Настройка Journal").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Позже") { finish() } } }
        .safeAreaInset(edge: .bottom) {
            Button { finish() } label: { Text("Начать").font(.body.bold()).frame(maxWidth: .infinity).frame(minHeight: 44) }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!validGroup(store.data.settings.group)).accessibilityIdentifier("setup-start")
                .padding(24).background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationDestination(isPresented: $groupPicker) { GroupPicker(embedded: true) }
        .navigationDestination(isPresented: $bells) { BellsView() }
    }
    private func finish() {
        if store.change("Начальная настройка завершена", undoable: false, { $0.settings.onboarded = true }) {
            completed()
            Task { await store.prefetch(force: true) }
        }
    }
    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title.bold()).foregroundStyle(JournalStyle.accent).frame(width: 36).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.bold())
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
