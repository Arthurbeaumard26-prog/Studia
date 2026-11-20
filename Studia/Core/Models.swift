import Foundation

// MARK: - Profil

struct StudentProfile: Codable, Hashable {
    var firstName: String = ""
    var lastName: String = ""
    var fullName: String = ""
    var className: String = ""
    var school: String = "Collège Françoise Dolto"
    var avatarURL: String = ""
}

// MARK: - Emploi du temps

struct Course: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    let date: Date
    let start: Date
    let end: Date
    var subject: String
    var room: String
    var teacher: String
    var groupName: String
    var isBreak: Bool
    var note: String

    var duration: String {
        let minutes = max(0, Int(end.timeIntervalSince(start) / 60))
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        if m == 0 { return "\(h) h" }
        return "\(h) h \(String(format: "%02d", m))"
    }

    var timeRange: String {
        "\(start.formatted(date: .omitted, time: .shortened)) – \(end.formatted(date: .omitted, time: .shortened))"
    }
}

// MARK: - Devoirs

struct Attachment: Codable, Hashable {
    var name: String
    var url: URL?
}

struct Homework: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    let due: Date?
    var subject: String
    var text: String
    var attachments: [Attachment]
    var done: Bool
}

// MARK: - Notes

struct Grade: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    let date: Date?
    var subject: String
    var valueText: String
    var outOfText: String
    var coefficient: String
    var average: String
    var title: String
    var comment: String
}

struct Appreciation: Codable, Hashable, Identifiable {
    var id: String { subject + "—" + text }
    var subject: String
    var author: String
    var text: String
}

struct SubjectSummary: Identifiable, Codable, Hashable {
    var id: String { subject }
    var subject: String
    var average: String
    var classAverage: String
    var coefficient: String
    var grades: [Grade]
}

struct Period: Identifiable, Codable, Hashable {
    var id: String { name }
    var name: String
    var generalAverage: String
    var classGeneralAverage: String
    var subjects: [SubjectSummary]
    var appreciations: [Appreciation]
}

// MARK: - Vie scolaire

enum LifeKind: String, Codable, CaseIterable {
    case absence, retard, observation, punition, sanction, carnet, dispensation

    var label: String {
        switch self {
        case .absence: "Absences"
        case .retard: "Retards"
        case .observation: "Observations"
        case .punition: "Punitions"
        case .sanction: "Sanctions"
        case .carnet: "Mots dans le carnet"
        case .dispensation: "Dispenses"
        }
    }

    var singular: String {
        switch self {
        case .absence: "Absence"
        case .retard: "Retard"
        case .observation: "Observation"
        case .punition: "Punition"
        case .sanction: "Sanction"
        case .carnet: "Mot dans le carnet"
        case .dispensation: "Dispense"
        }
    }

    var icon: String {
        switch self {
        case .absence: "person.slash"
        case .retard: "clock.badge.exclamationmark"
        case .observation: "eye"
        case .punition: "exclamationmark.triangle"
        case .sanction: "exclamationmark.octagon"
        case .carnet: "book.closed"
        case .dispensation: "stethoscope"
        }
    }

    var isAlert: Bool { self == .absence || self == .retard }
}

struct SchoolLifeEntry: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var kind: LifeKind
    var start: Date?
    var end: Date?
    var reason: String
    var duration: String
}

// MARK: - Cahier de textes

struct LessonEntry: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var date: Date?
    var subject: String
    var content: String
    var toDo: String
    var attachments: [Attachment]
}

// MARK: - Informations

struct NewsItem: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var title: String
    var date: Date?
    var body: String
    var author: String
    var surveyLink: URL?
}

// MARK: - Compétences

struct CompetencyItem: Codable, Hashable, Identifiable {
    var id: String { name + "—" + level }
    var name: String
    var level: String
}

struct CompetencyDomain: Identifiable, Codable, Hashable {
    var id: String { subject }
    var subject: String
    var level: String
    var items: [CompetencyItem]
}

// MARK: - Documents

struct ResourceDoc: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var name: String
    var subject: String
    var date: Date?
    var url: URL?
}

// MARK: - Agenda

struct AgendaEvent: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var date: Date?
    var title: String
    var kind: String
    var details: String
}

// MARK: - Messagerie

struct MailMessage: Identifiable, Codable, Hashable {
    var id: String { stableKey }
    let stableKey: String
    var subject: String
    var author: String
    var date: Date?
    var body: String
    var sent: Bool
}

// MARK: - Instantané complet

struct Snapshot: Codable {
    var profile = StudentProfile()
    var courses: [Course] = []
    var homework: [Homework] = []
    var periods: [Period] = []
    var life: [SchoolLifeEntry] = []
    var lessons: [LessonEntry] = []
    var news: [NewsItem] = []
    var competencies: [CompetencyDomain] = []
    var resources: [ResourceDoc] = []
    var agenda: [AgendaEvent] = []
    var messages: [MailMessage] = []
    var lastSync: Date?
    var rubricErrors: [String: String] = [:]

    var isLoggedIn: Bool { lastSync != nil }
}
