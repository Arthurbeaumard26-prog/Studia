import Foundation
import WebKit

/// Session HTTP partagée : les cookies issus de la webview de connexion
/// (ÉduConnect → Pronote) sont copiés vers URLSession pour la récupération.
final class PronoteSession: NSObject {
    static let schoolBase = "https://0170010u.index-education.net/pronote/"
    static let mobileURL = URL(string: schoolBase + "mobile.html")!

    static let shared = PronoteSession()

    let cookieStorage = HTTPCookieStorage.shared
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = cookieStorage
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 25
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let s = URLSession(configuration: config)
        return s
    }()

    /// Copie tous les cookies de la webview vers URLSession.
    func adoptCookies(from store: WKHTTPCookieStore) async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            store.getAllCookies { continuation.resume(returning: $0) }
        }
        for c in cookies {
            cookieStorage.setCookie(c)
        }
    }

    var hasPronoteCookies: Bool {
        guard let cookies = cookieStorage.cookies(for: URL(string: PronoteSession.schoolBase)!) else { return false }
        return !cookies.isEmpty
    }

    func fetchHTML(_ url: URL, attempts: Int = 3) async throws -> (html: String, finalURL: URL) {
        var lastError: Error = AppError.network("erreur inconnue")
        for attempt in 0..<attempts {
            do {
                var request = URLRequest(url: url)
                request.setValue(
                    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
                    forHTTPHeaderField: "User-Agent")
                request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
                request.setValue("fr-FR,fr;q=0.9", forHTTPHeaderField: "Accept-Language")
                let (data, response) = try await urlSession.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw AppError.network("réponse invalide")
                }
                if (400...499).contains(http.statusCode) {
                    throw AppError.sessionExpired
                }
                if http.statusCode >= 500 {
                    throw AppError.network("serveur Pronote indisponible (\(http.statusCode))")
                }
                let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
                    ?? ""
                if html.isEmpty { throw AppError.network("page vide") }
                return (html, response.url ?? url)
            } catch {
                lastError = error
                if case AppError.sessionExpired = error { throw error }
                if attempt < attempts - 1 {
                    try await Task.sleep(nanoseconds: UInt64(800_000_000 * (attempt + 1)))
                }
            }
        }
        throw lastError
    }
}
