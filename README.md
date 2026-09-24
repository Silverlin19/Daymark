# Daymark

Daymark is a private, local-first macOS dashboard for turning a busy project workspace into a deliberate day.

## What it does

- Captures and organizes tasks into Today, Next, and Later.
- Keeps one daily intention visible.
- Runs distraction-free focus sessions and tracks streaks.
- Offers a configurable Pomodoro cycle with work/break transition chimes.
- Schedules local macOS notifications for timer transitions and task reminders.
- Edits or deletes tasks, automatically cancelling reminders that no longer apply.
- Provides a menu-bar companion for timer controls, focus notes, and quick capture.
- Links tasks and focus sessions to workspace projects.
- Parses dates, buckets, and `@project` names from quick-capture text.
- Supports an intentional morning carry-forward ritual and a weekly focus review.
- Allows custom focus, Pomodoro work, break, and round lengths.
- Includes an app launcher with Productivity and Break & Play sections.
- Locks play-app shortcuts during focus and unlocks them automatically during Pomodoro breaks.
- Scans a chosen projects folder for activity, Git branch, and uncommitted work.
- Saves a lightweight evening reflection.
- Stores all personal data locally in `~/Library/Application Support/Daymark/state.json`.

## Run from source

Requires macOS 14 or newer and Xcode 16 or newer.

```sh
swift run
```

## Build and test

```sh
swift test
swift build -c release
./scripts/package-app.sh
```

The packaged application is written to `dist/Daymark.app`.
