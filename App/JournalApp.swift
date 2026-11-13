import SwiftUI
import JournalCore

@main @MainActor
struct JournalApp: App {
    @State private var store = JournalStore()
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .environment(\.calendar, Day.calendar)
                .environment(\.timeZone, Day.calendar.timeZone)
                .tint(.orange)
        }
    }
}

struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var settings = false
    var body: some View {
        @Bindable var store = store
        Group {
            if !store.data.settings.onboarded || !validGroup(store.data.settings.group) {
                OnboardingView()
            } else {
                TabView(selection: $tab) {
                    Tab("Расписание", systemImage: "calendar", value: 0) {
                        NavigationStack { ScheduleView().toolbar { settingsButton } }
                    }
                    Tab("Оценки", systemImage: "chart.bar.xaxis", value: 1) {
                        NavigationStack { GradesView().toolbar { settingsButton } }
                    }
                    Tab("Пропуски", systemImage: "person.crop.circle.badge.clock", value: 2) {
                        NavigationStack { AbsencesView().toolbar { settingsButton } }
                    }
                }
                .accessibilityIdentifier("main-tabs")
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let title = store.undoTitle {
                        HStack(spacing: 16) {
                            Text(title).font(.subheadline).lineLimit(2)
                            Spacer(minLength: 0)
                            Button("Отменить") { store.undo() }.font(.subheadline.weight(.semibold)).frame(minHeight: 44)
                            Button { store.undoTitleDismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                                .accessibilityLabel("Скрыть уведомление")
                        }
                        .padding(.horizontal, 16).background(.regularMaterial)
                    }
                }
            }
        }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Понятно") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .alert("Восстановление данных", isPresented: Binding(get: { store.recoveryMessage != nil }, set: { if !$0 { store.recoveryMessage = nil } })) {
            Button("Понятно") { store.recoveryMessage = nil }
        } message: { Text(store.recoveryMessage ?? "") }
        .task { await store.prefetch() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.prefetch() } } }
        .sensoryFeedback(.success, trigger: store.undoTitle) { _, _ in store.data.settings.haptics }
    }
    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Настройки", systemImage: "gearshape") { settings = true }
                .accessibilityIdentifier("settings-button")
        }
    }
}
