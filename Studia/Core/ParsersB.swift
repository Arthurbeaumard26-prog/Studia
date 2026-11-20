import Foundation

// MARK: - Notes

enum GradesParser {
    static func parse(_ doc: HTMLNode, reference: Date) -> [Period] {
        var periods: [String] = []
        var seenPeriods = Set<String>()
        var currentPeriod = "Année en cours"
        ensure(&periods, &seenPeriods, currentPeriod)

        var gradesBySubject: [String: [Grade]] = [:]
        var averages: [String: (avg: String, classAvg: String, coef: String)] = [:]
        var appreciations: [Appreciation] = []
        var generalAverages: [String: (String, String)] = [:]

        var currentSubject: String?
        var currentDate: Date?

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 3, text.count <= 2000 else { continue }
            let folded = Subjects.fold(text)

            if let r = folded.range(of: "(\\d+)(?:e|er)?\\s*(tri|periode)", options: .regularExpression) {
                let head = String(text.prefix(40)).trimmingCharacters(in: .whitespaces)
                let label = folded.contains("tri") ? "Trimestre" : "Période"
                let number = quarterNumber(in: head)
                let name = number.map { "\(label) \($0)" } ?? head
                currentPeriod = name
                ensure(&periods, &seenPeriods, name)
                currentSubject = nil
                currentDate = nil
                _ = r
                continue
            }

            if folded.contains("moyenne") && folded.contains("generale") {
                let values = Patterns.decimals(in: text)
                if let first = values.first {
                    generalAverages[currentPeriod] = (fmt(first), values.count > 1 ? fmt(values[1]) : "")
                }
                continue
            }

            if Patterns.first(regex: Patterns.dateSlash, in: text) != nil ||
               Patterns.first(regex: Patterns.dateWords, in: text) != nil {
                if let d = (Patterns.first(regex: Patterns.dateSlash, in: text) ?? Patterns.first(regex: Patterns.dateWords, in: text))
                    .flatMap({ DateFR.parse($0, reference: reference) }) {
                    currentDate = d
                }
            }

            if let s = Subjects.canonical(in: text) ?? currentSubject {
                currentSubject = s
                let isAppreciation = folded.contains("appreciation") ||
                    (text.count > 90 && Patterns.decimals(in: text).isEmpty && text.count <= 400)
                if isAppreciation {
                    appreciations.append(Appreciation(subject: s, author: author(in: text), text: text))
                    continue
                }
            }

            guard let s = Subjects.canonical(in: text) ?? currentSubject else { continue }

            if let regex = Patterns.singleScore {
                let gs = Patterns.groups(regex, text)
                if gs.count >= 2 {
                    let decimals = Patterns.decimals(in: text)
                    let grade = Grade(
                        stableKey: DateFR.dayKey(currentDate ?? reference) + "|" + s + "|" + text.normalizedKey,
                        date: currentDate,
                        subject: s,
                        valueText: gs[0],
                        outOfText: gs[1],
                        coefficient: firstCapture(pattern: "(?i)coef(?:ficient)?\\s*[:.]?\\s*(\\d+(?:[.,]\\d+)?)", in: text) ?? "",
                        average: folded.contains("moyenne") && decimals.count >= 3 ? fmt(decimals[decimals.count - 1]) : "",
                        title: "",
                        comment: commentText(text))
                    gradesBySubject[s, default: []].append(grade)
                    continue
                }
            }

            let values = Patterns.decimals(in: text)
            if values.count >= 2 {
                if averages[s] == nil {
                    averages[s] = (fmt(values[0]), fmt(values[1]),
                                   firstCapture(pattern: "(?i)coef(?:ficient)?\\s*[:.]?\\s*(\\d+(?:[.,]\\d+)?)", in: text) ?? "")
                }
            }
        }

        var orderedPeriods = periods
        if orderedPeriods.isEmpty, !gradesBySubject.isEmpty || !averages.isEmpty {
            orderedPeriods = ["Notes récupérées"]
        }

        var result: [Period] = []
        for p in orderedPeriods {
            var subjects: [SubjectSummary] = []
            let allSubjects = Set(gradesBySubject.keys).union(Set(averages.keys)).sorted()
            for s in allSubjects {
                let grades = gradesBySubject[s] ?? []
                let avg = averages[s]
                if grades.isEmpty && avg == nil { continue }
                subjects.append(SubjectSummary(
                    subject: s,
                    average: avg?.avg ?? "",
                    classAverage: avg?.classAvg ?? "",
                    coefficient: avg?.coef ?? "",
                    grades: grades))
            }
            guard !subjects.isEmpty || generalAverages[p] != nil else { continue }
            result.append(Period(
                name: p,
                generalAverage: generalAverages[p]?.0 ?? "",
                classGeneralAverage: generalAverages[p]?.1 ?? "",
                subjects: subjects,
                appreciations: appreciations.filter { $0.subject != "" }))
        }
        return result
    }

    static func quarterNumber(in text: String) -> Int? {
        let folded = Subjects.fold(text)
        if let m = firstCapture(pattern: "(\\d+)", in: folded) { return Int(m) }
        return nil
    }

    private static func ensure(_ periods: inout [String], _ seen: inout Set<String>, _ name: String) {
        if !seen.contains(name) {
            seen.insert(name)
            periods.append(name)
        }
    }

    private static func fmt(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
    }

    private static func commentText(_ text: String) -> String {
        let words = text.components(separatedBy: " ")
        let long = words.filter { $0.count > 25 }
        return long.joined(separator: " ")
    }

    private static func author(in text: String) -> String {
        for word in text.components(separatedBy: " ") where word.count > 3 && word.uppercased() == word {
            if word.range(of: "^[A-ZÀ-Ÿ]{3,}", options: .regularExpression) != nil { return word }
        }
        return ""
    }
}

// MARK: - Vie scolaire

enum LifeParser {
    static func parse(_ doc: HTMLNode, reference: Date) -> [SchoolLifeEntry] {
        var out: [SchoolLifeEntry] = []
        var seen = Set<String>()

        let kindKeywords: [(LifeKind, [String])] = [
            (.absence, ["absence"]),
            (.retard, ["retard"]),
            (.punition, ["punition"]),
            (.sanction, ["sanction"]),
            (.observation, ["observation", "remarque"]),
            (.carnet, ["mot dans le cahier", "cahier de correspondance", "mot du directeur", "mot de la direction"]),
            (.dispensation, ["dispense"]),
        ]

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 6, text.count <= 800 else { continue }
            let folded = Subjects.fold(text)

            var kind: LifeKind?
            for (k, words) in kindKeywords where words.contains(where: { folded.contains($0) }) {
                kind = k
                break
            }
            guard let k = kind else { continue }

            let dateText = Patterns.first(regex: Patterns.dateSlash, in: text) ??
                Patterns.first(regex: Patterns.dateWords, in: text)
            let date = dateText.flatMap { DateFR.parse($0, reference: reference) }

            var duration = ""
            if let m = firstCapture(pattern: "(?i)(\\d+\\s*(?:h|heures?|j|jours?|demi-journ[eé]e|minutes?))", in: text) {
                duration = m
            }
            var reason = text
            reason = reason.replacingOccurrences(of: k.label, with: "", options: [.caseInsensitive, .diacriticInsensitive])
                .trimmingCharacters(in: CharacterSet(charactersIn: " :;.–-"))
            let key = fingerprint(k, date, reason)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(SchoolLifeEntry(stableKey: key, kind: k, start: date, end: nil, reason: reason, duration: duration))
        }
        return out.sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }
    }
}

// MARK: - Cahier de textes

enum LessonParser {
    static func parse(_ doc: HTMLNode, baseURL: URL, reference: Date) -> [LessonEntry] {
        var out: [LessonEntry] = []
        var seen = Set<String>()
        var currentDate: Date?
        var currentSubject: String?

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 6 else { continue }

            let dateWords = Patterns.first(regex: Patterns.dateWords, in: text)
            let dateSlash = Patterns.first(regex: Patterns.dateSlash, in: text)
            if let m = dateWords ?? dateSlash, text.count <= 60, Subjects.canonical(in: text) == nil {
                if let d = DateFR.parse(m, reference: reference) {
                    currentDate = d
                    continue
                }
            }

            guard let subject = Subjects.canonical(in: text) ?? currentSubject, text.count >= 10 else { continue }
            currentSubject = subject

            let folded = Subjects.fold(text)
            var content = text
            var toDo = ""
            if let range = folded.range(of: "a faire") {
                let off = folded.distance(from: folded.startIndex, to: range.lowerBound)
                content = String(text.prefix(off)).trimmingCharacters(in: CharacterSet(charactersIn: " :;.-–"))
                toDo = String(text.dropFirst(folded.distance(from: folded.startIndex, to: range.upperBound)))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " :;.-–"))
            }

            let key = DateFR.dayKey(currentDate ?? reference) + "|" + subject + "|" + content.normalizedKey
            guard !seen.contains(key), content.count >= 8 else { continue }
            seen.insert(key)
            out.append(LessonEntry(stableKey: key,
                                   date: currentDate,
                                   subject: subject,
                                   content: content,
                                   toDo: toDo,
                                   attachments: DomWalk.attachments(in: block, baseURL: baseURL)))
        }
        return out
    }
}

// MARK: - Informations / actualités

enum NewsParser {
    static func parse(_ doc: HTMLNode, baseURL: URL, reference: Date) -> [NewsItem] {
        var out: [NewsItem] = []
        var seen = Set<String>()

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 15, text.count <= 4000 else { continue }
            let dateText = Patterns.first(regex: Patterns.dateSlash, in: text) ??
                Patterns.first(regex: Patterns.dateWords, in: text)
            guard dateText != nil || text.count >= 30 else { continue }
            let folded = Subjects.fold(text)
            if folded.contains("emploi du temps") && folded.contains("connexion") { continue }

            var body = text
            if let m = dateText {
                body = body.replacingOccurrences(of: m, with: " ").trimmingCharacters(in: .whitespaces)
            }
            guard body.count >= 8 else { continue }
            let title = String(body.prefix(90))
            let surveyLink = (folded.contains("sondage") || folded.contains("questionnaire") || folded.contains("formulaire"))
                ? block.anchors.compactMap { a -> URL? in
                    guard let h = a.href else { return nil }
                    return URL(string: h, relativeTo: baseURL)?.absoluteURL
                }.first
                : nil

            let key = title.normalizedKey + "|" + (dateText ?? "").normalizedKey
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(NewsItem(stableKey: key, title: title,
                                date: dateText.flatMap { DateFR.parse($0, reference: reference) },
                                body: body, author: "", surveyLink: surveyLink))
        }
        return out
    }
}

// MARK: - Compétences

enum CompetencyParser {
    static func parse(_ doc: HTMLNode) -> [CompetencyDomain] {
        var out: [CompetencyDomain] = []
        var currentSubject = ""
        let levelWords = ["acquis", "en cours d'acquisition", "non acquis", "avec aide",
                          "maîtrise insuffisante", "maîtrise fragile", "maîtrise satisfaisante", "très bonne maîtrise"]

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 5, text.count <= 400 else { continue }
            let folded = Subjects.fold(text)

            if let subject = Subjects.canonical(in: text) {
                if text.count < 45 {
                    currentSubject = subject
                    continue
                }
            }
            guard let level = levelWords.first(where: { folded.contains($0) }) else { continue }
            var name = text
            name = name.replacingOccurrences(of: level, with: "", options: [.caseInsensitive, .diacriticInsensitive])
            name = name.trimmingCharacters(in: CharacterSet(charactersIn: " :;.-–"))
            guard name.count >= 3 else { continue }
            let domain = CompetencyDomain(subject: currentSubject.isEmpty ? "Compétences" : currentSubject,
                                          level: level.capitalized,
                                          items: [CompetencyItem(name: name, level: level.capitalized)])
            if let idx = out.lastIndex(where: { $0.subject == domain.subject && $0.level == domain.level }) {
                var d = out[idx]
                d.items.append(contentsOf: domain.items)
                out[idx] = d
            } else {
                out.append(domain)
            }
        }
        return out
    }
}

// MARK: - Documents

enum DocumentParser {
    static func parse(_ doc: HTMLNode, baseURL: URL) -> [ResourceDoc] {
        var out: [ResourceDoc] = []
        var seen = Set<String>()
        for att in DomWalk.attachments(in: doc, baseURL: baseURL) {
            let key = att.url?.absoluteString ?? att.name
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(ResourceDoc(stableKey: key, name: att.name, subject: "", date: nil, url: att.url))
        }
        return out
    }
}

// MARK: - Agenda

enum AgendaParser {
    static func parse(_ doc: HTMLNode, reference: Date) -> [AgendaEvent] {
        var out: [AgendaEvent] = []
        var seen = Set<String>()
        let kinds = ["sortie", "contrôle", "devoir sur table", "échange", "voyage",
                     "réunion", "spectacle", "assemblée", "photo", "stage", "kermesse"]

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 8, text.count <= 800 else { continue }
            let folded = Subjects.fold(text)
            guard let kind = kinds.first(where: { folded.contains($0) }) else { continue }
            let dateText = Patterns.first(regex: Patterns.dateSlash, in: text) ??
                Patterns.first(regex: Patterns.dateWords, in: text)
            let key = fingerprintString(text)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(AgendaEvent(stableKey: key,
                                   date: dateText.flatMap { DateFR.parse($0, reference: reference) },
                                   title: String(text.prefix(120)),
                                   kind: kind.capitalized,
                                   details: text))
        }
        return out
    }
}

// MARK: - Messagerie

enum MessageParser {
    static func parse(_ doc: HTMLNode, reference: Date) -> [MailMessage] {
        var out: [MailMessage] = []
        var seen = Set<String>()

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 8, text.count <= 4000 else { continue }
            let folded = Subjects.fold(text)
            let looksLikeMessage = folded.range(of: "\\bde\\s+:", options: .regularExpression) != nil ||
                folded.contains("expediteur") || text.contains("@")
            guard looksLikeMessage else { continue }
            let sent = folded.contains("envoye") || folded.contains("envoyé")
            if folded.contains("salle") && folded.contains("emploi du temps") { continue }

            let dateText = Patterns.first(regex: Patterns.dateSlash, in: text) ??
                Patterns.first(regex: Patterns.dateWords, in: text)
            let author = (firstCapture(pattern: "(?i)(?:de|expediteur)\\s*[:.]?\\s*([^,;·\\n]{3,60})", in: text) ?? "")
                .trimmingCharacters(in: .whitespaces)
            let key = fingerprintString(text)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(MailMessage(stableKey: key, subject: String(text.prefix(80)), author: author,
                                   date: dateText.flatMap { DateFR.parse($0, reference: reference) },
                                   body: text, sent: sent))
        }
        return out
    }
}

// MARK: - Profil

enum ProfileParser {
    static func parse(_ doc: HTMLNode, baseURL: URL) -> StudentProfile {
        var p = StudentProfile(school: "Collège Françoise Dolto")
        for line in doc.visibleLines() {
            if p.className.isEmpty, let v = firstCapture(pattern: "(?i)classe\\s*[:.]\\s*(.{1,20})", in: line) {
                p.className = v.trimmingCharacters(in: .whitespaces)
            }
            if p.fullName.isEmpty,
               let v = firstCapture(pattern: "(?i)(?:bonjour|bienvenue|eleve)\\s*[:.]?\\s*([A-ZÀ-Ÿ][A-Za-zÀ-ÿ' -]{2,60})", in: line) {
                p.fullName = v.trimmingCharacters(in: CharacterSet(charactersIn: " .!"))
            }
            if p.school == "Collège Françoise Dolto",
               (line.contains("Collège") || line.contains("COLLEGE") || line.contains("Lycée")),
               line.count < 60 {
                p.school = line
            }
        }
        for img in doc.elements(named: "img") {
            guard let src = img.attr("src") else { continue }
            let s = src.lowercased()
            if s.contains("photo") || s.contains("avatar") || s.contains("identit") || s.contains("trombi") {
                p.avatarURL = URL(string: src, relativeTo: baseURL)?.absoluteString ?? src
                break
            }
        }
        if p.fullName.contains(" "), p.fullName.count <= 60 {
            let names = p.fullName.components(separatedBy: " ")
            p.firstName = names.first ?? ""
            p.lastName = names.dropFirst().joined(separator: " ")
        }
        return p
    }
}

// MARK: - Utilitaires

func fingerprint(_ kind: LifeKind, _ date: Date?, _ reason: String) -> String {
    kind.rawValue + "|" + (date.map(DateFR.dayKey) ?? "??") + "|" + reason.normalizedKey
}

func fingerprintString(_ s: String) -> String {
    String(s.normalizedKey.suffix(240))
}
