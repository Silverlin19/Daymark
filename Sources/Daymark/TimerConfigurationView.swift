import SwiftUI

struct PomodoroConfigurationView: View {
    @Bindable var model: AppModel
    var showHeading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showHeading {
                Text("POMODORO SETUP")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }
            TimerValueRow(
                title: "Focus",
                value: $model.pomodoroFocusLength,
                range: 1...240,
                suffix: "min"
            )
            TimerValueRow(
                title: "Break",
                value: $model.pomodoroBreakLength,
                range: 1...120,
                suffix: "min"
            )
            TimerValueRow(
                title: "Rounds",
                value: $model.pomodoroRounds,
                range: 1...12,
                suffix: model.pomodoroRounds == 1 ? "round" : "rounds"
            )
        }
        .onChange(of: model.pomodoroFocusLength) { _, _ in model.save() }
        .onChange(of: model.pomodoroBreakLength) { _, _ in model.save() }
        .onChange(of: model.pomodoroRounds) { _, _ in model.save() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Pomodoro configuration")
    }
}

private struct TimerValueRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let suffix: String

    var body: some View {
        HStack(spacing: 7) {
            Text(title)
                .font(.callout)
            Spacer()
            Button {
                value = max(range.lowerBound, value - 1)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(value <= range.lowerBound)
            .accessibilityLabel("Decrease \(title.lowercased())")

            TextField(title, value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 46)
                .onSubmit { value = min(max(value, range.lowerBound), range.upperBound) }

            Text(suffix)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .leading)

            Button {
                value = min(range.upperBound, value + 1)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(value >= range.upperBound)
            .accessibilityLabel("Increase \(title.lowercased())")
        }
    }
}
