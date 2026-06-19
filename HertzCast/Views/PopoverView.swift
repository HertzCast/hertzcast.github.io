import SwiftUI

struct PopoverView: View {
    @ObservedObject private var api      = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    @State private var sliderVolume: Double = 0
    @State private var isDraggingVolume: Bool = false
    @State private var lastSentSliderVolume: Int = -1

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
                        fontName: popoverFontName,
                        fontSize: 13,
                        color: settings.schemeColor,
                        glow: settings.schemeGlow
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 16)

                    MarqueeText(
                        text: artistName.isEmpty ? " " : artistName,
                        fontName: popoverFontName,
                        fontSize: 12,
                        color: settings.isLight
                            ? Color(red: 0.72, green: 0.02, blue: 0.02)
                            : Color(red: 1.00, green: 0.75, blue: 0.10),
                        glow: settings.isLight
                            ? Color.clear
                            : Color(red: 1.00, green: 0.65, blue: 0.00).opacity(0.5)
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
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundColor(api.powerState.isOn ? .secondary : .secondary.opacity(0.35))
                    .frame(width: 14)

                VolumeSlider(
                    value: $sliderVolume,
                    range: 0...Double(max(api.maxVolume, 1)),
                    isDisabled: !api.powerState.isOn,
                    onEditingChanged: { editing in
                        isDraggingVolume = editing
                        if !editing { lastSentSliderVolume = -1 }
                    }
                )
                .onChange(of: sliderVolume) { newVal in
                    guard isDraggingVolume else { return }
                    let intVal = Int(newVal)
                    guard intVal != lastSentSliderVolume else { return }
                    lastSentSliderVolume = intVal
                    api.setVolume(intVal) { _ in }
                }
                .onChange(of: api.volume) { newVal in
                    if !isDraggingVolume { sliderVolume = Double(newVal) }
                }
                .onAppear { sliderVolume = Double(api.volume) }

                Text(volumeLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(api.isMuted ? Color(red: 1.0, green: 0.35, blue: 0.2) : .primary)
                    .frame(minWidth: 42, alignment: .center)

                TransportButton(label: "", systemImage: api.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                width: btnW, isActive: api.isMuted,
                                isDisabled: !api.powerState.isOn) { api.toggleMute() }
                TransportButton(label: "QUIT", width: btnW, isDisabled: false) {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .frame(width: 280)
        .background(settings.appBackground)
        .preferredColorScheme(settings.isLight ? .light : .dark)
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
        return String(format: "%.1f", Double(api.volume) * 0.5)
    }

    private var popoverFontName: String {
        settings.isLight ? "BitcountPropSingle-Regular" : "BitcountPropSingle-ExtraLight"
    }

    private var artPlaceholder: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(settings.appSurface)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(settings.appTextDim)
            )
    }
}

private extension PowerState {
    var isOn: Bool { self == .on }
}

private struct VolumeSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let isDisabled: Bool
    let onEditingChanged: (Bool) -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isDragging = false
    @State private var thumbImg: NSImage? = nil

    private let thumbSize: CGFloat = 18
    private let trackHeight: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let trackWidth = geo.size.width - thumbSize
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let thumbX = thumbSize / 2 + fraction * trackWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: trackHeight)

                Capsule()
                    .fill(settings.schemeColor.opacity(isDisabled ? 0.3 : 0.85))
                    .frame(width: max(thumbX, 0), height: trackHeight)

                Group {
                    if let img = thumbImg {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Circle().fill(Color.white).shadow(radius: 1)
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .offset(x: thumbX - thumbSize / 2)
                .opacity(isDisabled ? 0.4 : 1)
            }
            .frame(height: thumbSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        if !isDragging { isDragging = true; onEditingChanged(true) }
                        let f = (drag.location.x - thumbSize / 2) / max(trackWidth, 1)
                        value = (range.lowerBound + max(0, min(1, f)) * (range.upperBound - range.lowerBound)).rounded()
                    }
                    .onEnded { _ in isDragging = false; onEditingChanged(false) }
            )
            .disabled(isDisabled)
        }
        .frame(height: thumbSize)
        .onAppear { loadThumb() }
        .onChange(of: settings.isLight) { _ in loadThumb() }
    }

    private func loadThumb() {
        let name = settings.isLight ? "Button White" : "Button"
        if let path = Bundle.main.path(forResource: name, ofType: "png") {
            thumbImg = NSImage(contentsOfFile: path)
        }
    }
}
