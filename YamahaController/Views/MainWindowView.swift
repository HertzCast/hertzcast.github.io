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

// Shared header height so all panels align
private let headerHeight: CGFloat = 44

struct MainWindowView: View {
    @ObservedObject private var uiState = AppUIState.shared

    var body: some View {
        HStack(spacing: 0) {
            // ── Music Center panel (left) ─────────────────────────────
            if uiState.showMusicCenter {
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
                .transition(.move(edge: .leading).combined(with: .opacity))

                Divider()
            }

            // ── Main panel ────────────────────────────────────────────
            VStack(spacing: 0) {
                // Header — buttons only; title lives in macOS title bar
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleMusicCenter() }
                    } label: {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 15))
                            .foregroundColor(uiState.showMusicCenter ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Music Center")

                    Spacer()

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
                    // Panel header aligned with main header
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

            // ── Audio settings panel ──────────────────────────────────
            if uiState.showAudio {
                Divider()
                VStack(spacing: 0) {
                    // Panel header aligned with main header
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
        }
        .animation(.easeInOut(duration: 0.25), value: uiState.showSettings || uiState.showAudio || uiState.showMusicCenter)
        .onChange(of: uiState.showMusicCenter) { showing in
            guard let window = NSApp.windows.first(where: { $0.canBecomeMain }) else { return }
            let delta: CGFloat = 301
            var frame = window.frame
            frame.origin.x += showing ? -delta : delta
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(frame, display: true)
            }
        }
        .background(WindowConfigurator())
    }
}
