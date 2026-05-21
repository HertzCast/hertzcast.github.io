import SwiftUI

@main
struct HertzCastApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView()
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
                .frame(width: 300)
        }
    }
}
