import SwiftUI

struct RootView: View {
    @Bindable var model: AppModel

    var body: some View {
        NavigationSplitView {
            Sidebar(model: model)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            Group {
                switch model.selectedSection {
                case .today: DashboardView(model: model)
                case .tasks: TasksView(model: model)
                case .projects: ProjectsView(model: model)
                case .reflect: ReflectionView(model: model)
                case .review: ReviewView(model: model)
                case .apps: AppsView(model: model)
                }
            }
            .background {
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor), DaymarkTheme.amber.opacity(0.035)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }
        .sheet(item: $model.presentedSheet) { destination in
            switch destination {
            case .newTask: TaskEditorSheet(model: model, taskID: nil)
            case .editTask(let id): TaskEditorSheet(model: model, taskID: id)
            case .morningPlan: MorningPlanSheet(model: model)
            }
        }
    }
}

private struct Sidebar: View {
    @Bindable var model: AppModel

    var body: some View {
        List(selection: $model.selectedSection) {
            Section {
                ForEach(AppSection.allCases) { section in
                    Label(section.rawValue, systemImage: section.symbol)
                        .tag(section)
                }
            }

            Section("At a glance") {
                SidebarMetric(value: "\(model.openTodayTasks.count)", label: "open today", color: DaymarkTheme.coral)
                SidebarMetric(value: "\(model.focusMinutesToday)m", label: "focused", color: DaymarkTheme.indigo)
                SidebarMetric(value: "\(model.streak)", label: "day streak", color: DaymarkTheme.mint)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                Image(systemName: "sun.horizon.fill")
                    .foregroundStyle(DaymarkTheme.amber)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DAYMARK").font(.caption.weight(.black)).tracking(1.5)
                    Text("Make today count").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(14)
        }
    }
}

private struct SidebarMetric: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.caption)
    }
}
