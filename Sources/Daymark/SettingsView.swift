import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section("Focus") {
                Picker("Default timer", selection: $model.focusMode) {
                    ForEach(FocusMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .onChange(of: model.focusMode) { _, _ in model.save() }

                Stepper("Session length: \(model.focusLength) minutes", value: $model.focusLength, in: 5...180, step: 5)
                .disabled(model.focusMode == .pomodoro)
                .onChange(of: model.focusLength) { _, _ in model.save() }

                Toggle("Play transition chimes", isOn: $model.chimesEnabled)
                    .onChange(of: model.chimesEnabled) { _, _ in model.save() }
            }

            Section("Pomodoro") {
                PomodoroConfigurationView(model: model, showHeading: false)
                Text("These controls are also available directly beside the timer and in the menu bar before a cycle starts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Timer and task notifications", isOn: Binding(
                    get: { model.notificationsEnabled },
                    set: { model.setNotificationsEnabled($0) }
                ))
                Text("Task reminders can be added while creating or editing a task. macOS will ask for permission the first time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Projects") {
                LabeledContent("Workspace", value: URL(fileURLWithPath: model.workspacePath).lastPathComponent)
                Button("Choose projects folder…") { model.chooseWorkspace() }
            }

            Section {
                Text("Daymark keeps your tasks, intentions, sessions, and reflections on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 520)
    }
}
