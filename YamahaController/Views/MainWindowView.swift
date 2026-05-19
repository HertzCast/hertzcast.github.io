import SwiftUI
import AppKit

private struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { configure(v.window) }
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { configure(nsView.window) }
    }
    private func configure(_ win: NSWindow?) {
        win?.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

private let headerHeight: CGFloat = 44

struct MainWindowView: View {
    @ObservedObject private var uiState = AppUIState.shared

    var body: some View {
        HStack(spacing: 0) {

            // ── Main panel ────────────────────────────────────────────
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleZone2() }
                    } label: {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 14))
                            .foregroundColor(uiState.showZone2 ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Zone 2")

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleMusicCenter() }
                    } label: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 15))
                            .foregroundColor(uiState.showMusicCenter ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Music Center")

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleAudio() }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15))
                            .foregroundColor(uiState.showAudio ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Audio Settings")

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleSettings() }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(uiState.showSettings ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Settings")
                }
                .padding(.horizontal)
                .frame(height: headerHeight)

                Divider()

                ReceiverDisplayView()
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 6)

                Divider()

                ManualControlsView()
                    .padding()

                Divider()

                SceneButtonsView()
                    .padding()

                Divider()

                TransportControlsView()
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .frame(width: 300)

            // ── Settings panel ────────────────────────────────────────
            if uiState.showSettings {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text("Settings")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(height: headerHeight)

                    Divider()

                    SettingsView()
                }
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // ── Audio Settings panel ──────────────────────────────────
            if uiState.showAudio {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text("Audio Settings")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(height: headerHeight)

                    Divider()

                    AudioSettingsView()
                }
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // ── Zone 2 panel ──────────────────────────────────────────
            if uiState.showZone2 {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text("Zone 2")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(height: headerHeight)

                    Divider()

                    Zone2View()
                }
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // ── Music Center panel ────────────────────────────────────
            if uiState.showMusicCenter {
                Divider()
                VStack(spacing: 0) {
                    HStack {
                        Text("Music Center")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(height: headerHeight)

                    Divider()

                    MusicCenterView()
                }
                .frame(width: 300)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.showSettings || uiState.showAudio || uiState.showMusicCenter || uiState.showZone2)
        .background(WindowConfigurator())
    }
}
