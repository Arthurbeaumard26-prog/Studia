import Foundation

enum AppError: LocalizedError {
    case sessionExpired
    case notLoggedIn
    case network(String)

    var errorDescription: String? {
        switch self {
        case .sessionExpired: return "Ta session a expiré. Reconnecte-toi pour actualiser tes données."
        case .notLoggedIn: return "Connecte-toi à Pronote pour récupérer tes données."
        case .network(let m): return "Connexion impossible (\(m)). Nouvelle tentative en cours…"
        }
    }
}

/// Persiste l'instantané complet des données sur le disque (Application Support).
final class LocalStore {
    static let shared = LocalStore()
    private let fileURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Studia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("snapshot.json")
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Snapshot.self, from: data)
    }

    func save(_ snapshot: Snapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(snapshot) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    var hasSession: Bool {
        UserDefaults.standard.bool(forKey: "studia.hasSession")
    }

    func rememberSession(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "studia.hasSession")
    }
}
