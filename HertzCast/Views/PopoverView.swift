import SwiftUI

struct PopoverView: View {
    @ObservedObject private var api      = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    private let btnW: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {

            // ── Artwork + Now Playing ─────────────────────────────────
            HStack(spacing: 10) {
                Group {
                    if let artURL = URL(string: api.albumArtURLString), !api.albumArtURLString.isEmpty {
                        AsyncImage(url: artURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                artPlaceholder
                            }
                        }
                    } else {
                        artPlaceholder
                    }
                }
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .stroke(settings.schemeColor.opacity(api.albumArtURLString.isEmpty ? 0 : 0.6), lineWidth: 1.5))

                VStack(alignment: .leading, spacing: 5) {
                    MarqueeText(
                        text: trackTitle,
                        fontName: "BitcountPropSingle-ExtraLight",
                        fontSize: 13,
                        color: settings.schemeColor,
                        glow: settings.schemeGlow
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 16)

                    MarqueeText(
                        text: artistName.isEmpty ? " " : artistName,
                        fontName: "BitcountPropSingle-ExtraLight",
                        fontSize: 12,
                        color: Color(red: 1.00, green: 0.75, blue: 0.10),
                        glow: Color(red: 1.00, green: 0.65, blue: 0.00).opacity(0.5)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 15)
                    .opacity(artistName.isEmpty ? 0 : 1)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 8)

            Divider()

            // ── Playback buttons ──────────────────────────────────────
            HStack(spacing: 6) {
                Spacer()
                TransportButton(label: "", systemImage: "backward.end.fill", width: btnW,
                                isDisabled: !api.powerState.isOn) { api.setPlayback("previous") }
                TransportButton(label: "", systemImage: "stop.fill", width: btnW,
                                isDisabled: !api.powerState.isOn) { api.setPlayback("stop") }
                TransportButton(label: "",
                                systemImage: api.playbackStatus == "play" ? "pause.fill" : "play.fill",
                                width: btnW, isDisabled: !api.powerState.isOn) { api.togglePlayback() }
                TransportButton(label: "", systemImage: "forward.end.fill", width: btnW,
                                isDisabled: !api.powerState.isOn) { api.setPlayback("next") }
                TransportButton(label: "", systemImage: "shuffle", width: btnW,
                                isActive: api.shuffleMode != "off",
                                isDisabled: !api.powerState.isOn) { api.toggleShuffle() }
                TransportButton(label: "", systemImage: api.repeatMode == "one" ? "repeat.1" : "repeat",
                                width: btnW,
                                isActive: api.repeatMode != "off",
                                isDisabled: !api.powerState.isOn) { api.cycleRepeat() }
                Spacer()
            }
            .padding(.vertical, 10)

            Divider()

            // ── Volume + Mute + Quit ──────────────────────────────────
            HStack(spacing: 6) {
                Spacer()
                TransportButton(label: "−", width: btnW,
                                isDisabled: !api.powerState.isOn) { api.volumeDown() }
                Text(volumeLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(api.isMuted ? Color(red: 1.0, green: 0.35, blue: 0.2) : .primary)
                    .frame(minWidth: 64, alignment: .center)
                TransportButton(label: "+", width: btnW,
                                isDisabled: !api.powerState.isOn) { api.volumeUp() }
                TransportButton(label: "", systemImage: api.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                width: btnW, isActive: api.isMuted,
                                isDisabled: !api.powerState.isOn) { api.toggleMute() }
                TransportButton(label: "QUIT", width: btnW, isDisabled: false) {
                    NSApplication.shared.terminate(nil)
                }
                Spacer()
            }
            .padding(.vertical, 10)
        }
        .frame(width: 280)
    }

    private var trackTitle: String {
        guard api.powerState == .on else { return "STANDBY" }
        if !api.nowPlayingTrack.isEmpty { return api.nowPlayingTrack }
        if !api.currentInput.isEmpty { return HertzAPIService.formatInput(api.currentInput).uppercased() }
        return "– – –"
    }

    private var artistName: String {
        guard api.powerState == .on else { return "" }
        return api.nowPlayingArtist
    }

    private var volumeLabel: String {
        guard api.powerState == .on else { return "– – –" }
        if api.isMuted { return "MUTED" }
        if let db = api.actualVolumeDb { return String(format: "%.1f dB", db) }
        return "VOL \(api.volume)"
    }

    private var artPlaceholder: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(white: 0.12))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(Color(white: 0.35))
            )
    }
}

private extension PowerState {
    var isOn: Bool { self == .on }
}
