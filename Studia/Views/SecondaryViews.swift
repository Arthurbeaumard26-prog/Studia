import SwiftUI

// MARK: - Cahier de textes

struct NotebookView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.snapshot.lessons.isEmpty {
                EmptyState(icon: "book.pages", title: "Cahier de textes vide",
                           message: model.snapshot.rubricErrors["notebook"] ?? "Aucun contenu de séance récupéré.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(groupedByDay, id: \.0) { group in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(group.0.map { DateFR.title($0) } ?? "Date inconnue")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(Theme.accent))
                                    .padding(.leading, 4)
                                ForEach(group.1) { lesson in
                                    lessonCard(lesson)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Cahier de textes")
        .refreshable { await model.refreshAll(silent: true) }
    }

    private var groupedByDay: [(Date?, [LessonEntry])] {
        let dated = Dictionary(grouping: model.snapshot.lessons) { $0.date }
        return dated
            .sorted { ($0.key ?? .distantFuture) > ($1.key ?? .distantFuture) }
            .map { ($0.key, $0.value) }
    }

    private func lessonCard(_ lesson: LessonEntry) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(lesson.subject)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(Theme.accent))
                Text(lesson.content)
                    .font(.footnote)
                    .foregroundStyle(Color(Theme.text))
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Compétences

struct CompetenciesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.snapshot.competencies.isEmpty {
                EmptyState(icon: "checkmark.seal", title: "Aucune compétence",
                           message: model.snapshot.rubricErrors["competencies"] ?? "Aucun niveau d'acquisition récupéré.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.snapshot.competencies) { domain in
                            Card {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text(domain.subject)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color(Theme.text))
                                        Spacer()
                                        BlueBadge(text: domain.level)
                                    }
                                    ForEach(domain.items) { item in
                                        HStack(alignment: .top) {
                                            Image(systemName: "checkmark.circle")
                                                .font(.caption)
                                                .foregroundStyle(Color(Theme.accent))
                                                .padding(.top, 2)
                                            Text(item.name)
                                                .font(.footnote)
                                                .foregroundStyle(Color(Theme.textSecondary))
                                            Spacer()
                                            Text(item.level)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color(Theme.accent))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Compétences")
        .refreshable { await model.refreshAll(silent: true) }
    }
}

// MARK: - Informations et actualités

struct NewsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.snapshot.news.isEmpty {
                EmptyState(icon: "megaphone", title: "Aucune information",
                           message: model.snapshot.rubricErrors["news"] ?? "Aucun message du collège récupéré.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(model.snapshot.news) { item in
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        if let date = item.date {
                                            Text(DateFR.shortTitle(date))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(Color(Theme.accent))
                                        }
                                        Spacer()
                                    }
                                    Text(item.body)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(Theme.text))
                                    if let link = item.surveyLink {
                                        Link(destination: link) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checklist")
                                                    .font(.caption)
                                                Text("Formulaires à remplir")
                                                    .font(.footnote.weight(.semibold))
                                            }
                                            .foregroundStyle(Color(Theme.accent))
                                        }
                                        .padding(.top, 2)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Informations")
        .refreshable { await model.refreshAll(silent: true) }
    }
}

// MARK: - Documents et ressources

struct ResourcesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.snapshot.resources.isEmpty {
                EmptyState(icon: "folder", title: "Aucun document",
                           message: model.snapshot.rubricErrors["resources"] ?? "Aucun fichier mis à disposition récupéré.")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(model.snapshot.resources) { doc in
                            Card {
                                HStack(spacing: 12) {
                                    Image(systemName: doc.name.hasSuffix("pdf") ? "doc.richtext" : "doc")
                                        .foregroundStyle(Color(Theme.accent))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(doc.name)
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(Color(Theme.text))
                                            .lineLimit(2)
                                        if let date = doc.date {
                                            Text(DateFR.shortTitle(date))
                                                .font(.caption2)
                                                .foregroundStyle(Color(Theme.textTertiary))
                                        }
                                    }
                                    Spacer()
                                    if let url = doc.url {
                                        Link(destination: url) {
                                            Image(systemName: "arrow.down.circle")
                                                .foregroundStyle(Color(Theme.accent))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Documents")
        .refreshable { await model.refreshAll(silent: true) }
    }
}

// MARK: - Agenda

struct AgendaView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Group {
            if model.snapshot.agenda.isEmpty {
                EmptyState(icon: "calendar.badge.clock", title: "Aucun événement",
                           message: model.snapshot.rubricErrors["agenda"] ?? "Aucun événement ou contrôle annoncé récupéré.")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(model.snapshot.agenda) { event in
                            Card {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        BlueBadge(text: event.kind)
                                        Spacer()
                                        if let date = event.date {
                                            Text(DateFR.shortTitle(date))
                                                .font(.caption)
                                                .foregroundStyle(Color(Theme.textTertiary))
                                        }
                                    }
                                    Text(event.details)
                                        .font(.subheadline)
                                        .foregroundStyle(Color(Theme.text))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Agenda")
        .refreshable { await model.refreshAll(silent: true) }
    }
}

// MARK: - Messagerie

struct MessagingView: View {
    @EnvironmentObject var model: AppModel

    private var received: [MailMessage] {
        model.snapshot.messages.filter { !$0.sent }
    }

    private var sent: [MailMessage] {
        model.snapshot.messages.filter { $0.sent }
    }

    var body: some View {
        Group {
            if model.snapshot.messages.isEmpty {
                EmptyState(icon: "envelope", title: "Messagerie vide",
                           message: model.snapshot.rubricErrors["messaging"] ?? "Aucun message récupéré. La messagerie est peut-être désactivée par ton établissement.")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !received.isEmpty {
                            SectionTitle(text: "Reçus", icon: "tray")
                            ForEach(received) { message in MailRow(message: message) }
                        }
                        if !sent.isEmpty {
                            SectionTitle(text: "Envoyés", icon: "paperplane")
                            ForEach(sent) { message in MailRow(message: message) }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(Theme.background))
        .navigationTitle("Messagerie")
        .refreshable { await model.refreshAll(silent: true) }
    }
}

struct MailRow: View {
    var message: MailMessage

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text(message.subject)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(Theme.text))
                    .lineLimit(2)
                HStack {
                    if !message.author.isEmpty {
                        Text(message.author)
                            .font(.caption)
                            .foregroundStyle(Color(Theme.accent))
                    }
                    Spacer()
                    if let date = message.date {
                        Text(DateFR.shortTitle(date))
                            .font(.caption)
                            .foregroundStyle(Color(Theme.textTertiary))
                    }
                }
                if message.body.count > message.subject.count {
                    Text(message.body)
                        .font(.footnote)
                        .foregroundStyle(Color(Theme.textSecondary))
                }
            }
        }
    }
}

// MARK: - Profil

struct ProfileView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(Color(Theme.accentSoft))
                            Text(initials)
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(Color(Theme.accent))
                        }
                        .frame(width: 84, height: 84)
                        Text(model.snapshot.profile.fullName.isEmpty ? "Élève" : model.snapshot.profile.fullName)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Color(Theme.text))
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)

                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow("Prénom", model.snapshot.profile.firstName)
                        infoRow("Nom", model.snapshot.profile.lastName)
                        infoRow("Classe", model.snapshot.profile.className)
                        infoRow("Établissement", model.snapshot.profile.school)
                        infoRow("Plateforme", "Pronote · Collège Françoise Dolto")
                        if let sync = model.snapshot.lastSync {
                            infoRow("Dernière mise à jour", sync.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                .padding(.horizontal, 16)

                Button(role: .destructive) {
                    model.logout()
                } label: {
                    Text("Se déconnecter")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(Theme.danger))
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .background(Color(Theme.background))
        .navigationTitle("Profil")
    }

    private var initials: String {
        let full = model.snapshot.profile.fullName
        let parts = full.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !parts.isEmpty else { return "?" }
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(Theme.textSecondary))
                .frame(width: 130, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(Theme.text))
            Spacer()
        }
    }
}
