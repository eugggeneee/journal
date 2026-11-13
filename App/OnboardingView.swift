import SwiftUI
import JournalCore

struct OnboardingView: View {
    @Environment(JournalStore.self) private var store
    @State private var groupPicker = false
    @State private var bells = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image("AppArtwork").resizable().scaledToFit().frame(width: 112, height: 112)
                        .clipShape(RoundedRectangle(cornerRadius: 26)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Учёба.\nВ своём ритме.").font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
                        Text("Journal объединяет расписание, оценки и пропуски. Всё нужное — под рукой.")
                            .font(.title3).foregroundStyle(.secondary)
                    }
                    Surface {
                        VStack(alignment: .leading, spacing: 22) {
                            feature("calendar", "План на день", "Пары, кабинеты и время до следующего занятия.")
                            feature("chart.bar.xaxis", "Видимый прогресс", "Оценки и средний балл по каждому предмету.")
                            feature("checkmark.shield", "Спокойствие за данные", "Без аккаунтов и рекламы. Данные на вашем iPhone.")
                        }
                    }
                    VStack(spacing: 12) {
                        Button { groupPicker = true } label: {
                            HStack { Label(store.data.settings.group.isEmpty ? "Выбрать группу" : "Группа \(store.data.settings.group)", systemImage: "person.2"); Spacer(); Image(systemName: "chevron.right") }
                                .padding(18).frame(maxWidth: .infinity).background(JournalStyle.surface, in: RoundedRectangle(cornerRadius: 20))
                        }.foregroundStyle(.primary).accessibilityIdentifier("onboarding-group")
                        Button("Настроить время пар", systemImage: "clock") { bells = true }.frame(minHeight: 44)
                    }
                    Text("Неофициальное приложение МГТЭК. Расписание загружается с bseumtc.by и может отличаться от актуального. Уже загруженные дни доступны без интернета.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(JournalStyle.page)
            .navigationTitle("Journal").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    if store.change("Начальная настройка завершена", undoable: false, { $0.settings.onboarded = true }) {
                        Task { await store.prefetch(force: true) }
                    }
                } label: { Text("Начать").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10) }
                    .buttonStyle(.borderedProminent).controlSize(.large).disabled(!validGroup(store.data.settings.group))
                    .padding(.horizontal, 24).padding(.vertical, 12).background(.regularMaterial)
            }
            .sheet(isPresented: $groupPicker) { GroupPicker() }
            .sheet(isPresented: $bells) { NavigationStack { BellsView() } }
        }
    }
    private func feature(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.orange).frame(width: 32).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary) }
        }
    }
}
