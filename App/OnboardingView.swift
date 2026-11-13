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
            NativeWelcome(firstRun: firstRun) {
                if firstRun || !validGroup(store.data.settings.group) { setup = true }
                else { finish() }
            }
            .toolbar(.hidden, for: .navigationBar)
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
        .toolbar(.visible, for: .navigationBar)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Позже") { finish() } } }
        .safeAreaInset(edge: .bottom) {
            Button { finish() } label: { Text("Начать").font(.body.bold()).frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).controlSize(.large).buttonBorderShape(.capsule)
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
}
