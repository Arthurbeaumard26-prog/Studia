import SwiftUI

struct HomeView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if model.sessionExpired {
                    Section {
                        sessionBanner
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    statsGrid
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    nextCourseCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    urgentHomeworkCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    recentGradesCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    recentLifeCard
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    allSectionsGrid
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(Theme.background))
            .navigationTitle("Accueil")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await model.refreshAll(silent: false) }
                    } label: {
                        if model.backgroundRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(Color(Theme.accent))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    if let date = model.snapshot.lastSync {
                        Text("MAJ " + date.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(Color(Theme.textTertiary))
                    }
                }
            }
            .refreshable {
                await model.refreshAll(silent: true)
            }
        }
    }

    // MARK: sections

    private var profileHeader: some View {
        let p = model.snapshot.profile
        let name = p.fullName.isEmpty ? "Élève" : p.fullName
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(Theme.accentSoft))
                Text(initials(name))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(Theme.accent))
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color(Theme.text))
                Text([p.className, p.school].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(Color(Theme.textSecondary))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var sessionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Color(Theme.danger))
            Text("Ta session a expiré. Reconnecte-toi pour actualiser tes données.")
                .font(.footnote)
                .foregroundStyle(Color(Theme.text))
            Button("Se reconnecter") {
                model.startOver()
            }
            .font(.footnote.weight(.semibold))
            .tint(Color(Theme.accent))
        }
        .padding(14)
        .background(Color(Theme.dangerSoft))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            Card {
                StatCell(label: "Moyenne", value: generalAverage, icon: "chart.line.uptrend.xyaxis", highlighted: true)
            }
            Card {
                StatCell(label: "À faire", value: "\(pendingHomework.count)", icon: "book.closed")
            }
            Card {
                StatCell(label: "Absences", value: "\(count(kind: .absence))", icon: "person.slash",
                         highlighted: count(kind: .absence) > 0, alert: true)
            }
        }
        .padding(.horizontal, 16)
    }

    private var nextCourseCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(text: "Prochain cours", icon: "clock")
                if let course = nearestCourse {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(course.subject)
                                .font(.headline)
                                .foregroundStyle(Color(Theme.text))
                            Text([course.timeRange, course.room, course.teacher].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(Color(Theme.textSecondary))
                        }
                        Spacer()
                        if DateFR.sameDay(course.date, Date()) {
                            BlueBadge(text: "Aujourd'hui")
                        } else {
                            BlueBadge(text: DateFR.shortTitle(course.date))
                        }
                    }
                } else {
                    Text("Aucun cours à venir dans tes données.")
                        .font(.subheadline)
                        .foregroundStyle(Color(Theme.textSecondary))
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var urgentHomeworkCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Devoirs à remettre bientôt", icon: "book.closed")
                if urgentHomework.isEmpty {
                    Text("Rien à faire pour les prochains jours.")
                        .font(.subheadline)
                        .foregroundStyle(Color(Theme.textSecondary))
                } else {
                    ForEach(urgentHomework.prefix(4)) { hw in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hw.subject)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(Theme.accent))
                                Text(hw.text)
                                    .font(.footnote)
                                    .foregroundStyle(Color(Theme.textSecondary))
                                    .lineLimit(2)
                            }
                            Spacer()
                            if let due = hw.due {
                                Text(DateFR.shortTitle(due))
                                    .font(.caption)
                                    .foregroundStyle(Color(Theme.textTertiary))
                            }
                        }
                    }
                }
                NavigationLink {
                    HomeworkTabView()
                } label: {
                    Text("Tout voir dans Devoirs")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color(Theme.accent))
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
    }

    private var recentGradesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Dernières notes", icon: "chart.line.uptrend.xyaxis")
                let grades = latestGrades
                if grades.isEmpty {
                    Text("Aucune note récupérée pour l'instant.")
                        .font(.subheadline)
                        .foregroundStyle(Color(Theme.textSecondary))
                } else {
                    ForEach(grades.prefix(4)) { grade in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(grade.subject)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(Theme.text))
                                if let d = grade.date {
                                    Text(DateFR.shortTitle(d))
                                        .font(.caption)
                                        .foregroundStyle(Color(Theme.textTertiary))
                                }
                            }
                            Spacer()
                            Text("\(grade.valueText) / \(grade.outOfText)")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color(Theme.accent))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var recentLifeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Vie scolaire récente", icon: "person.2")
                let entries = Array(model.snapshot.life.prefix(3))
                if entries.isEmpty {
                    Text("Aucune absence, retard ou observation récupéré.")
                        .font(.subheadline)
                        .foregroundStyle(Color(Theme.textSecondary))
                } else {
                    ForEach(entries) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: entry.kind.icon)
                                .foregroundStyle(entry.kind.isAlert ? Color(Theme.danger) : Color(Theme.accent))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.kind.singular)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(Color(Theme.text))
                                if let d = entry.start {
                                    Text(DateFR.shortTitle(d))
                                        .font(.caption)
                                        .foregroundStyle(Color(Theme.textTertiary))
                                }
                            }
                            Spacer()
                            if !entry.duration.isEmpty {
                                Text(entry.duration)
                                    .font(.caption)
                                    .foregroundStyle(Color(Theme.textSecondary))
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var allSectionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Toutes les rubriques", icon: "square.grid.2x2")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                sectionLink("Cahier de textes", icon: "book.pages") { NotebookView() }
                sectionLink("Compétences", icon: "checkmark.seal") { CompetenciesView() }
                sectionLink("Informations", icon: "megaphone", badge: model.snapshot.news.count) { NewsView() }
                sectionLink("Documents", icon: "folder") { ResourcesView() }
                sectionLink("Agenda", icon: "calendar.badge.clock") { AgendaView() }
                sectionLink("Messagerie", icon: "envelope") { MessagingView() }
                sectionLink("Profil", icon: "person.circle") { ProfileView() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func sectionLink<Destination: View>(_ title: String, icon: String, badge: Int? = nil,
                                                @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color(Theme.accent))
                    .frame(width: 28)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color(Theme.text))
                Spacer()
                if let badge, badge > 0 {
                    BlueBadge(text: "\(badge)")
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(Theme.textTertiary))
            }
            .padding(14)
            .background(Color(Theme.surface))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: calculs

    private func initials(_ name: String) -> String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.count > 1 ? (parts.last?.first.map(String.init) ?? "") : ""
        return (first + last).uppercased()
    }

    private var generalAverage: String {
        model.snapshot.periods.compactMap(\.generalAverage).last ?? ""
    }

    private var pendingHomework: [Homework] {
        model.snapshot.homework.filter { !$0.done && ($0.due.map { $0 >= DateFR.calendar.startOfDay(for: Date()) } ?? true) }
    }

    private func count(kind: LifeKind) -> Int {
        model.snapshot.life.filter { $0.kind == kind }.count
    }

    private var nearestCourse: Course? {
        let all = model.snapshot.courses.filter { !$0.isBreak }
        return all.first { $0.end > Date() } ?? all.first { DateFR.sameDay($0.date, Date()) } ?? all.first
    }

    private var urgentHomework: [Homework] {
        pendingHomework
            .filter { hw in hw.due.map { $0.timeIntervalSinceNow < 10 * 86400 } ?? true }
            .sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }

    private var latestGrades: [Grade] {
        model.snapshot.periods
            .flatMap(\.subjects)
            .flatMap(\.grades)
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }
}
