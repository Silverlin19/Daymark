import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class AppModel {
    var selectedSection: AppSection = .today
    var presentedSheet: SheetDestination?
    var tasks: [FocusTask] = []
    var entries: [DailyEntry] = []
    var sessions: [FocusSession] = []
    var projects: [ProjectSnapshot] = []
    var workspacePath = ""
    var focusLength = 25
    var focusMode: FocusMode = .single
    var pomodoroFocusLength = 25
    var pomodoroBreakLength = 5
    var pomodoroRounds = 4
    var chimesEnabled = true
    var notificationsEnabled = false
    var focusEndsAt: Date?
    var timerPhase: TimerPhase = .focus
    var pomodoroRound = 1
    var activeTaskID: UUID?
    var focusNote = ""
    var appLinks: [DaymarkAppLink] = []
    var hasSeededAppLinks = false
    var isScanning = false

    private let storeURL: URL
    private var activePhaseStartedAt: Date?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = support.appendingPathComponent("Daymark", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        storeURL = directory.appendingPathComponent("state.json")
        load()

        if workspacePath.isEmpty {
            workspacePath = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/GPT Projects").path
        }
        if !hasSeededAppLinks {
            appLinks = AppCatalog.installedDefaults()
            hasSeededAppLinks = true
            save()
        }
        ensureTodayEntry()
        refreshProjects()
    }

    var todayKey: String { Self.dayFormatter.string(from: .now) }

    var todayEntry: DailyEntry {
        entries.first(where: { $0.dayKey == todayKey }) ?? DailyEntry(dayKey: todayKey)
    }

    var openTodayTasks: [FocusTask] {
        DaymarkLogic.orderedTasks(tasks.filter {
            $0.bucket == .today && !$0.isComplete && ($0.plannedDayKey == nil || $0.plannedDayKey == todayKey)
        })
    }

    var planningCandidates: [FocusTask] {
        DaymarkLogic.orderedTasks(tasks.filter { task in
            guard !task.isComplete else { return false }
            if task.bucket != .today { return true }
            return task.plannedDayKey.map { $0 < todayKey } == true
        })
    }

    var activeTask: FocusTask? {
        activeTaskID.flatMap { id in tasks.first(where: { $0.id == id }) }
    }

    var sessionsThisWeek: [FocusSession] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        return sessions.filter { $0.startedAt >= start }.sorted { $0.startedAt > $1.startedAt }
    }

    var completedTodayCount: Int {
        tasks.filter { task in
            guard task.isComplete, let completedAt = task.completedAt else { return false }
            return Calendar.current.isDateInToday(completedAt)
        }.count
    }

    var focusMinutesToday: Int {
        sessions.filter { $0.completed && Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var streak: Int { DaymarkLogic.streakDays(sessions: sessions) }

    var playAppsLocked: Bool {
        DaymarkLogic.isAppLocked(category: .play, focusEndsAt: focusEndsAt, timerPhase: timerPhase)
    }

    func updateTodayEntry(_ update: (inout DailyEntry) -> Void) {
        ensureTodayEntry()
        guard let index = entries.firstIndex(where: { $0.dayKey == todayKey }) else { return }
        update(&entries[index])
        save()
    }

    func addTask(
        title: String,
        note: String,
        bucket: TaskBucket,
        reminderAt: Date?,
        projectPath: String? = nil,
        projectName: String? = nil
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let task = FocusTask(
            title: cleanTitle,
            note: note,
            bucket: bucket,
            reminderAt: reminderAt,
            projectPath: projectPath,
            projectName: projectName,
            plannedDayKey: bucket == .today ? todayKey : nil
        )
        tasks.append(task)
        save()
        scheduleReminder(for: task)
    }

    func updateTask(
        id: UUID,
        title: String,
        note: String,
        bucket: TaskBucket,
        reminderAt: Date?,
        projectPath: String?,
        projectName: String?
    ) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].title = cleanTitle
        tasks[index].note = note
        tasks[index].bucket = bucket
        tasks[index].reminderAt = reminderAt
        tasks[index].projectPath = projectPath
        tasks[index].projectName = projectName
        if bucket == .today, tasks[index].plannedDayKey == nil { tasks[index].plannedDayKey = todayKey }
        if bucket != .today { tasks[index].plannedDayKey = nil }
        let task = tasks[index]
        save()
        scheduleReminder(for: task)
    }

    func toggleTask(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].isComplete.toggle()
        tasks[index].completedAt = tasks[index].isComplete ? .now : nil
        if tasks[index].isComplete { NotificationService.cancelTaskReminder(id: task.id) }
        else { scheduleReminder(for: tasks[index]) }
        if tasks[index].isComplete, activeTaskID == task.id { activeTaskID = nil }
        save()
    }

    func deleteTask(_ task: FocusTask) {
        tasks.removeAll { $0.id == task.id }
        if activeTaskID == task.id { activeTaskID = nil }
        NotificationService.cancelTaskReminder(id: task.id)
        save()
    }

    func deleteTasks(at offsets: IndexSet, in visibleTasks: [FocusTask]) {
        let ids = Set(offsets.map { visibleTasks[$0].id })
        tasks.removeAll { ids.contains($0.id) }
        if let activeTaskID, ids.contains(activeTaskID) { self.activeTaskID = nil }
        ids.forEach(NotificationService.cancelTaskReminder)
        save()
    }

    func startFocus(taskID: UUID? = nil) {
        activeTaskID = taskID ?? activeTaskID ?? openTodayTasks.first?.id
        timerPhase = .focus
        pomodoroRound = 1
        beginPhase(minutes: focusMode == .pomodoro ? pomodoroFocusLength : focusLength)
        save()
    }

    func cancelFocus() {
        focusEndsAt = nil
        activePhaseStartedAt = nil
        focusNote = ""
        NotificationService.cancelTimerTransition()
    }

    func completeFocus() {
        if timerPhase == .focus { recordFocusSession() }
        focusEndsAt = nil
        activePhaseStartedAt = nil
        focusNote = ""
        NotificationService.cancelTimerTransition()
        save()
    }

    func timerDidExpire() {
        guard focusEndsAt != nil else { return }
        if timerPhase == .focus {
            recordFocusSession()
            if focusMode == .pomodoro, pomodoroRound < pomodoroRounds {
                timerPhase = .breakTime
                beginPhase(minutes: pomodoroBreakLength)
            } else {
                focusEndsAt = nil
                activePhaseStartedAt = nil
                focusNote = ""
                NotificationService.cancelTimerTransition()
                if chimesEnabled { NotificationService.playChime() }
            }
        } else {
            pomodoroRound += 1
            timerPhase = .focus
            beginPhase(minutes: pomodoroFocusLength)
        }
        save()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        guard enabled else {
            notificationsEnabled = false
            NotificationService.cancelAllPending()
            save()
            return
        }
        Task {
            notificationsEnabled = await NotificationService.requestPermission()
            if notificationsEnabled {
                for task in tasks where task.reminderAt.map({ $0 > .now }) == true && !task.isComplete {
                    _ = await NotificationService.scheduleTaskReminder(for: task)
                }
            }
            save()
        }
    }

    func smartAddTask(_ input: String) {
        let result = DaymarkLogic.smartCapture(input, projects: projects)
        addTask(
            title: result.title,
            note: "",
            bucket: result.bucket,
            reminderAt: result.reminderAt,
            projectPath: result.projectPath,
            projectName: result.projectName
        )
    }

    func planForToday(taskIDs: Set<UUID>) {
        for index in tasks.indices where taskIDs.contains(tasks[index].id) {
            tasks[index].bucket = .today
            tasks[index].plannedDayKey = todayKey
        }
        save()
    }

    func chooseWorkspace() {
        let panel = NSOpenPanel()
        panel.title = "Choose your projects folder"
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            workspacePath = url.path
            save()
            refreshProjects()
        }
    }

    func refreshProjects() {
        isScanning = true
        projects = WorkspaceScanner.scan(path: workspacePath)
        isScanning = false
    }

    func reveal(_ project: ProjectSnapshot) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: project.path)])
    }

    func launch(_ app: DaymarkAppLink) {
        guard !(app.category == .play && playAppsLocked) else { return }
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }

    func chooseApplication(for category: AppCategory) {
        let panel = NSOpenPanel()
        panel.title = "Add a \(category.rawValue) app"
        panel.prompt = "Add App"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard !appLinks.contains(where: { $0.path == url.path }) else { return }
        let name = url.deletingPathExtension().lastPathComponent
        appLinks.append(DaymarkAppLink(name: name, path: url.path, category: category))
        appLinks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }

    func removeAppLink(_ app: DaymarkAppLink) {
        appLinks.removeAll { $0.id == app.id }
        save()
    }

    func save() {
        let state = StoredState(
            tasks: tasks,
            entries: entries,
            sessions: sessions,
            workspacePath: workspacePath,
            focusLength: focusLength,
            focusMode: focusMode,
            pomodoroFocusLength: pomodoroFocusLength,
            pomodoroBreakLength: pomodoroBreakLength,
            pomodoroRounds: pomodoroRounds,
            chimesEnabled: chimesEnabled,
            notificationsEnabled: notificationsEnabled,
            activeTaskID: activeTaskID,
            appLinks: appLinks,
            hasSeededAppLinks: hasSeededAppLinks
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storeURL),
              let state = try? JSONDecoder().decode(StoredState.self, from: data) else { return }
        tasks = state.tasks
        entries = state.entries
        sessions = state.sessions
        workspacePath = state.workspacePath
        focusLength = state.focusLength
        focusMode = state.focusMode
        pomodoroFocusLength = state.pomodoroFocusLength
        pomodoroBreakLength = state.pomodoroBreakLength
        pomodoroRounds = state.pomodoroRounds
        chimesEnabled = state.chimesEnabled
        notificationsEnabled = state.notificationsEnabled
        activeTaskID = state.activeTaskID
        appLinks = state.appLinks
        hasSeededAppLinks = state.hasSeededAppLinks
    }

    private func beginPhase(minutes: Int) {
        let now = Date()
        activePhaseStartedAt = now
        focusEndsAt = now.addingTimeInterval(TimeInterval(minutes * 60))
        if chimesEnabled { NotificationService.playChime(isBreak: timerPhase == .breakTime) }
        if notificationsEnabled, let end = focusEndsAt {
            let title = timerPhase == .focus ? "Focus complete" : "Break complete"
            let body = timerPhase == .focus ? "Time to step away and reset." : "Ready for the next focus round?"
            Task { await NotificationService.scheduleTimerTransition(at: end, title: title, body: body) }
        }
    }

    private func recordFocusSession() {
        let configuredDuration = focusMode == .pomodoro ? pomodoroFocusLength : focusLength
        let startedAt = activePhaseStartedAt ?? Date().addingTimeInterval(TimeInterval(-configuredDuration * 60))
        let duration = max(1, Int(round(Date().timeIntervalSince(startedAt) / 60)))
        sessions.append(FocusSession(
            startedAt: startedAt,
            durationMinutes: duration,
            completed: true,
            taskID: activeTask?.id,
            taskTitle: activeTask?.title,
            projectName: activeTask?.projectName,
            note: focusNote.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
    }

    private func scheduleReminder(for task: FocusTask) {
        guard task.reminderAt != nil else {
            NotificationService.cancelTaskReminder(id: task.id)
            return
        }
        Task {
            let scheduled = await NotificationService.scheduleTaskReminder(for: task)
            notificationsEnabled = scheduled
            save()
        }
    }

    private func ensureTodayEntry() {
        guard !entries.contains(where: { $0.dayKey == todayKey }) else { return }
        entries.append(DailyEntry(dayKey: todayKey))
        save()
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
