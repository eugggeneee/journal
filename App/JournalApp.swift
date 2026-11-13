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
                .dynamicTypeSize(.large)
                .tint(JournalStyle.accent)
                .preferredColorScheme(previewScheme)
        }
    }
    private var previewScheme: ColorScheme? {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--dark") ? .dark : nil
        #else
        nil
        #endif
    }
}

struct RootView: View {
    @Environment(JournalStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var settings = false
    @State private var welcome = false
    @AppStorage("lastWelcomeBuild") private var lastWelcomeBuild = 0
    private var currentBuild: Int { Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2") ?? 2 }
    private var needsWelcome: Bool {
        #if DEBUG
        if store.demo { return ProcessInfo.processInfo.arguments.contains("--welcome") }
        #endif
        return !store.data.settings.onboarded || lastWelcomeBuild < currentBuild
    }
    var body: some View {
                TabView(selection: $tab) {
                    Tab("Расписание", systemImage: "calendar", value: 0) {
                        NavigationStack { ScheduleView().modifier(UndoBanner()).toolbar { settingsButton } }
                    }
                    Tab("Оценки", systemImage: "chart.bar.xaxis", value: 1) {
                        NavigationStack { GradesView().modifier(UndoBanner()).toolbar { settingsButton } }
                    }
                    Tab("Пропуски", systemImage: "person.crop.circle.badge.clock", value: 2) {
                        NavigationStack { AbsencesView().modifier(UndoBanner()).toolbar { settingsButton } }
                    }
                }
                .accessibilityIdentifier("main-tabs")
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
        .sheet(isPresented: $welcome) {
            OnboardingView(firstRun: !store.data.settings.onboarded) {
                lastWelcomeBuild = currentBuild
                welcome = false
            }.presentationDetents([.large]).presentationDragIndicator(.visible).interactiveDismissDisabled()
        }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("Понятно") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .alert("Восстановление данных", isPresented: Binding(get: { store.recoveryMessage != nil }, set: { if !$0 { store.recoveryMessage = nil } })) {
            Button("Понятно") { store.recoveryMessage = nil }
        } message: { Text(store.recoveryMessage ?? "") }
        .task {
            welcome = needsWelcome
            await store.prefetch()
        }
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

/// Insets belong to each tab's content, so UIKit's tab bar keeps a stable frame on iOS 18.
struct UndoBanner: ViewModifier {
    @Environment(JournalStore.self) private var store
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if let title = store.undoTitle {
                HStack(spacing: 12) {
                    Text(title).font(.subheadline).lineLimit(2)
                    Spacer(minLength: 0)
                    Button("Отменить") { store.undo() }.font(.subheadline.weight(.bold)).frame(minHeight: 44)
                    Button { store.undoTitleDismiss() } label: { Image(systemName: "xmark").frame(width: 44, height: 44) }
                        .accessibilityLabel("Скрыть уведомление")
                }
                .padding(.horizontal, 16).background(.regularMaterial)
            }
        }
    }
}
