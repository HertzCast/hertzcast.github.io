import SwiftUI

private struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let glow: Color

    @State private var xOffset: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundColor(color)
                .shadow(color: glow, radius: 3)
                .fixedSize()
                .offset(x: xOffset)
                .background(
                    GeometryReader { textGeo in
                        Color.clear.onAppear {
                            let textW = textGeo.size.width
                            let containerW = geo.size.width
                            guard textW > containerW else { return }
                            // Start off-screen to the right, scroll left, exit left with gap, repeat
                            xOffset = containerW
                            let gap: CGFloat = 28
                            let totalDist = containerW + textW + gap
                            let dur = Double(totalDist) / 42.0
                            DispatchQueue.main.async {
                                withAnimation(.linear(duration: dur).repeatForever(autoreverses: false)) {
                                    xOffset = -(textW + gap)
                                }
                            }
                        }
                    }
                )
        }
        .clipped()
        .id(text)
    }
}

struct ReceiverDisplayView: View {
    @ObservedObject private var api = YamahaAPIService.shared
    @ObservedObject private var settings = YamahaSettings.shared

    private var inputLabel: String {
        api.powerState == .on && !api.currentInput.isEmpty
            ? YamahaAPIService.formatInput(api.currentInput).uppercased()
            : "– – –"
    }

    private var volumeLabel: String {
        guard api.powerState == .on else { return "– – –" }
        if api.isMuted { return "MUTE" }
        if let db = api.actualVolumeDb { return String(format: "%.1f dB", db) }
        return "VOL \(api.volume)"
    }

    private var soundLabel: String {
        guard api.powerState == .on, !api.soundProgram.isEmpty else { return "– – –" }
        return api.soundProgram.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    // Whether current input has now-playing info
    private var signalLabel: String {
        guard isOn, !api.audioFormat.isEmpty else { return "" }
        var parts: [String] = [api.audioFormat.uppercased()]
        if api.audioBitrate > 0 { parts.append("\(api.audioBitrate) KBPS") }
        if !api.audioBitDepth.isEmpty { parts.append(api.audioBitDepth.uppercased()) }
        if !api.audioChannels.isEmpty { parts.append(api.audioChannels.uppercased()) }
        return parts.joined(separator: " · ")
    }

    private var hasNowPlaying: Bool {
        let input = api.currentInput.lowercased()
        return api.powerState == .on &&
               (input == "net_radio" || input == "spotify") &&
               (!api.nowPlayingTrack.isEmpty || !api.nowPlayingArtist.isEmpty)
    }

    private var hasAlbumArt: Bool { hasNowPlaying && !api.albumArtURLString.isEmpty }

    private var isOn: Bool { api.powerState == .on }

    var body: some View {
        ZStack {
            // Panel background
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.04, green: 0.06, blue: 0.05))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(white: 0.15), lineWidth: 1))

            // Scanlines
            GeometryReader { _ in
                Canvas { context, size in
                    var y: CGFloat = 0
                    while y < size.height {
                        context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                                     with: .color(Color.black.opacity(0.12)))
                        y += 3
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {

                // ── Row 0: Signal format (always present, opacity-gated) ─
                Text(signalLabel.isEmpty ? " " : signalLabel)
                    .font(.custom("BitcountPropSingle-ExtraLight", size: 9))
                    .foregroundColor(lcdAmber)
                    .shadow(color: lcdAmberGlow, radius: 2)
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 10)
                    .padding(.top, 6)
                    .padding(.bottom, 2)
                    .opacity(signalLabel.isEmpty ? 0 : 1)

                // ── Row 1: INPUT label + status dots ────────────────────
                HStack {
                    Text("INPUT")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .foregroundColor(lcdDim).tracking(1.5)
                    Spacer()
                    Text("MUTE")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 1.0, green: 0.35, blue: 0.2))
                        .tracking(1)
                        .opacity(isOn && api.isMuted ? 1 : 0)
                }
                .padding(.horizontal, 10)
                .padding(.top, 8)

                // ── Row 2: Input name (big) ──────────────────────────────
                Text(inputLabel)
                    .font(.custom("BitcountPropSingle-ExtraLight", size: 22))
                    .foregroundColor(isOn ? lcdGreen : lcdDim)
                    .shadow(color: isOn ? lcdGlow : .clear, radius: 4)
                    .tracking(2).lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                // ── Row 3: Now Playing (always reserved, opacity-gated) ──
                Divider()
                    .background(Color(white: 0.12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        MarqueeText(
                            text: api.nowPlayingTrack.isEmpty ? " " : api.nowPlayingTrack,
                            font: .custom("BitcountPropSingle-ExtraLight", size: 14),
                            color: lcdGreen,
                            glow: lcdGlow
                        )
                        .frame(height: 18)
                        .opacity(hasNowPlaying && !api.nowPlayingTrack.isEmpty ? 1 : 0)

                        MarqueeText(
                            text: api.nowPlayingArtist.isEmpty ? " " : api.nowPlayingArtist,
                            font: .custom("BitcountPropSingle-ExtraLight", size: 14),
                            color: lcdAmber,
                            glow: lcdAmberGlow
                        )
                        .frame(height: 18)
                        .opacity(hasNowPlaying && !api.nowPlayingArtist.isEmpty ? 1 : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Group {
                        if let artURL = URL(string: api.albumArtURLString), !api.albumArtURLString.isEmpty {
                            AsyncImage(url: artURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color.clear
                                }
                            }
                        } else {
                            Color.clear
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(lcdGreen.opacity(hasAlbumArt ? 0.75 : 0), lineWidth: 1.5))
                    .opacity(hasAlbumArt ? 1 : 0)
                }
                .padding(.horizontal, 10)

                // ── Row 4: Volume + [shuffle/repeat] + Mode ─────────────
                Divider()
                    .background(Color(white: 0.12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VOLUME")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(lcdDim).tracking(1.5)
                        Text(volumeLabel)
                            .font(.custom("BitcountPropSingle-ExtraLight", size: 16))
                            .foregroundColor(isOn
                                ? (api.isMuted ? Color(red: 1.0, green: 0.35, blue: 0.2) : lcdGreen)
                                : lcdDim)
                            .shadow(color: isOn && !api.isMuted ? lcdGlow : .clear, radius: 3)
                            .tracking(1)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(lcdGreen)
                            .shadow(color: lcdGlow, radius: 4)
                            .opacity(isOn && api.shuffleMode != "off" ? 1 : 0)
                        Image(systemName: api.repeatMode == "one" ? "repeat.1" : "repeat")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(lcdGreen)
                            .shadow(color: lcdGlow, radius: 4)
                            .opacity(isOn && api.repeatMode != "off" ? 1 : 0)
                    }
                    .padding(.bottom, 2)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("MODE")
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundColor(lcdDim).tracking(1.5)
                        Text(soundLabel)
                            .font(.custom("BitcountPropSingle-ExtraLight", size: 11))
                            .foregroundColor(isOn ? lcdAmber : lcdDim)
                            .shadow(color: isOn ? lcdAmberGlow : .clear, radius: 3)
                            .tracking(0.8).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 168)
        .animation(.easeInOut(duration: 0.3), value: api.powerState)
        .animation(.easeInOut(duration: 0.2), value: api.currentInput)
    }

    private var placeholderArt: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(lcdDim.opacity(0.2))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 14))
                    .foregroundColor(lcdDim)
            )
    }

    private var lcdGreen:     Color { settings.schemeColor }
    private var lcdGlow:      Color { settings.schemeGlow }
    private var lcdAmber:     Color { Color(red: 1.00, green: 0.75, blue: 0.10) }
    private var lcdAmberGlow: Color { Color(red: 1.00, green: 0.65, blue: 0.00).opacity(0.5) }
    private var lcdDim:       Color { settings.schemeLcdDim }
}
