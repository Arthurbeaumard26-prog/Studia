import Foundation

enum DateFR {
    static let months: [String: Int] = [
        "janvier": 1, "fevrier": 1, "février": 2, "mars": 3, "avril": 4, "mai": 5,
        "juin": 6, "juillet": 7, "aout": 8, "août": 8, "septembre": 9, "octobre": 10,
        "novembre": 11, "decembre": 12, "décembre": 12,
    ]

    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.locale = Locale(identifier: "fr_FR")
        return c
    }()

    static func isWeekdayName(_ w: String) -> Bool {
        let names = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        return names.contains(w.lowercased())
    }

    /// Parse une date écrite en français : "mardi 10 novembre", "10/11", "10/11/2026",
    /// "demain", "aujourd'hui", plus heures "HH:mm".
    static func parse(_ raw: String, reference: Date = Date()) -> Date? {
        let s = raw
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }

        let cal = calendar
        var comps = cal.dateComponents([.year, .month, .day], from: reference)

        if s.contains("aujourd") || s.contains("ce jour") {
            return cal.date(from: comps)
        }
        if s.contains("demain") {
            if let d = cal.date(byAdding: .day, value: 1, to: reference) {
                return cal.startOfDay(for: d)
            }
        }
        if s.contains("hier") {
            if let d = cal.date(byAdding: .day, value: -1, to: reference) {
                return cal.startOfDay(for: d)
            }
        }

        // format "dd/mm[/yyyy]"
        let digits = s.replacingOccurrences(of: " ", with: "")
        let slash = digits.components(separatedBy: "/")
        if slash.count >= 2,
           let d = Int(slash[0].prefix(2)), let m = Int(slash[1].prefix(2)),
           (1...31).contains(d), (1...12).contains(m) {
            if slash.count >= 3, let y = Int(slash[2].prefix(4)), y > 2000 {
                comps.year = y
            } else {
                comps.year = inferredYear(day: d, month: m, reference: reference)
            }
            comps.day = d
            comps.month = m
            return cal.date(from: comps)
        }

        // format "mardi 10 novembre [2026]" / "10 novembre"
        let tokens = s.components(separatedBy: CharacterSet(charactersIn: " ,"))
            .filter { !$0.isEmpty }
        var day: Int?, monthNum: Int?, year: Int?
        for t in tokens {
            if let n = Int(t), n >= 1, n <= 31, day == nil {
                day = n
            } else if let n = Int(t), n > 2000 {
                year = n
            } else if let m = months[t] {
                monthNum = m
            }
        }
        if let d = day, let m = monthNum {
            comps.day = d
            comps.month = m
            comps.year = year ?? inferredYear(day: d, month: m, reference: reference)
            return cal.date(from: comps)
        }

        // ISO "2026-11-10"
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "fr_FR")
        for f in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd", "dd/MM/yyyy HH:mm", "dd/MM/yyyy"] {
            iso.dateFormat = f
            if let d = iso.date(from: raw.trimmingCharacters(in: .whitespaces)) {
                return f.contains("HH:mm") ? d : cal.startOfDay(for: d)
            }
        }
        return nil
    }

    static func inferredYear(day: Int, month: Int, reference: Date) -> Int {
        let cal = calendar
        let y = cal.component(.year, from: reference)
        func candidate(_ year: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: day))!
        }
        // Année scolaire (septembre → août) : on choisit l'année la plus proche
        // en restant cohérente avec l'année scolaire en cours.
        let near = candidate(y)
        if abs(near.timeIntervalSince(reference)) < 180 * 86400 { return y }
        let next = candidate(y + 1), prev = candidate(y - 1)
        let dn = abs(next.timeIntervalSince(reference)), dp = abs(prev.timeIntervalSince(reference))
        return dn < dp ? y + 1 : y - 1
    }

    static func parseTime(_ raw: String) -> (Int, Int)? {
        let pattern = "^([0-9]{1,2})\\s*[:h]\\s*([0-9]{2})$"
        guard let r = raw.range(of: pattern, options: .regularExpression) else { return nil }
        let parts = raw[r].components(separatedBy: CharacterSet(charactersIn: ":h "))
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    static func dateOn(_ day: Date, hour: Int, minute: Int) -> Date {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps) ?? day
    }

    static func dayKey(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: d)
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }

    static func startOfWeek(_ d: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: d)
    }

    static func title(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEEE d MMMM"
        let s = f.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    static func shortTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateFormat = "EEE d MMM"
        let s = f.string(from: d)
        return s.prefix(1).uppercased() + s.dropFirst()
    }
}

extension String {
    /// Clé stable pour dédupliquer : texte normalisé sans espace superflu.
    var normalizedKey: String {
        folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
