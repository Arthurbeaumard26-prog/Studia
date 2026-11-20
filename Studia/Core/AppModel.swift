import SwiftUI
import WebKit

@MainActor
final class AppModel: ObservableObject {
    enum Stage {
        case idle
        case login
        case syncing
        case ready
        case failed(String)
    }

    @Published var stage: Stage = .idle
    @Published var snapshot = Snapshot()
    @Published var syncLabel = "Préparation…"
    @Published var syncProgress: Double = 0
    @Published var sessionExpired = false
    @Published var backgroundRefreshing = false

    private let store = LocalStore.shared

    init() {
        if let saved = store.load(), saved.isLoggedIn {
            snapshot = saved
            stage = .ready
        } else {
            stage = .login
        }
    }

    // MARK: - Connexion

    func completeLogin(cookieStore: WKHTTPCookieStore) async {
        stage = .syncing
        syncProgress = 0
        syncLabel = "Vérification de la session…"
        await PronoteSession.shared.adoptCookies(from: cookieStore)
        await runSync(silent: false)
    }

    /// Rafraîchit tout, en arrière-plan et sans déranger si tout va bien.
    func refreshAll(silent: Bool) async {
        if silent {
            backgroundRefreshing = true
        }
        await runSync(silent: silent)
        backgroundRefreshing = false
    }

    private func runSync(silent: Bool) async {
        let scraper = MobileScraper()
        scraper.onProgress = { [weak self] label, progress in
            guard let self else { return }
            Task { @MainActor in
                if !silent || self.snapshot.lastSync == nil {
                    self.syncLabel = label
                    self.syncProgress = progress
                }
            }
        }
        do {
            let fresh = try await scraper.fetchSnapshot()
            merge(fresh)
            sessionExpired = false
            store.save(snapshot)
            store.rememberSession(true)
            stage = .ready
        } catch {
            handle(error, silent: silent)
        }
    }

    private func handle(_ error: Error, silent: Bool) {
        if case AppError.sessionExpired = error {
            sessionExpired = true
            stage = snapshot.isLoggedIn ? .ready : .login
            return
        }
        if snapshot.isLoggedIn {
            stage = .ready
        } else if case .syncing = stage {
            var message = error.localizedDescription
            if let appError = error as? AppError {
                message = appError.errorDescription ?? message
            }
            stage = .failed(message)
        }
    }

    /// Fusionne le nouvel instantané : les devoirs cochés localement restent cochés.
    private func merge(_ fresh: Snapshot) {
        let doneKeys = Set(snapshot.homework.filter(\.done).map(\.stableKey))
        snapshot = fresh
        for i in snapshot.homework.indices where doneKeys.contains(snapshot.homework[i].stableKey) {
            snapshot.homework[i].done = true
        }
    }

    // MARK: - Devoirs : état fait / non fait

    func toggleDone(_ homework: Homework) {
        guard let index = snapshot.homework.firstIndex(where: { $0.stableKey == homework.stableKey }) else { return }
        snapshot.homework[index].done.toggle()
        store.save(snapshot)
    }

    // MARK: - Déconnexion / session

    func logout() {
        store.clear()
        store.rememberSession(false)
        sessionExpired = false
        snapshot = Snapshot()
        PronoteSession.shared.cookieStorage.removeCookies(since: Date.distantPast)
        stage = .login
    }

    func startOver() {
        stage = .login
        sessionExpired = false
    }
}
