import SwiftUI

struct ProjectsView: View {
    @Bindable var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    SectionHeading(eyebrow: "Workspace pulse", title: "Projects", subtitle: "See what’s moving without opening every folder.")
                    Spacer()
                    Button("Choose folder") { model.chooseWorkspace() }
                    Button { model.refreshProjects() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                        .buttonStyle(.borderedProminent)
                        .tint(DaymarkTheme.indigo)
                }

                HStack {
                    Image(systemName: "folder.fill").foregroundStyle(DaymarkTheme.amber)
                    Text(model.workspacePath).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text("\(model.projects.count) projects").font(.caption.weight(.semibold))
                }

                if model.projects.isEmpty {
                    Card {
                        ContentUnavailableView("No project folders found", systemImage: "folder.badge.questionmark", description: Text("Choose the folder where your work lives."))
                            .frame(maxWidth: .infinity, minHeight: 280)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.projects) { project in
                            ProjectCard(project: project) { model.reveal(project) }
                        }
                    }
                }
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Projects")
    }
}

private struct ProjectCard: View {
    let project: ProjectSnapshot
    let reveal: () -> Void

    private var freshnessColor: Color {
        switch project.freshness {
        case .active: DaymarkTheme.mint
        case .resting: DaymarkTheme.amber
        case .quiet: .secondary
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9).fill(DaymarkTheme.indigo.opacity(0.12))
                        Image(systemName: "folder.fill").foregroundStyle(DaymarkTheme.indigo)
                    }
                    .frame(width: 38, height: 38)
                    Spacer()
                    Circle().fill(freshnessColor).frame(width: 8, height: 8)
                    Text(project.freshness.rawValue).font(.caption).foregroundStyle(.secondary)
                }
                Text(project.name).font(.title3.bold()).lineLimit(1)
                HStack(spacing: 6) {
                    Text(project.kind)
                    if let branch = project.branch {
                        Text("•")
                        Image(systemName: "arrow.triangle.branch")
                        Text(branch).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                HStack {
                    if project.isDirty {
                        Label("Uncommitted work", systemImage: "pencil.circle.fill")
                            .foregroundStyle(DaymarkTheme.coral)
                    } else {
                        Label("Clean", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(DaymarkTheme.mint)
                    }
                    Spacer()
                    Button("Reveal", action: reveal).buttonStyle(.plain)
                }
                .font(.caption)
            }
        }
    }
}
