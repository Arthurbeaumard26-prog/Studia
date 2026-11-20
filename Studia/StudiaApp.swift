import SwiftUI

@main
struct StudiaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        switch model.stage {
        case .idle:
            Color(Theme.background).ignoresSafeArea()
        case .login:
            LoginView()
        case .syncing:
            SyncOverlay()
        case .ready:
            MainTabs()
        case .failed(let message):
            failedView(message)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color(Theme.accent))
            Text("Impossible de récupérer tes données")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(Theme.text))
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color(Theme.textSecondary))
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button {
                    model.stage = .syncing
                    Task { await model.refreshAll(silent: false) }
                } label: {
                    Text("Réessayer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button("Se reconnecter") {
                    model.startOver()
                }
                .buttonStyle(.bordered)
                .tint(Color(Theme.accent))
            }
            .padding(.horizontal, 8)
        }
        .padding(32)
        .background(Color(Theme.background).ignoresSafeArea())
    }
}

struct MainTabs: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Accueil", systemImage: "house") }
            ScheduleView()
                .tabItem { Label("Cours", systemImage: "calendar") }
            HomeworkTabView()
                .tabItem { Label("Devoirs", systemImage: "book.closed") }
            GradesView()
                .tabItem { Label("Notes", systemImage: "chart.line.uptrend.xyaxis") }
            SchoolLifeView()
                .tabItem { Label("Vie scolaire", systemImage: "person.2") }
        }
        .task {
            await model.refreshAll(silent: true)
        }
    }
}
