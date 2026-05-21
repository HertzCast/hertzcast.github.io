import Foundation

class AppUIState: ObservableObject {
    static let shared = AppUIState()
    @Published var showSettings = false
    @Published var showAudio = false
    @Published var showMusicCenter = false
    @Published var showZone2 = false
    private init() {}

    private func closeAll() {
        showSettings = false
        showAudio = false
        showMusicCenter = false
        showZone2 = false
    }

    func toggleSettings()    { let v = showSettings;    closeAll(); showSettings    = !v }
    func toggleAudio()       { let v = showAudio;       closeAll(); showAudio       = !v }
    func toggleMusicCenter() { let v = showMusicCenter; closeAll(); showMusicCenter = !v }
    func toggleZone2()       { let v = showZone2;       closeAll(); showZone2       = !v }
}
