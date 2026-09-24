import XCTest
@testable import Daymark

final class DaymarkTests: XCTestCase {
    private struct LegacyTask: Codable {
        let id: UUID
        let title: String
        let note: String
        let bucket: TaskBucket
        let isComplete: Bool
        let createdAt: Date
        let completedAt: Date?
    }

    private struct LegacySession: Codable {
        let id: UUID
        let startedAt: Date
        let durationMinutes: Int
        let completed: Bool
    }

    func testTaskOrderingPutsOpenTodayFirst() {
        let now = Date()
        let tasks = [
            FocusTask(title: "Done", bucket: .today, isComplete: true, createdAt: now),
            FocusTask(title: "Later", bucket: .later, createdAt: now),
            FocusTask(title: "Today", bucket: .today, createdAt: now)
        ]

        XCTAssertEqual(DaymarkLogic.orderedTasks(tasks).map(\.title), ["Today", "Later", "Done"])
    }

    func testFocusStreakIncludesConsecutiveDays() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now)!
        let sessions = [now, yesterday, twoDaysAgo].map {
            FocusSession(startedAt: $0, durationMinutes: 25, completed: true)
        }

        XCTAssertEqual(DaymarkLogic.streakDays(sessions: sessions, now: now, calendar: calendar), 3)
    }

    func testLegacyTaskDecodesWithoutReminder() throws {
        let legacy = LegacyTask(
            id: UUID(),
            title: "Existing task",
            note: "",
            bucket: .today,
            isComplete: false,
            createdAt: .now,
            completedAt: nil
        )
        let data = try JSONEncoder().encode(legacy)
        let task = try JSONDecoder().decode(FocusTask.self, from: data)

        XCTAssertEqual(task.title, "Existing task")
        XCTAssertNil(task.reminderAt)
    }

    func testLegacySessionDecodesWithoutContext() throws {
        let legacy = LegacySession(id: UUID(), startedAt: .now, durationMinutes: 25, completed: true)
        let data = try JSONEncoder().encode(legacy)
        let session = try JSONDecoder().decode(FocusSession.self, from: data)

        XCTAssertEqual(session.durationMinutes, 25)
        XCTAssertNil(session.taskTitle)
        XCTAssertEqual(session.note, "")
    }

    func testSmartCaptureFindsBucketAndProject() {
        let project = ProjectSnapshot(
            name: "mathfolio",
            path: "/Projects/mathfolio",
            branch: "main",
            isDirty: false,
            lastModified: .now,
            kind: "Web"
        )

        let result = DaymarkLogic.smartCapture("Polish homepage later @mathfolio", projects: [project])

        XCTAssertEqual(result.title, "Polish homepage")
        XCTAssertEqual(result.bucket, .later)
        XCTAssertEqual(result.projectName, "mathfolio")
        XCTAssertEqual(result.projectPath, "/Projects/mathfolio")
    }

    func testPlayAppsLockOnlyDuringFocus() {
        XCTAssertTrue(DaymarkLogic.isAppLocked(category: .play, focusEndsAt: .now.addingTimeInterval(60), timerPhase: .focus))
        XCTAssertFalse(DaymarkLogic.isAppLocked(category: .play, focusEndsAt: .now.addingTimeInterval(60), timerPhase: .breakTime))
        XCTAssertFalse(DaymarkLogic.isAppLocked(category: .productivity, focusEndsAt: .now.addingTimeInterval(60), timerPhase: .focus))
        XCTAssertFalse(DaymarkLogic.isAppLocked(category: .play, focusEndsAt: nil, timerPhase: .focus))
    }
}
