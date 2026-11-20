import Foundation

// MARK: - Vocabulaire des disciplines (collège)

enum Subjects {
    static let map: [(keywords: [String], name: String)] = [
        (["mathematiques", "mathematique", "maths", "math"], "Mathématiques"),
        (["francais"], "Français"),
        (["histoire-geo", "histoire geographie", "h-g", "hgeo"], "Histoire-Géographie"),
        (["emc", "enseignement moral et civique"], "EMC"),
        (["anglais"], "Anglais"),
        (["espagnol"], "Espagnol"),
        (["allemand"], "Allemand"),
        (["latin"], "Latin"),
        (["grec"], "Grec"),
        (["svt", "sciences de la vie"], "SVT"),
        (["physique-chimie", "physique chimie", "physique", "chimie"], "Physique-Chimie"),
        (["technologie"], "Technologie"),
        (["education physique", "eps", "sport"], "EPS"),
        (["arts plastiques"], "Arts plastiques"),
        (["education musicale", "musique"], "Musique"),
        (["sciences numeriques", "nsi"], "Numérique et sciences informatiques"),
        (["chorale"], "Chorale"),
        (["theatre"], "Théâtre"),
        (["accompagnement personnalise"], "Accompagnement personnalisé"),
        (["vie de classe"], "Vie de classe"),
        (["aide aux devoirs"], "Aide aux devoirs"),
    ]

    static func canonical(in line: String) -> String? {
        let folded = fold(line)
        for entry in map {
            for kw in entry.keywords where folded.contains(kw) {
                return entry.name
            }
        }
        return nil
    }

    static func fold(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR")).lowercased()
    }

    /// Ligne courte sans horaire ni score, qui ressemble à un intitulé.
    static func looksLikeLabel(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.count >= 2, t.count <= 40 else { return false }
        if t.range(of: "[0-9]{1,2}[:h][0-9]{2}", options: .regularExpression) != nil { return false }
        if t.contains("/") { return false }
        if canonical(in: t) != nil { return true }
        if t.range(of: "^[a-zà-âçéèêëîïôùûü]", options: [.regularExpression, .caseInsensitive]) != nil { return false }
        return true
    }
}

// MARK: - Extraction de blocs feuilles

enum DomWalk {
    static let blockTags: Set<String> = ["div", "p", "li", "tr", "ul", "ol", "table", "section", "article", "td", "nav", "header", "footer", "h1", "h2", "h3", "h4"]

    /// Blocs qui portent du contenu terminal, dans l'ordre du document.
    static func leafBlocks(_ root: HTMLNode) -> [HTMLNode] {
        var out: [HTMLNode] = []
        func walk(_ n: HTMLNode) {
            guard let tag = n.tag else { return }
            if tag == "li" || tag == "tr" {
                if !n.cleanedText.isEmpty { out.append(n) }
                return
            }
            if ["div", "p", "td", "section", "article", "header", "footer"].contains(tag) {
                let hasBlockChild = n.children.contains { c in
                    guard let t = c.tag else { return false }
                    return blockTags.contains(t)
                }
                if !hasBlockChild && !n.cleanedText.isEmpty {
                    out.append(n)
                    return
                }
            }
            for c in n.children { walk(c) }
        }
        for c in root.children { walk(c) }
        return out
    }

    /// Pièces jointes (liens vers fichiers) contenues dans un nœud.
    static func attachments(in node: HTMLNode, baseURL: URL) -> [Attachment] {
        var out: [Attachment] = []
        let exts = ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "odt", "ods", "zip", "jpg", "jpeg", "png", "gif", "csv", "mp3", "mp4"]
        var seen = Set<String>()
        for a in node.anchors {
            guard let href = a.href, !href.isEmpty, !href.lowercased().hasPrefix("javascript") else { continue }
            let lower = href.lowercased()
            let looksLikeFile = exts.contains(where: { lower.hasSuffix("." + $0) || lower.contains("." + $0 + "?") })
            guard looksLikeFile else { continue }
            let name = a.cleanedText.isEmpty ? (href as NSString).lastPathComponent : a.cleanedText
            let key = href.normalizedKey
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let resolved = URL(string: href, relativeTo: baseURL)?.absoluteURL
            out.append(Attachment(name: name.isEmpty ? "Pièce jointe" : name, url: resolved))
        }
        return out
    }
}

// MARK: - Expressions régulières prêtes à l'emploi

enum Patterns {
    static let timeRange = try? NSRegularExpression(
        pattern: "([0-9]{1,2})\\s*[:h]\\s*([0-9]{2})\\s*(?:-|–|à|a)\\s*([0-9]{1,2})\\s*[:h]\\s*([0-9]{2})",
        options: [.caseInsensitive])
    static let singleScore = try? NSRegularExpression(
        pattern: "(\\d{1,2}(?:[.,]\\d{1,2})?)\\s*/\\s*(\\d{1,3}(?:[.,]\\d{1,2})?)")
    static let dateSlash = try? NSRegularExpression(pattern: "\\b\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?\\b")
    static let dateWords = try? NSRegularExpression(
        pattern: "(?i)(?:pour\\s+(?:le\\s+)?)?(lun|mar|mer|jeu|ven|sam|dim)[a-zéû\\.]*\\s+\\d{1,2}(?:er)?\\s+[a-zéû]+(?:\\s+\\d{4})?")

    static func first(regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = regex.firstMatch(in: text, range: range), let r = Range(m.range, in: text) else { return nil }
        return String(text[r])
    }

    static func groups(_ regex: NSRegularExpression, _ text: String) -> [String] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = regex.firstMatch(in: text, range: range) else { return [] }
        return (1..<m.numberOfRanges).compactMap { i in
            guard let r = Range(m.range(at: i), in: text) else { return nil }
            return String(text[r])
        }
    }

    static func decimals(in text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: "\\d{1,2}(?:[.,]\\d{1,2})?") else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { m in
            guard let r = Range(m.range, in: text) else { return nil }
            return Double(String(text[r]).replacingOccurrences(of: ",", with: "."))
        }
    }
}

func firstCapture(pattern: String, in text: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    guard let m = regex.firstMatch(in: text, range: range), m.numberOfRanges > 1,
          let r = Range(m.range(at: 1), in: text) else { return nil }
    return String(text[r])
}

// MARK: - Emploi du temps

enum ScheduleParser {
    static func parse(_ doc: HTMLNode, reference: Date) -> [Course] {
        var courses: [Course] = []
        var seen = Set<String>()
        var currentDate: Date?
        var open: Int? = nil

        for rawLine in doc.visibleLines() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if let m = Patterns.first(regex: Patterns.dateWords, in: line),
               let d = DateFR.parse(m, reference: reference) {
                currentDate = d
                open = nil
                continue
            }
            if let m = Patterns.first(regex: Patterns.dateSlash, in: line),
               let d = DateFR.parse(m, reference: reference) {
                currentDate = d
                open = nil
                continue
            }

            if let matched = Patterns.first(regex: Patterns.timeRange, in: line),
               let regex = Patterns.timeRange {
                let gs = Patterns.groups(regex, line)
                guard gs.count == 4,
                      let sh = Int(gs[0]), let sm = Int(gs[1]), let eh = Int(gs[2]), let em = Int(gs[3]),
                      sh <= 23, eh <= 23, sm <= 59, em <= 59,
                      (eh * 60 + em) > (sh * 60 + sm) else { continue }
                let day = currentDate ?? DateFR.calendar.startOfDay(for: reference)
                guard let start = Calendar.current.date(byAdding: .minute, value: sh * 60 + sm, to: day),
                      let end = Calendar.current.date(byAdding: .minute, value: eh * 60 + em, to: day) else { continue }

                let rest = line.replacingOccurrences(of: matched, with: " ").trimmingCharacters(in: .whitespaces)
                let folded = Subjects.fold(line)
                let isBreak = folded.contains("pause") || folded.contains("recreation")
                let subject: String = isBreak
                    ? "Pause"
                    : (Subjects.canonical(in: rest) ?? Subjects.canonical(in: line) ?? "Cours")
                let key = DateFR.dayKey(day) + "|" + matched + "|" + subject.normalizedKey
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                var course = Course(stableKey: key, date: day, start: start, end: end,
                                    subject: subject, room: "", teacher: "", groupName: "",
                                    isBreak: isBreak, note: "")
                if !rest.isEmpty && Subjects.canonical(in: rest) == nil {
                    course.note = rest
                }
                courses.append(course)
                open = courses.count - 1
                continue
            }

            guard let i = open, courses.indices.contains(i), line.count <= 80 else { continue }
            let folded = Subjects.fold(line)
            if folded.range(of: "\\b(m\\.|mme|mlle|monsieur|madame)\\b", options: .regularExpression) != nil {
                if courses[i].teacher.isEmpty { courses[i].teacher = line }
            } else if folded.contains("salle") || folded.contains("amphi") || folded.contains("laboratoire") ||
                        line.range(of: "^[A-Z]{1,2}[0-9]{2,5}$", options: .regularExpression) != nil ||
                        line.range(of: "^[0-9]{3}$", options: .regularExpression) != nil {
                if courses[i].room.isEmpty { courses[i].room = line }
            } else if folded.contains("annul") || folded.contains("permanence") || folded.contains("groupe") ||
                        folded.contains("evalu") || folded.contains("controle") {
                courses[i].note = courses[i].note.isEmpty ? line : courses[i].note + " — " + line
            } else if courses[i].subject == "Cours", let s = Subjects.canonical(in: line) {
                courses[i].subject = s
            } else if courses[i].groupName.isEmpty,
                      Subjects.looksLikeLabel(line),
                      Subjects.canonical(in: line) != line,
                      Subjects.canonical(in: line) != courses[i].subject {
                courses[i].groupName = line
            }
        }
        return courses.sorted { $0.start < $1.start }
    }
}

// MARK: - Devoirs

enum HomeworkParser {
    static func parse(_ doc: HTMLNode, baseURL: URL, reference: Date) -> [Homework] {
        var out: [Homework] = []
        var seen = Set<String>()
        var currentDate: Date?

        for block in DomWalk.leafBlocks(doc) {
            let text = block.cleanedText
            guard text.count >= 8, text.count <= 4000 else { continue }

            let dateWords = Patterns.first(regex: Patterns.dateWords, in: text)
            let dateSlash = Patterns.first(regex: Patterns.dateSlash, in: text)
            let subject = Subjects.canonical(in: text)
            let isPureDate = text.count <= 60 && (dateWords != nil || dateSlash != nil) && subject == nil

            if isPureDate {
                currentDate = DateFR.parse(dateWords ?? dateSlash ?? "", reference: reference)
                continue
            }

            guard subject != nil || dateWords != nil || dateSlash != nil else { continue }
            let folded = Subjects.fold(text)
            if folded.range(of: "absence|retard|punition|sanction|absent|retardataire", options: .regularExpression) != nil { continue }
            if folded.range(of: "\\d{1,2}\\s*/\\s*\\d{1,3}", options: .regularExpression) != nil { continue }

            var due = currentDate
            if let m = dateWords, let d = DateFR.parse(m, reference: reference) { due = d }
            else if let m = dateSlash, let d = DateFR.parse(m, reference: reference) { due = d }

            var body = text
            if let m = dateWords {
                body = body.replacingOccurrences(of: m, with: " ").trimmingCharacters(in: .whitespaces)
            } else if let m = dateSlash {
                body = body.replacingOccurrences(of: m, with: " ").trimmingCharacters(in: .whitespaces)
            }
            if let s = subject {
                if body.normalizedKey.hasPrefix(s.normalizedKey) {
                    body = String(body.dropFirst(s.count)).trimmingCharacters(in: CharacterSet(charactersIn: " :;.·-–"))
                }
            }
            guard body.count >= 8 else { continue }

            let key = fingerprintDue(due, subject, body)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(Homework(stableKey: key, due: due,
                                subject: subject ?? "Matière non identifiée",
                                text: body,
                                attachments: DomWalk.attachments(in: block, baseURL: baseURL),
                                done: false))
        }
        return out
    }

    static func fingerprintDue(_ due: Date?, _ subject: String?, _ body: String) -> String {
        (due.map(DateFR.dayKey) ?? "??") + "|" + (subject ?? "") + "|" + body.normalizedKey
    }
}
