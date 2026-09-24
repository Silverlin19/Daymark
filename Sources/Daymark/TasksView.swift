import SwiftUI

struct TasksView: View {
    @Bindable var model: AppModel
    @State private var filter: TaskBucket?
    @State private var pendingDeletion: FocusTask?

    private var visibleTasks: [FocusTask] {
        DaymarkLogic.orderedTasks(model.tasks.filter { filter == nil || $0.bucket == filter })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .bottom) {
                SectionHeading(eyebrow: "Clear the noise", title: "Tasks", subtitle: "A small list you can actually trust.")
                Spacer()
                Picker("Filter", selection: $filter) {
                    Text("All").tag(TaskBucket?.none)
                    ForEach(TaskBucket.allCases) { bucket in
                        Text(bucket.rawValue).tag(Optional(bucket))
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
                Button { model.presentedSheet = .newTask } label: { Label("New task", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .tint(DaymarkTheme.coral)
            }

            Card {
                if visibleTasks.isEmpty {
                    ContentUnavailableView("Nothing here", systemImage: "checkmark", description: Text("Your attention is free."))
                        .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    List {
                        ForEach(visibleTasks) { task in
                            TaskRow(
                                task: task,
                                toggle: { model.toggleTask(task) },
                                edit: { model.presentedSheet = .editTask(task.id) },
                                delete: { pendingDeletion = task }
                            )
                                .padding(.vertical, 7)
                                .listRowSeparator(.visible)
                        }
                        .onDelete { model.deleteTasks(at: $0, in: visibleTasks) }
                    }
                    .listStyle(.plain)
                    .frame(minHeight: 300)
                }
            }
        }
        .padding(30)
        .frame(maxWidth: 1100, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Tasks")
        .alert("Delete this task?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        ), presenting: pendingDeletion) { task in
            Button("Delete", role: .destructive) { model.deleteTask(task) }
            Button("Cancel", role: .cancel) {}
        } message: { task in
            Text("“\(task.title)” and its reminder will be removed.")
        }
    }
}

@MainActor
struct TaskEditorSheet: View {
    let model: AppModel
    let taskID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var note: String
    @State private var bucket: TaskBucket
    @State private var reminderEnabled: Bool
    @State private var reminderDate: Date
    @State private var selectedProjectPath: String?
    @State private var confirmsDeletion = false
    @FocusState private var titleFocused: Bool

    init(model: AppModel, taskID: UUID?) {
        self.model = model
        self.taskID = taskID
        let task = taskID.flatMap { id in model.tasks.first(where: { $0.id == id }) }
        _title = State(initialValue: task?.title ?? "")
        _note = State(initialValue: task?.note ?? "")
        _bucket = State(initialValue: task?.bucket ?? .today)
        let fallbackReminder = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        let futureReminder = task?.reminderAt.flatMap { $0 > .now ? $0 : nil }
        _reminderEnabled = State(initialValue: futureReminder != nil)
        _reminderDate = State(initialValue: futureReminder ?? fallbackReminder)
        _selectedProjectPath = State(initialValue: task?.projectPath)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(
                eyebrow: taskID == nil ? "Quick capture" : "Task details",
                title: taskID == nil ? "What needs your attention?" : "Edit task"
            )
            TextField("Task", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .focused($titleFocused)
                .onSubmit { saveTask() }
            TextField("A useful note (optional)", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
            HStack {
                Picker("Project", selection: $selectedProjectPath) {
                    Text("No project").tag(String?.none)
                    ForEach(model.projects) { project in
                        Text(project.name).tag(Optional(project.path))
                    }
                }
                Spacer()
                Button("Interpret text", systemImage: "wand.and.stars") { applySmartCapture() }
                    .help("Recognize dates, Today/Next/Later, and @project names")
            }
            Picker("When", selection: $bucket) {
                ForEach(TaskBucket.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Toggle("Remind me", isOn: $reminderEnabled)
            if reminderEnabled {
                DatePicker("Reminder", selection: $reminderDate, in: .now...)
                    .datePickerStyle(.field)
            }

            HStack {
                if taskID != nil {
                    Button("Delete task", role: .destructive) { confirmsDeletion = true }
                }
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(taskID == nil ? "Add task" : "Save changes") { saveTask() }
                    .buttonStyle(.borderedProminent)
                    .tint(DaymarkTheme.coral)
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(28)
        .frame(width: 480)
        .onAppear { if taskID == nil { titleFocused = true } }
        .alert("Delete this task?", isPresented: $confirmsDeletion) {
            Button("Delete", role: .destructive) { deleteTask() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task and its scheduled reminder will be removed.")
        }
    }

    private func saveTask() {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let reminder = reminderEnabled ? reminderDate : nil
        let project = model.projects.first(where: { $0.path == selectedProjectPath })
        if let taskID {
            model.updateTask(
                id: taskID,
                title: title,
                note: note,
                bucket: bucket,
                reminderAt: reminder,
                projectPath: project?.path,
                projectName: project?.name
            )
        } else {
            model.addTask(
                title: title,
                note: note,
                bucket: bucket,
                reminderAt: reminder,
                projectPath: project?.path,
                projectName: project?.name
            )
        }
        dismiss()
    }

    private func deleteTask() {
        guard let taskID, let task = model.tasks.first(where: { $0.id == taskID }) else { return }
        model.deleteTask(task)
        dismiss()
    }

    private func applySmartCapture() {
        let result = DaymarkLogic.smartCapture(title, projects: model.projects)
        title = result.title
        bucket = result.bucket
        if let reminder = result.reminderAt {
            reminderEnabled = true
            reminderDate = reminder
        }
        selectedProjectPath = result.projectPath ?? selectedProjectPath
    }
}
