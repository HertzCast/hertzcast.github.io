import SwiftUI

@main
struct HertzCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .windowSize) { }
            CommandGroup(replacing: .windowArrangement) { }
            CommandGroup(replacing: .windowList) { }
            CommandGroup(replacing: .help) { }
        }

        Settings {
            SettingsView()
                .frame(width: 300)
        }
    }
}
