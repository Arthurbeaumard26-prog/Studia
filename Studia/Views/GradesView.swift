import SwiftUI

// MARK: - Onglet Notes : par trimestre, par matière

struct GradesView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedPeriodIndex = 0

    private var periods: [Period] {
        model.snapshot.periods
    }

    private var currentPeriod: Period? {
        guard !periods.isEmpty else { return nil }
        let index = min(selectedPeriodIndex, periods.count - 1)
        return periods[index]
    }

    var body: some View {
        NavigationStack {
            Group {
                if periods.isEmpty {
                    EmptyState(icon: "chart.line.uptrend.xyaxis", title: "Aucune note",
                               message: errorText(for: "grades") ?? "Aucune note n'a été récupérée. Tire vers le bas pour réessayer.")
                } else {
                    content
                }
            }
            .background(Color(Theme.background))
            .navigationTitle("Notes")
            .refreshable {
                await model.refreshAll(silent: true)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if periods.count > 1 {
                    Picker("Période", selection: $selectedPeriodIndex) {
                        ForEach(Array(periods.enumerated()), id: \.offset) { entry in
                            Text(entry.element.name).tag(entry.offset)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }

                if let period = currentPeriod {
                    averageCard(period)
                    ForEach(period.subjects) { subject in
                        SubjectCard(subject: subject)
                    }
                    if !period.appreciations.isEmpty {
                        appreciationsCard(period.appreciations)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private func averageCard(_ period: Period) -> some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Moyenne générale")
                        .font(.footnote)
                        .foregroundStyle(Color(Theme.textSecondary))
                    Text(period.generalAverage.isEmpty ? "—" : period.generalAverage + "/20")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(Theme.accent))
                }
                Spacer()
                if !period.classGeneralAverage.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Classe")
                            .font(.footnote)
                            .foregroundStyle(Color(Theme.textSecondary))
                        Text(period.classGeneralAverage + "/20")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(Color(Theme.textSecondary))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func appreciationsCard(_ list: [Appreciation]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(text: "Appréciations", icon: "text.bubble")
                ForEach(list) { appreciation in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appreciation.subject + (appreciation.author.isEmpty ? "" : " · " + appreciation.author))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(Theme.accent))
                        Text(appreciation.text)
                            .font(.footnote)
                            .foregroundStyle(Color(Theme.textSecondary))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func errorText(for key: String) -> String? {
        model.snapshot.rubricErrors[key]
    }
}

struct SubjectCard: View {
    var subject: SubjectSummary

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(subject.subject)
                        .font(.headline)
                        .foregroundStyle(Color(Theme.text))
                    Spacer()
                    Text(subject.average.isEmpty ? "—" : subject.average)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(Theme.accent))
                }
                HStack(spacing: 10) {
                    Text(subject.coefficient.isEmpty ? "coef —" : "coef " + subject.coefficient)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(Theme.accentSoft))
                        .foregroundStyle(Color(Theme.accent))
                        .clipShape(Capsule())
                    if !subject.classAverage.isEmpty {
                        Text("Classe : " + subject.classAverage)
                            .font(.caption)
                            .foregroundStyle(Color(Theme.textSecondary))
                    }
                    Spacer()
                }

                ForEach(subject.grades) { grade in
                    NavigationLink {
                        GradeDetailView(subject: subject.subject, grade: grade)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                if !grade.title.isEmpty {
                                    Text(grade.title)
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(Color(Theme.text))
                                        .lineLimit(1)
                                }
                                if let d = grade.date {
                                    Text(DateFR.shortTitle(d))
                                        .font(.caption2)
                                        .foregroundStyle(Color(Theme.textTertiary))
                                }
                            }
                            Spacer()
                            Text(grade.valueText + " / " + grade.outOfText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(Theme.accent))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Color(Theme.textTertiary))
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(Theme.surfaceRaised))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

struct GradeDetailView: View {
    var subject: String
    var grade: Grade

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subject)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(Theme.accent))
                        HStack(alignment: .firstTextBaseline) {
                            Text(grade.valueText)
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(Theme.text))
                            Text("/ " + grade.outOfText)
                                .font(.title3)
                                .foregroundStyle(Color(Theme.textSecondary))
                        }
                        if let d = grade.date {
                            Text(DateFR.title(d))
                                .font(.footnote)
                                .foregroundStyle(Color(Theme.textTertiary))
                        }
                    }
                }
                if !grade.coefficient.isEmpty || !grade.average.isEmpty || !grade.comment.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            if !grade.coefficient.isEmpty {
                                row("Coefficient", grade.coefficient)
                            }
                            if !grade.average.isEmpty {
                                row("Moyenne de la classe", grade.average)
                            }
                            if !grade.comment.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Commentaire")
                                        .font(.caption)
                                        .foregroundStyle(Color(Theme.textSecondary))
                                    Text(grade.comment)
                                        .font(.footnote)
                                        .foregroundStyle(Color(Theme.text))
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(Theme.background))
        .navigationTitle("Détail de la note")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Color(Theme.textSecondary))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(Theme.text))
        }
    }
}
