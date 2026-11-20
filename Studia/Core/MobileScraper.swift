import Foundation

/// Récupération automatique de toutes les rubriques Pronote mobile.
final class MobileScraper {
    private let session: PronoteSession

    /// Appelé à chaque étape : (libellé, progression 0…1).
    var onProgress: ((String, Double) -> Void)?

    init(session: PronoteSession = .shared) {
        self.session = session
    }

    // MARK: - Découverte des rubriques

    static func discoverRubrics(in doc: HTMLNode, pageURL: URL) -> [String: URL] {
        var found: [String: URL] = [:]
        let definitions: [(String, [String])] = [
            ("schedule", ["emploi du temps"]),
            ("homework", ["devoir", "travail a faire", "travail à faire"]),
            ("grades", ["notes", "bulletin", "resultats", "résultats"]),
            ("life", ["vie scolaire"]),
            ("notebook", ["cahier de textes", "cahier de texte", "temps d'enseignement"]),
            ("news", ["information", "actualite", "actualité", "annonce"]),
            ("competencies", ["competence", "compétence", "evaluation", "linguistique", "socle"]),
            ("resources", ["document", "ressource", "fichiers"]),
            ("agenda", ["agenda", "calendrier", "evenement"]),
            ("messaging", ["messagerie", "courrier", "message"]),
            ("profile", ["profil", "mon compte", "mon profil"]),
        ]

        for (key, keywords) in definitions {
            var bestScore = 0
            var bestURL: URL?
            for link in doc.links() {
                let text = link.text.lowercased()
                let hrefFolded = link.href.lowercased()
                for kw in keywords {
                    var score = 0
                    if text.contains(kw) {
                        score = kw.count + 10
                    } else if hrefFolded.contains(kw.lowercased()) {
                        score = kw.count
                    }
                    if score > bestScore {
                        if key == "profile" && !link.href.contains("mobile.html") {
                            continue
                        }
                        guard let url = URL(string: link.href, relativeTo: pageURL)?.absoluteURL else { continue }
                        bestScore = score
                        bestURL = url
                    }
                }
            }
            if bestScore > 0, let url = bestURL {
                found[key] = url
            }
        }
        return found
    }

    // MARK: - Session

    static let sessionMarkers = ["mot de passe", "identifiant", "educonnect", "connexion", "authentification", "choisis ton profil", "choisissez"]
    static let loggedMarkers = ["déconnexion", "deconnexion", "mes devoirs", "emploi du temps", "mon profil", "vie scolaire"]

    static func looksLoggedOut(_ html: String) -> Bool {
        let folded = Subjects.fold(html)
        let hasLoginUI = sessionMarkers.contains { folded.contains($0) }
        let hasLoggedUI = loggedMarkers.contains { folded.contains($0) }
        return hasLoginUI && !hasLoggedUI
    }

    // MARK: - Récupération complète

    func fetchSnapshot() async throws -> Snapshot {
        var snapshot = Snapshot()

        onProgress?("Vérification de la session…", 0.02)
        let (homeHTML, homeURL) = try await session.fetchHTML(PronoteSession.mobileURL)
        if Self.looksLoggedOut(homeHTML) {
            throw AppError.sessionExpired
        }
        let homeDoc = HTMLParser.parse(homeHTML)
        let rubrics = Self.discoverRubrics(in: homeDoc, pageURL: homeURL)
        snapshot.profile = ProfileParser.parse(homeDoc, baseURL: homeURL)
        if snapshot.profile.fullName.isEmpty {
            snapshot.profile.fullName = firstCapture(pattern: "(?i)bonjour\\s+([A-Za-zÀ-ÿ' -]{3,60})", in: homeHTML) ?? ""
        }
        if snapshot.profile.className.isEmpty {
            snapshot.profile.className = firstCapture(pattern: "(?i)\\b(6[eè]|5[eè]|4[eè]|3[eè]){1}\\s*[0-9]{1,2}", in: homeHTML) ?? ""
        }

        let plan: [(String, String, URL?)] = [
            ("Récupération de l'emploi du temps…", "schedule", rubrics["schedule"]),
            ("Récupération des devoirs…", "homework", rubrics["homework"]),
            ("Récupération des notes…", "grades", rubrics["grades"]),
            ("Récupération de la vie scolaire…", "life", rubrics["life"]),
            ("Récupération du cahier de textes…", "notebook", rubrics["notebook"]),
            ("Récupération des informations…", "news", rubrics["news"]),
            ("Récupération des compétences…", "competencies", rubrics["competencies"]),
            ("Récupération des documents…", "resources", rubrics["resources"]),
            ("Récupération de l'agenda…", "agenda", rubrics["agenda"]),
            ("Récupération de la messagerie…", "messaging", rubrics["messaging"]),
        ]

        let total = Double(plan.count) + 1.0
        for (index, item) in plan.enumerated() {
            onProgress?(item.0, Double(index + 1) / total)
            do {
                guard let url = item.2 else {
                    snapshot.rubricErrors[item.1] = "Rubrique introuvable sur la version mobile de ton Pronote."
                    continue
                }
                let (html, finalURL) = try await session.fetchHTML(url)
                if Self.looksLoggedOut(html) {
                    throw AppError.sessionExpired
                }
                let doc = HTMLParser.parse(html)
                let ref = Date()
                switch item.1 {
                case "schedule": snapshot.courses = ScheduleParser.parse(doc, reference: ref)
                case "homework": snapshot.homework = HomeworkParser.parse(doc, baseURL: finalURL, reference: ref)
                case "grades": snapshot.periods = GradesParser.parse(doc, reference: ref)
                case "life": snapshot.life = LifeParser.parse(doc, reference: ref)
                case "notebook": snapshot.lessons = LessonParser.parse(doc, baseURL: finalURL, reference: ref)
                case "news": snapshot.news = NewsParser.parse(doc, baseURL: finalURL, reference: ref)
                case "competencies": snapshot.competencies = CompetencyParser.parse(doc)
                case "resources": snapshot.resources = DocumentParser.parse(doc, baseURL: finalURL)
                case "agenda": snapshot.agenda = AgendaParser.parse(doc, reference: ref)
                case "messaging": snapshot.messages = MessageParser.parse(doc, reference: ref)
                default: break
                }
            } catch {
                if case AppError.sessionExpired = error { throw error }
                if let appError = error as? AppError {
                    snapshot.rubricErrors[item.1] = appError.errorDescription ?? "Échec de la récupération."
                } else {
                    snapshot.rubricErrors[item.1] = error.localizedDescription
                }
            }
        }

        onProgress?("Mise en ordre…", 0.99)
        snapshot.lastSync = Date()
        onProgress?("Terminé", 1.0)
        return snapshot
    }
}
