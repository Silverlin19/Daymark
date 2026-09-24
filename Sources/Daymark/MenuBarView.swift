import SwiftUI

struct MenuBarView: View {
    @Bindable var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var quickCapture = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("DAYMARK", systemImage: "sun.horizon.fill")
                    .font(.caption.bold())
                    .foregroundStyle(DaymarkTheme.amber)
                Spacer()
                Button("Open Daymark") { openWindow(id: "main") }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }

            if let end = model.focusEndsAt {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(model.timerPhase.rawValue.uppercased()).font(.caption.bold())
                        Spacer()
                        if model.focusMode == .pomodoro {
                            Text("\(model.pomodoroRound)/\(model.pomodoroRounds)").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                        Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .onChange(of: remaining) { _, value in
                                if value == 0 { model.timerDidExpire() }
                            }
                    }
                    Text(model.activeTask?.title ?? "Open focus")
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                    TextField("Focus note…", text: $model.focusNote)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(model.focusMode == .pomodoro ? "End cycle" : "Finish") { model.completeFocus() }
                            .buttonStyle(.borderedProminent)
                            .tint(DaymarkTheme.mint)
                        Button("Cancel") { model.cancelFocus() }
                    }
                }
                .padding(14)
                .background(DaymarkTheme.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Task", selection: $model.activeTaskID) {
                        Text("Open focus").tag(UUID?.none)
                        ForEach(model.openTodayTasks) { task in
                            Text(task.title).tag(Optional(task.id))
                        }
                    }
                    .labelsHidden()
                    .onChange(of: model.activeTaskID) { _, _ in model.save() }
                    Picker("Mode", selection: $model.focusMode) {
                        ForEach(FocusMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: model.focusMode) { _, _ in model.save() }
                    if model.focusMode == .pomodoro {
                        PomodoroConfigurationView(model: model)
                            .padding(10)
                            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
                    }
                    Button {
                        model.startFocus()
                    } label: {
                        Label(
                            model.focusMode == .pomodoro ? "Start \(model.pomodoroFocusLength)-minute Pomodoro" : "Start \(model.focusLength)-minute focus",
                            systemImage: "play.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DaymarkTheme.indigo)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("QUICK CAPTURE").font(.caption2.bold()).foregroundStyle(.secondary)
                TextField("Try “Review @mathfolio tomorrow at 9”", text: $quickCapture)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { capture() }
                Text("Use @project, today, next, later, or a date.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("\(model.completedTodayCount) done", systemImage: "checkmark.circle")
                Spacer()
                Label("\(model.focusMinutesToday)m", systemImage: "timer")
                Spacer()
                SettingsLink { Label("Settings", systemImage: "gear") }
                    .buttonStyle(.plain)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(width: 340)
    }

    private func capture() {
        let value = quickCapture.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        model.smartAddTask(value)
        quickCapture = ""
    }
}
