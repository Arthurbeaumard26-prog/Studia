import SwiftUI

// MARK: - Onglet Cours : un jour par écran, balayage horizontal

struct ScheduleView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedDay = DateFR.calendar.startOfDay(for: Date())

    private var days: [Date] {
        var dayList: [Date] = []
        let today = DateFR.calendar.startOfDay(for: Date())
        if model.snapshot.courses.isEmpty {
            for offset in -3...21 {
                if let d = Calendar.current.date(byAdding: .day, value: offset, to: today) {
                    dayList.append(d)
                }
            }
            return dayList
        }
        let first = model.snapshot.courses.map(\.date).min() ?? today
        let last = model.snapshot.courses.map(\.date).max() ?? today
        let start = min(DateFR.startOfWeek(first), today)
        let end = max(last, today)
        var cursor = start
        while cursor <= end, dayList.count < 180 {
            dayList.append(cursor)
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dayList
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedDay) {
                ForEach(days, id: \.self) { day in
                    DaySchedulePage(day: day, courses: courses(on: day))
                        .tag(day)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color(Theme.background))
            .navigationTitle(DateFR.title(selectedDay))
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if DateFR.sameDay(selectedDay, Date()) {
                        BlueBadge(text: "Aujourd'hui")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        weekButton("chevron.left", offset: -7)
                        Button {
                            withAnimation { selectedDay = DateFR.calendar.startOfDay(for: Date()) }
                        } label: {
                            Image(systemName: "smallcircle.filled.circle")
                                .foregroundStyle(Color(Theme.accent))
                        }
                        weekButton("chevron.right", offset: 7)
                    }
                }
            }
            .refreshable {
                await model.refreshAll(silent: true)
            }
        }
    }

    @ViewBuilder
    private func weekButton(_ icon: String, offset: Int) -> some View {
        Button {
            if let target = Calendar.current.date(byAdding: .day, value: offset, to: selectedDay) {
                withAnimation { selectedDay = target }
            }
        } label: {
            Image(systemName: icon)
                .foregroundStyle(Color(Theme.accent))
        }
    }

    private func courses(on day: Date) -> [Course] {
        model.snapshot.courses
            .filter { DateFR.sameDay($0.date, day) }
            .sorted { $0.start < $1.start }
    }
}

struct DaySchedulePage: View {
    var day: Date
    var courses: [Course]

    var body: some View {
        Group {
            if courses.isEmpty {
                EmptyState(icon: "sun.max", title: "Aucun cours",
                           message: "Aucun cours n'a été récupéré pour ce jour.")
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(courses) { course in
                            CourseRow(course: course)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
    }
}

struct CourseRow: View {
    var course: Course

    var body: some View {
        Card {
            HStack(spacing: 14) {
                VStack(spacing: 2) {
                    Text(course.start.formatted(date: .omitted, time: .shortened))
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Color(Theme.text))
                    Text(course.duration)
                        .font(.caption2)
                        .foregroundStyle(Color(Theme.textTertiary))
                }
                .frame(width: 64, alignment: .leading)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(Theme.accent).opacity(course.isBreak ? 0.35 : 1))
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.subject)
                        .font(.body.weight(.medium))
                        .foregroundStyle(course.isBreak ? Color(Theme.textSecondary) : Color(Theme.text))
                    if !course.room.isEmpty || !course.teacher.isEmpty || !course.groupName.isEmpty {
                        Text([course.room, course.teacher, course.groupName].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.footnote)
                            .foregroundStyle(Color(Theme.textSecondary))
                            .lineLimit(1)
                    }
                    if !course.note.isEmpty {
                        Text(course.note)
                            .font(.caption)
                            .foregroundStyle(Color(Theme.accent))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Text(course.end.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color(Theme.textTertiary))
            }
        }
    }
}
