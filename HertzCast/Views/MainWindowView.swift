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

private struct HeaderButton: View {
    let icon: String
    let iconSize: CGFloat
    let isActive: Bool
    let help: String
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isPressed = false

    private let size: CGFloat = 32

    @State private var cachedButtonImage: NSImage = NSImage()

    private func loadButtonImage() {
        let name = settings.isLight ? "Button White" : "Button"
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) { cachedButtonImage = img }
    }

    var body: some View {
        ZStack {
            Image(nsImage: cachedButtonImage)
                .resizable()
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(isActive ? settings.schemeColor : settings.appText.opacity(0.7))
                .shadow(color: isActive && !settings.isLight ? settings.schemeMid.opacity(0.9) : .clear, radius: 4)
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.91 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .help(help)
        .onAppear { loadButtonImage() }
        .onChange(of: settings.isLight) { _ in loadButtonImage() }
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            onTap()
        }
    }
}

struct MainWindowView: View {
    @ObservedObject private var uiState = AppUIState.shared
    @ObservedObject private var settings = HertzSettings.shared
    @ObservedObject private var api = HertzAPIService.shared

    var body: some View {
        HStack(spacing: 0) {

            // ── Main panel ────────────────────────────────────────────
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 8) {
                    Spacer()
                    HeaderButton(icon: "rectangle.split.2x1", iconSize: 12, isActive: uiState.showZone2, help: "Zone 2") {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleZone2() }
                    }
                    HeaderButton(icon: "music.note.list", iconSize: 13, isActive: uiState.showMusicCenter, help: "Music Center") {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleMusicCenter() }
                    }
                    HeaderButton(icon: "slider.horizontal.3", iconSize: 13, isActive: uiState.showAudio, help: "Audio Settings") {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleAudio() }
                    }
                    HeaderButton(icon: "gearshape", iconSize: 14, isActive: uiState.showSettings, help: "Settings") {
                        withAnimation(.easeInOut(duration: 0.25)) { uiState.toggleSettings() }
                    }
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
                        PowerButtonView(
                            isOn: api.zone2Power == .on,
                            isDisabled: false,
                            isBusy: false,
                            onTap: { api.setZone2Power(api.zone2Power != .on) }
                        )
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
        .background(settings.appBackground.ignoresSafeArea())
        .background(WindowConfigurator())
        .preferredColorScheme(settings.isLight ? .light : .dark)
    }
}
