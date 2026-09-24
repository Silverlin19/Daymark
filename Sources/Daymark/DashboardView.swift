import SwiftUI

struct DashboardView: View {
    @Bindable var model: AppModel

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return "Good morning" }
        if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .bottom) {
                    SectionHeading(
                        eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                        title: greeting,
                        subtitle: "A clear day starts with one honest choice."
                    )
                    Spacer()
                    Button {
                        model.presentedSheet = .newTask
                    } label: {
                        Label("Capture", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DaymarkTheme.coral)
                    .controlSize(.large)
                }

                HStack(alignment: .top, spacing: 18) {
                    IntentionCard(model: model)
                    FocusTimerCard(model: model)
                        .frame(width: 290)
                }

                if !model.planningCandidates.isEmpty {
                    Button {
                        model.presentedSheet = .morningPlan
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "sunrise.fill")
                                .font(.title2)
                                .foregroundStyle(DaymarkTheme.amber)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Plan today").fontWeight(.semibold)
                                Text("Choose intentionally from \(model.planningCandidates.count) waiting task\(model.planningCandidates.count == 1 ? "" : "s").")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding(14)
                        .background(DaymarkTheme.amber.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }

                HStack(alignment: .top, spacing: 18) {
                    TodayTasksCard(model: model)
                    MomentumCard(model: model)
                        .frame(width: 290)
                }
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Today")
    }
}

private struct IntentionCard: View {
    let model: AppModel
    @State private var intention = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Label("THE ONE THING", systemImage: "scope")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DaymarkTheme.indigo)

                TextField("What would make today feel meaningful?", text: $intention, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 23, weight: .semibold, design: .rounded))
                    .lineLimit(2...4)
                    .onSubmit { save() }

                Divider()

                HStack {
                    Text("Energy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            model.updateTodayEntry { $0.energy = value }
                        } label: {
                            Image(systemName: value <= model.todayEntry.energy ? "circle.fill" : "circle")
                                .foregroundStyle(value <= model.todayEntry.energy ? DaymarkTheme.amber : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Energy level \(value)")
                    }
                    Spacer()
                    Button("Save") { save() }
                        .buttonStyle(.borderless)
                }
            }
        }
        .onAppear { intention = model.todayEntry.intention }
        .onChange(of: model.todayEntry.intention) { _, newValue in intention = newValue }
    }

    private func save() {
        model.updateTodayEntry { $0.intention = intention }
    }
}

private struct FocusTimerCard: View {
    @Bindable var model: AppModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("FOCUS", systemImage: "timer")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DaymarkTheme.coral)

                if model.focusEndsAt == nil {
                    Picker("Timer mode", selection: $model.focusMode) {
                        ForEach(FocusMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: model.focusMode) { _, _ in model.save() }

                    if model.focusMode == .pomodoro {
                        PomodoroConfigurationView(model: model)
                            .padding(10)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Picker("Focus task", selection: $model.activeTaskID) {
                        Text("No linked task").tag(UUID?.none)
                        ForEach(model.openTodayTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: model.activeTaskID) { _, _ in model.save() }
                }

                if let end = model.focusEndsAt {
                    HStack {
                        Text(model.timerPhase.rawValue.uppercased())
                            .font(.caption.weight(.bold))
                            .foregroundStyle(model.timerPhase == .focus ? DaymarkTheme.coral : DaymarkTheme.mint)
                        Spacer()
                        if model.focusMode == .pomodoro {
                            Text("Round \(model.pomodoroRound) of \(model.pomodoroRounds)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .onChange(of: remaining) { _, value in
                                if value == 0 { model.timerDidExpire() }
                            }
                    }
                    TextField("Capture a focus note…", text: $model.focusNote)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(model.focusMode == .pomodoro ? "End cycle" : "Finish") { model.completeFocus() }
                            .buttonStyle(.borderedProminent)
                            .tint(DaymarkTheme.mint)
                        Button("Cancel") { model.cancelFocus() }
                    }
                } else {
                    Text(model.focusMode == .pomodoro ? "\(model.pomodoroFocusLength) • \(model.pomodoroBreakLength) × \(model.pomodoroRounds)" : "\(model.focusLength) minutes")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(model.focusMode == .pomodoro ? "Focus • break • repeat" : "One task. No switching.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Begin session") { model.startFocus() }
                        .buttonStyle(.borderedProminent)
                        .tint(DaymarkTheme.indigo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TodayTasksCard: View {
    @Bindable var model: AppModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("TODAY", systemImage: "checkmark.circle")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(DaymarkTheme.mint)
                    Spacer()
                    Button("See all") { model.selectedSection = .tasks }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }

                if model.openTodayTasks.isEmpty {
                    ContentUnavailableView(
                        "A quiet slate",
                        systemImage: "sparkles",
                        description: Text("Capture a task, or protect the space you already have.")
                    )
                    .frame(minHeight: 130)
                } else {
                    ForEach(model.openTodayTasks.prefix(4)) { task in
                        TaskRow(
                            task: task,
                            toggle: { model.toggleTask(task) },
                            edit: { model.presentedSheet = .editTask(task.id) }
                        )
                        if task.id != model.openTodayTasks.prefix(4).last?.id { Divider() }
                    }
                }
            }
        }
    }
}

private struct MomentumCard: View {
    let model: AppModel

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("MOMENTUM", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(DaymarkTheme.amber)
                Metric(value: "\(model.completedTodayCount)", label: "tasks completed")
                Metric(value: "\(model.focusMinutesToday)", label: "focus minutes")
                Metric(value: "\(model.projects.filter { $0.freshness == .active }.count)", label: "active projects")
                Divider()
                Text(model.streak > 0 ? "You’re on a \(model.streak)-day focus streak." : "Complete a focus session to start a streak.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct Metric: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }
}

struct TaskRow: View {
    let task: FocusTask
    let toggle: () -> Void
    var edit: (() -> Void)?
    var delete: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Button(action: toggle) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isComplete ? DaymarkTheme.mint : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isComplete ? "Mark incomplete" : "Mark complete")
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.isComplete)
                    .foregroundStyle(task.isComplete ? .secondary : .primary)
                if !task.note.isEmpty {
                    Text(task.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if task.reminderAt != nil {
                Image(systemName: "bell.fill")
                    .font(.caption)
                    .foregroundStyle(DaymarkTheme.amber)
                    .help(task.reminderAt?.formatted(date: .abbreviated, time: .shortened) ?? "Reminder")
            }
            if let projectName = task.projectName {
                Label(projectName, systemImage: "folder")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(task.bucket.rawValue)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
            if edit != nil || delete != nil {
                Menu {
                    if let edit { Button("Edit", systemImage: "pencil", action: edit) }
                    if let delete { Button("Delete", systemImage: "trash", role: .destructive, action: delete) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .contextMenu {
            if let edit { Button("Edit", systemImage: "pencil", action: edit) }
            if let delete { Button("Delete", systemImage: "trash", role: .destructive, action: delete) }
        }
    }
}
