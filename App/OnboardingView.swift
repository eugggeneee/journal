import SwiftUI
import JournalCore

/// System sheet with the familiar welcome / What's New structure.
struct OnboardingView: View {
    @Environment(JournalStore.self) private var store
    let firstRun: Bool
    var completed: () -> Void
    @State private var groupPicker = false
    @State private var bells = false
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
                    if firstRun || !validGroup(store.data.settings.group) {
                        VStack(spacing: 0) {
                            Button { groupPicker = true } label: {
                                HStack {
                                    Label(validGroup(store.data.settings.group) ? "Группа выбрана" : "Выбрать группу", systemImage: "person.2.fill")
                                    Spacer()
                                    Image(systemName: validGroup(store.data.settings.group) ? "checkmark" : "chevron.right")
                                }.frame(minHeight: 50).contentShape(Rectangle())
                            }.accessibilityIdentifier("onboarding-group")
                            Divider()
                            Button { bells = true } label: {
                                HStack { Label("Настроить звонки", systemImage: "clock.fill"); Spacer(); Image(systemName: "chevron.right") }
                                    .frame(minHeight: 50).contentShape(Rectangle())
                            }
                        }.padding(.horizontal, 16)
                            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 12))
                    }
                    Text("Неофициальное приложение МГТЭК. Источник расписания — сайт колледжа. Личные записи остаются на вашем устройстве.")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding(.horizontal, 28).padding(.bottom, 20)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 4) {
                    Button { finish() } label: {
                        Text(firstRun ? "Начать" : "Продолжить").font(.body.bold()).frame(maxWidth: .infinity).frame(minHeight: 44)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(firstRun && !validGroup(store.data.settings.group))
                        .accessibilityIdentifier("welcome-continue")
                    if firstRun {
                        Button("Настроить позже") { finish() }.frame(minHeight: 44)
                            .accessibilityIdentifier("welcome-later")
                    }
                }.padding(.horizontal, 28).padding(.top, 12).padding(.bottom, 12)
                    .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemBackground))
            .sheet(isPresented: $groupPicker) { GroupPicker() }
            .sheet(isPresented: $bells) { NavigationStack { BellsView() } }
        }
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
