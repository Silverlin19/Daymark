import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case today = "Today"
    case tasks = "Tasks"
    case projects = "Projects"
    case reflect = "Reflect"
    case review = "Review"
    case apps = "Apps"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .tasks: "checkmark.circle.fill"
        case .projects: "square.stack.3d.up.fill"
        case .reflect: "moon.stars.fill"
        case .review: "chart.bar.xaxis"
        case .apps: "square.grid.2x2.fill"
        }
    }
}

enum TaskBucket: String, Codable, CaseIterable, Identifiable {
    case today = "Today"
    case next = "Next"
    case later = "Later"

    var id: String { rawValue }
}

enum FocusMode: String, Codable, CaseIterable, Identifiable {
    case single = "Focus"
    case pomodoro = "Pomodoro"

    var id: String { rawValue }
}

enum TimerPhase: String {
    case focus = "Focus"
    case breakTime = "Break"
}

enum AppCategory: String, Codable, CaseIterable, Identifiable {
    case productivity = "Productivity"
    case play = "Break & Play"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .productivity: "bolt.fill"
        case .play: "gamecontroller.fill"
        }
    }
}

struct DaymarkAppLink: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var path: String
    var category: AppCategory
}

struct FocusTask: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var note = ""
    var bucket: TaskBucket = .today
    var isComplete = false
    var createdAt = Date()
    var completedAt: Date?
    var reminderAt: Date?
    var projectPath: String?
    var projectName: String?
    var plannedDayKey: String?

    init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        bucket: TaskBucket = .today,
        isComplete: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        reminderAt: Date? = nil,
        projectPath: String? = nil,
        projectName: String? = nil,
        plannedDayKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.bucket = bucket
        self.isComplete = isComplete
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.reminderAt = reminderAt
        self.projectPath = projectPath
        self.projectName = projectName
        self.plannedDayKey = plannedDayKey
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, note, bucket, isComplete, createdAt, completedAt, reminderAt
        case projectPath, projectName, plannedDayKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        bucket = try container.decodeIfPresent(TaskBucket.self, forKey: .bucket) ?? .today
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        reminderAt = try container.decodeIfPresent(Date.self, forKey: .reminderAt)
        projectPath = try container.decodeIfPresent(String.self, forKey: .projectPath)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        plannedDayKey = try container.decodeIfPresent(String.self, forKey: .plannedDayKey)
    }
}

struct DailyEntry: Identifiable, Codable, Equatable {
    var id: String { dayKey }
    var dayKey: String
    var intention = ""
    var reflection = ""
    var energy = 3
}

struct FocusSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var startedAt: Date
    var durationMinutes: Int
    var completed: Bool
    var taskID: UUID?
    var taskTitle: String?
    var projectName: String?
    var note: String

    init(
        id: UUID = UUID(),
        startedAt: Date,
        durationMinutes: Int,
        completed: Bool,
        taskID: UUID? = nil,
        taskTitle: String? = nil,
        projectName: String? = nil,
        note: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.durationMinutes = durationMinutes
        self.completed = completed
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.projectName = projectName
        self.note = note
    }

    private enum CodingKeys: String, CodingKey {
        case id, startedAt, durationMinutes, completed, taskID, taskTitle, projectName, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        durationMinutes = try container.decode(Int.self, forKey: .durationMinutes)
        completed = try container.decodeIfPresent(Bool.self, forKey: .completed) ?? true
        taskID = try container.decodeIfPresent(UUID.self, forKey: .taskID)
        taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitle)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }
}

struct StoredState: Codable {
    var tasks: [FocusTask] = []
    var entries: [DailyEntry] = []
    var sessions: [FocusSession] = []
    var workspacePath: String = ""
    var focusLength = 25
    var focusMode: FocusMode = .single
    var pomodoroFocusLength = 25
    var pomodoroBreakLength = 5
    var pomodoroRounds = 4
    var chimesEnabled = true
    var notificationsEnabled = false
    var activeTaskID: UUID?
    var appLinks: [DaymarkAppLink] = []
    var hasSeededAppLinks = false

    init(
        tasks: [FocusTask] = [],
        entries: [DailyEntry] = [],
        sessions: [FocusSession] = [],
        workspacePath: String = "",
        focusLength: Int = 25,
        focusMode: FocusMode = .single,
        pomodoroFocusLength: Int = 25,
        pomodoroBreakLength: Int = 5,
        pomodoroRounds: Int = 4,
        chimesEnabled: Bool = true,
        notificationsEnabled: Bool = false,
        activeTaskID: UUID? = nil,
        appLinks: [DaymarkAppLink] = [],
        hasSeededAppLinks: Bool = false
    ) {
        self.tasks = tasks
        self.entries = entries
        self.sessions = sessions
        self.workspacePath = workspacePath
        self.focusLength = focusLength
        self.focusMode = focusMode
        self.pomodoroFocusLength = pomodoroFocusLength
        self.pomodoroBreakLength = pomodoroBreakLength
        self.pomodoroRounds = pomodoroRounds
        self.chimesEnabled = chimesEnabled
        self.notificationsEnabled = notificationsEnabled
        self.activeTaskID = activeTaskID
        self.appLinks = appLinks
        self.hasSeededAppLinks = hasSeededAppLinks
    }

    private enum CodingKeys: String, CodingKey {
        case tasks, entries, sessions, workspacePath, focusLength, focusMode
        case pomodoroFocusLength, pomodoroBreakLength, pomodoroRounds
        case chimesEnabled, notificationsEnabled, activeTaskID, appLinks, hasSeededAppLinks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try container.decodeIfPresent([FocusTask].self, forKey: .tasks) ?? []
        entries = try container.decodeIfPresent([DailyEntry].self, forKey: .entries) ?? []
        sessions = try container.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        workspacePath = try container.decodeIfPresent(String.self, forKey: .workspacePath) ?? ""
        focusLength = try container.decodeIfPresent(Int.self, forKey: .focusLength) ?? 25
        focusMode = try container.decodeIfPresent(FocusMode.self, forKey: .focusMode) ?? .single
        pomodoroFocusLength = try container.decodeIfPresent(Int.self, forKey: .pomodoroFocusLength) ?? 25
        pomodoroBreakLength = try container.decodeIfPresent(Int.self, forKey: .pomodoroBreakLength) ?? 5
        pomodoroRounds = try container.decodeIfPresent(Int.self, forKey: .pomodoroRounds) ?? 4
        chimesEnabled = try container.decodeIfPresent(Bool.self, forKey: .chimesEnabled) ?? true
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? false
        activeTaskID = try container.decodeIfPresent(UUID.self, forKey: .activeTaskID)
        appLinks = try container.decodeIfPresent([DaymarkAppLink].self, forKey: .appLinks) ?? []
        hasSeededAppLinks = try container.decodeIfPresent(Bool.self, forKey: .hasSeededAppLinks) ?? false
    }
}

struct ProjectSnapshot: Identifiable, Equatable, Sendable {
    var id: String { path }
    let name: String
    let path: String
    let branch: String?
    let isDirty: Bool
    let lastModified: Date
    let kind: String

    var freshness: ProjectFreshness {
        let days = Calendar.current.dateComponents([.day], from: lastModified, to: .now).day ?? 0
        if days <= 2 { return .active }
        if days <= 14 { return .resting }
        return .quiet
    }
}

enum ProjectFreshness: String, Sendable {
    case active = "Active"
    case resting = "Resting"
    case quiet = "Quiet"
}

enum SheetDestination: Identifiable {
    case newTask
    case editTask(UUID)
    case morningPlan

    var id: String {
        switch self {
        case .newTask: "new-task"
        case .editTask(let id): "edit-\(id.uuidString)"
        case .morningPlan: "morning-plan"
        }
    }
}

enum DaymarkLogic {
    static func isAppLocked(category: AppCategory, focusEndsAt: Date?, timerPhase: TimerPhase) -> Bool {
        category == .play && focusEndsAt != nil && timerPhase == .focus
    }

    static func orderedTasks(_ tasks: [FocusTask]) -> [FocusTask] {
        tasks.sorted {
            if $0.isComplete != $1.isComplete { return !$0.isComplete }
            if $0.bucket != $1.bucket {
                let order: [TaskBucket: Int] = [.today: 0, .next: 1, .later: 2]
                return order[$0.bucket, default: 3] < order[$1.bucket, default: 3]
            }
            return $0.createdAt < $1.createdAt
        }
    }

    static func streakDays(sessions: [FocusSession], now: Date = .now, calendar: Calendar = .current) -> Int {
        let completedDays = Set(sessions.filter(\.completed).map { calendar.startOfDay(for: $0.startedAt) })
        guard !completedDays.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: now)
        if !completedDays.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor), completedDays.contains(yesterday) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while completedDays.contains(cursor) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func smartCapture(_ input: String, projects: [ProjectSnapshot], now: Date = .now) -> SmartCaptureResult {
        var title = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var bucket: TaskBucket = .today
        let lowered = title.lowercased()
        if lowered.contains(" later") || lowered.hasSuffix("later") { bucket = .later }
        else if lowered.contains(" next") || lowered.hasSuffix("next") { bucket = .next }

        var projectPath: String?
        var projectName: String?
        for project in projects.sorted(by: { $0.name.count > $1.name.count }) {
            let token = "@\(project.name)"
            if let range = title.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]) {
                title.removeSubrange(range)
                projectPath = project.path
                projectName = project.name
                break
            }
        }

        var reminderAt: Date?
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue),
           let match = detector.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)),
           let date = match.date,
           date > now,
           let range = Range(match.range, in: title) {
            reminderAt = date
            title.removeSubrange(range)
        }

        for word in [" later", " next", " today"] {
            title = title.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        if title.isEmpty { title = input.trimmingCharacters(in: .whitespacesAndNewlines) }

        return SmartCaptureResult(
            title: title,
            bucket: bucket,
            reminderAt: reminderAt,
            projectPath: projectPath,
            projectName: projectName
        )
    }
}

struct SmartCaptureResult: Equatable {
    let title: String
    let bucket: TaskBucket
    let reminderAt: Date?
    let projectPath: String?
    let projectName: String?
}
