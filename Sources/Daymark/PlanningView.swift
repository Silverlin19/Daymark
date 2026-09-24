import SwiftUI

struct MorningPlanSheet: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var selected = Set<UUID>()

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionHeading(
                eyebrow: "Morning reset",
                title: "What deserves today?",
                subtitle: "Carry tasks forward deliberately. Everything else can wait without guilt."
            )

            if model.planningCandidates.isEmpty {
                ContentUnavailableView("You’re already clear", systemImage: "sun.max.fill")
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                List(model.planningCandidates, selection: $selected) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                            HStack {
                                Text(task.bucket.rawValue)
                                if let project = task.projectName { Text("• \(project)") }
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: selected.contains(task.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected.contains(task.id) ? DaymarkTheme.mint : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(task.id) { selected.remove(task.id) }
                        else { selected.insert(task.id) }
                    }
                }
                .listStyle(.inset)
                .frame(minHeight: 280)
            }

            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Bring \(selected.count) into today") {
                    model.planForToday(taskIDs: selected)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(DaymarkTheme.coral)
                .disabled(selected.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(28)
        .frame(width: 580, height: 500)
    }
}
