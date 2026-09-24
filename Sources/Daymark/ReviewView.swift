import SwiftUI

struct ReviewView: View {
    let model: AppModel

    private var totalMinutes: Int { model.sessionsThisWeek.reduce(0) { $0 + $1.durationMinutes } }
    private var projectsTouched: [(String, Int)] {
        Dictionary(grouping: model.sessionsThisWeek.compactMap { session in
            session.projectName.map { ($0, session.durationMinutes) }
        }, by: \.0)
        .map { name, values in (name, values.reduce(0) { $0 + $1.1 }) }
        .sorted { $0.1 > $1.1 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(
                    eyebrow: "Weekly review",
                    title: "Where your attention went",
                    subtitle: "A record of protected time, not a productivity score."
                )

                HStack(spacing: 16) {
                    ReviewMetric(value: "\(totalMinutes)", label: "focus minutes", color: DaymarkTheme.indigo)
                    ReviewMetric(value: "\(model.sessionsThisWeek.count)", label: "sessions", color: DaymarkTheme.coral)
                    ReviewMetric(value: "\(projectsTouched.count)", label: "projects touched", color: DaymarkTheme.mint)
                }

                HStack(alignment: .top, spacing: 18) {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("PROJECT ATTENTION").font(.caption.bold()).foregroundStyle(DaymarkTheme.mint)
                            if projectsTouched.isEmpty {
                                Text("Link a task to a project before focusing to see its momentum here.")
                                    .foregroundStyle(.secondary)
                            } else {
                                ForEach(projectsTouched, id: \.0) { project, minutes in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack { Text(project); Spacer(); Text("\(minutes)m").monospacedDigit() }
                                        GeometryReader { proxy in
                                            Capsule().fill(.quaternary)
                                                .overlay(alignment: .leading) {
                                                    Capsule().fill(DaymarkTheme.mint)
                                                        .frame(width: proxy.size.width * CGFloat(minutes) / CGFloat(max(totalMinutes, 1)))
                                                }
                                        }
                                        .frame(height: 7)
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SESSION HISTORY").font(.caption.bold()).foregroundStyle(DaymarkTheme.indigo)
                            if model.sessionsThisWeek.isEmpty {
                                Text("Your completed focus sessions will appear here.").foregroundStyle(.secondary)
                            } else {
                                ForEach(model.sessionsThisWeek.prefix(12)) { session in
                                    SessionRow(session: session)
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Review")
    }
}

private struct ReviewMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .top) { Capsule().fill(color).frame(height: 3).padding(.horizontal, 20) }
    }
}

private struct SessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.taskTitle ?? "Open focus")
                    .fontWeight(.medium)
                HStack {
                    Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    if let project = session.projectName { Text("• \(project)") }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if !session.note.isEmpty {
                    Text(session.note).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Text("\(session.durationMinutes)m").font(.caption.bold()).monospacedDigit()
        }
    }
}
