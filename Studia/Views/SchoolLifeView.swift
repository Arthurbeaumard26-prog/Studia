import SwiftUI

// MARK: - Onglet Vie scolaire : compteurs + liste datée

struct SchoolLifeView: View {
    @EnvironmentObject var model: AppModel

    private var entries: [SchoolLifeEntry] {
        model.snapshot.life
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyState(icon: "person.2", title: "Vie scolaire vide",
                               message: errorText() ?? "Aucune absence, retard, observation ou sanction récupéré.")
                } else {
                    content
                }
            }
            .background(Color(Theme.background))
            .navigationTitle("Vie scolaire")
            .refreshable {
                await model.refreshAll(silent: true)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                counters
                ForEach(groupedByMonth, id: \.0) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(Theme.accent))
                            .padding(.leading, 4)
                        ForEach(group.1) { entry in
                            LifeRow(entry: entry)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var counters: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(LifeKind.allCases, id: \.self) { kind in
                let count = entries.filter { $0.kind == kind }.count
                if count > 0 {
                    Card {
                        VStack(spacing: 6) {
                            Image(systemName: kind.icon)
                                .font(.title3)
                                .foregroundStyle(kind.isAlert ? Color(Theme.danger) : Color(Theme.accent))
                            Text("\(count)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color(Theme.text))
                            Text(kind.label)
                                .font(.caption2)
                                .foregroundStyle(Color(Theme.textSecondary))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var groupedByMonth: [(String, [SchoolLifeEntry])] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "MMMM yyyy"
        let groups = Dictionary(grouping: entries) { entry -> String in
            guard let d = entry.start else { return "Date inconnue" }
            return formatter.string(from: d)
        }
        return groups
            .map { group -> (String, [SchoolLifeEntry]) in (group.key, group.value) }
            .sorted { lhs, rhs in
                let l = lhs.1.compactMap(\.start).max() ?? .distantPast
                let r = rhs.1.compactMap(\.start).max() ?? .distantPast
                return l > r
            }
    }

    private func errorText() -> String? {
        model.snapshot.rubricErrors["life"]
    }
}

struct LifeRow: View {
    var entry: SchoolLifeEntry

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: entry.kind.icon)
                    .font(.body)
                    .foregroundStyle(entry.kind.isAlert ? Color(Theme.danger) : Color(Theme.accent))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.kind.singular)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(entry.kind.isAlert ? Color(Theme.danger) : Color(Theme.text))
                    if !entry.reason.isEmpty {
                        Text(entry.reason)
                            .font(.footnote)
                            .foregroundStyle(Color(Theme.textSecondary))
                            .lineLimit(4)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    if let d = entry.start {
                        Text(DateFR.shortTitle(d))
                            .font(.caption)
                            .foregroundStyle(Color(Theme.textTertiary))
                    }
                    if !entry.duration.isEmpty {
                        Text(entry.duration)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(Theme.accent))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }
}
