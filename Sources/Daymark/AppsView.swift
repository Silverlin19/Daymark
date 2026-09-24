import AppKit
import SwiftUI

struct AppsView: View {
    @Bindable var model: AppModel
    private let columns = [GridItem(.adaptive(minimum: 175, maximum: 230), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                HStack(alignment: .bottom) {
                    SectionHeading(
                        eyebrow: "Intentional access",
                        title: "Apps",
                        subtitle: "Work when it’s time to work. Play when it’s time to reset."
                    )
                    Spacer()
                    timerStatus
                }

                appSection(
                    category: .productivity,
                    description: "Always available for making and moving work forward."
                )

                Divider()

                appSection(
                    category: .play,
                    description: "Available outside focus sessions and automatically unlocked during Pomodoro breaks."
                )
            }
            .padding(30)
            .frame(maxWidth: 1100, alignment: .leading)
        }
        .navigationTitle("Apps")
    }

    @ViewBuilder
    private var timerStatus: some View {
        if model.playAppsLocked, let end = model.focusEndsAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(end.timeIntervalSince(context.date)))
                Label("Play locked • \(remaining / 60):\(String(format: "%02d", remaining % 60))", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DaymarkTheme.coral)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(DaymarkTheme.coral.opacity(0.1), in: Capsule())
            }
        } else if model.focusEndsAt != nil, model.timerPhase == .breakTime {
            Label("Break active • Play unlocked", systemImage: "lock.open.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DaymarkTheme.mint)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(DaymarkTheme.mint.opacity(0.1), in: Capsule())
        } else {
            Label("All apps available", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func appSection(category: AppCategory, description: String) -> some View {
        let apps = model.appLinks.filter { $0.category == category }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Label(category.rawValue, systemImage: category.symbol)
                    .font(.title2.bold())
                    .foregroundStyle(category == .productivity ? DaymarkTheme.indigo : DaymarkTheme.amber)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    model.chooseApplication(for: category)
                } label: {
                    Label("Add app", systemImage: "plus")
                }
            }

            if apps.isEmpty {
                ContentUnavailableView(
                    "No apps yet",
                    systemImage: category.symbol,
                    description: Text("Add an installed app to this section.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(apps) { app in
                        AppLauncherCard(
                            app: app,
                            isLocked: DaymarkLogic.isAppLocked(
                                category: app.category,
                                focusEndsAt: model.focusEndsAt,
                                timerPhase: model.timerPhase
                            ),
                            launch: { model.launch(app) },
                            remove: { model.removeAppLink(app) }
                        )
                    }
                }
            }
        }
    }
}

private struct AppLauncherCard: View {
    let app: DaymarkAppLink
    let isLocked: Bool
    let launch: () -> Void
    let remove: () -> Void

    private var icon: NSImage {
        NSWorkspace.shared.icon(forFile: app.path)
    }

    var body: some View {
        Button(action: launch) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 52, height: 52)
                        .saturation(isLocked ? 0 : 1)
                        .opacity(isLocked ? 0.45 : 1)
                    Spacer()
                    Image(systemName: isLocked ? "lock.fill" : "arrow.up.forward.app.fill")
                        .foregroundStyle(isLocked ? DaymarkTheme.coral : .secondary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(isLocked ? "Available on your break" : "Open app")
                        .font(.caption)
                        .foregroundStyle(isLocked ? DaymarkTheme.coral : .secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isLocked ? DaymarkTheme.coral.opacity(0.2) : .primary.opacity(0.07))
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .contextMenu {
            Button("Remove from Daymark", systemImage: "minus.circle", role: .destructive, action: remove)
        }
        .help(isLocked ? "Play apps unlock when the focus phase ends" : "Open \(app.name)")
    }
}
