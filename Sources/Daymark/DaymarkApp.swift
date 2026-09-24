import SwiftUI

@main
struct DaymarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup("Daymark", id: "main") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
            CommandMenu("Daymark") {
                Button("Quick Capture") {
                    model.presentedSheet = .newTask
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Refresh Projects") {
                    model.refreshProjects()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(model: model)
        }

        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(systemName: model.focusEndsAt == nil ? "sun.horizon.fill" : "timer")
                .accessibilityLabel("Daymark")
        }
        .menuBarExtraStyle(.window)
    }
}
