import SwiftUI

struct ReflectionView: View {
    let model: AppModel
    @State private var reflection = ""
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(eyebrow: "Close the loop", title: "Evening reflection", subtitle: "A minute of noticing makes tomorrow lighter.")

                HStack(alignment: .top, spacing: 18) {
                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("What moved forward? What can you release?")
                                .font(.title3.bold())
                            TextEditor(text: $reflection)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .padding(10)
                                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                                .frame(minHeight: 220)
                            HStack {
                                if saved {
                                    Label("Saved", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(DaymarkTheme.mint)
                                }
                                Spacer()
                                Button("Save reflection") {
                                    model.updateTodayEntry { $0.reflection = reflection }
                                    saved = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(DaymarkTheme.indigo)
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("TODAY IN NUMBERS", systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(DaymarkTheme.amber)
                            ReflectionStat(value: "\(model.completedTodayCount)", label: "tasks finished")
                            ReflectionStat(value: "\(model.focusMinutesToday)", label: "minutes protected")
                            ReflectionStat(value: "\(model.todayEntry.energy)/5", label: "energy")
                            Divider()
                            Text(model.todayEntry.intention.isEmpty ? "Set an intention tomorrow morning." : "Intention: \(model.todayEntry.intention)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 290)
                }
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Reflect")
        .onAppear { reflection = model.todayEntry.reflection }
        .onChange(of: reflection) { _, _ in saved = false }
    }
}

private struct ReflectionStat: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }
}
