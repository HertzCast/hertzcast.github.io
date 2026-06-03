import SwiftUI
import AppKit

struct MarqueeText: NSViewRepresentable {
    let text: String
    let fontName: String
    let fontSize: CGFloat
    let color: Color
    let glow: Color

    func makeNSView(context: Context) -> MarqueeNSView { MarqueeNSView() }

    func updateNSView(_ nsView: MarqueeNSView, context: Context) {
        nsView.configure(text: text,
                         fontName: fontName,
                         fontSize: fontSize,
                         color: NSColor(color),
                         glow: NSColor(glow))
    }
}

final class MarqueeNSView: NSView {
    private let contentLayer = CALayer()
    private let textLayer1 = CATextLayer()
    private let textLayer2 = CATextLayer()
    private var currentText: String = ""
    private var currentFontName: String = ""
    private var currentFontSize: CGFloat = 0
    private var lastBoundsWidth: CGFloat = 0
    private let speed: CGFloat = 42
    private let gap: CGFloat = 70

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        for tl in [textLayer1, textLayer2] {
            tl.contentsScale = scale
            tl.truncationMode = .none
            tl.isWrapped = false
            tl.alignmentMode = .left
            tl.anchorPoint = CGPoint(x: 0, y: 0.5)
            tl.shadowOpacity = 1.0
            tl.shadowRadius = 6
            tl.shadowOffset = .zero
            contentLayer.addSublayer(tl)
        }
        contentLayer.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(contentLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        if bounds.width != lastBoundsWidth {
            lastBoundsWidth = bounds.width
            rebuildAnimation()
        }
    }

    func configure(text: String, fontName: String, fontSize: CGFloat,
                   color: NSColor, glow: NSColor) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for tl in [textLayer1, textLayer2] {
            tl.foregroundColor = color.cgColor
            tl.shadowColor = glow.cgColor
        }
        CATransaction.commit()

        let textChanged = text != currentText ||
                          fontName != currentFontName ||
                          fontSize != currentFontSize
        if textChanged {
            currentText = text
            currentFontName = fontName
            currentFontSize = fontSize
            let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for tl in [textLayer1, textLayer2] {
                tl.font = font
                tl.fontSize = fontSize
                tl.string = text
            }
            CATransaction.commit()
            rebuildAnimation()
        }
    }

    private func rebuildAnimation() {
        guard !currentText.isEmpty, bounds.width > 0 else { return }
        let font = NSFont(name: currentFontName, size: currentFontSize) ?? NSFont.systemFont(ofSize: currentFontSize)
        let textSize = (currentText as NSString).size(withAttributes: [.font: font])
        let containerWidth = bounds.width
        let yCenter = bounds.height / 2

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        contentLayer.removeAllAnimations()

        if textSize.width <= containerWidth {
            textLayer1.frame = CGRect(x: 0, y: 0, width: textSize.width, height: textSize.height)
            textLayer1.position = CGPoint(x: 0, y: textSize.height / 2)
            textLayer2.isHidden = true
            contentLayer.frame = CGRect(x: 0, y: yCenter - textSize.height / 2,
                                        width: textSize.width, height: textSize.height)
            contentLayer.position = CGPoint(x: 0, y: yCenter)
            CATransaction.commit()
            return
        }

        textLayer2.isHidden = false
        let cycle = textSize.width + gap
        textLayer1.frame = CGRect(x: 0, y: 0, width: textSize.width, height: textSize.height)
        textLayer1.position = CGPoint(x: 0, y: textSize.height / 2)
        textLayer2.frame = CGRect(x: 0, y: 0, width: textSize.width, height: textSize.height)
        textLayer2.position = CGPoint(x: cycle, y: textSize.height / 2)

        contentLayer.frame = CGRect(x: 0, y: 0, width: cycle * 2, height: textSize.height)
        contentLayer.position = CGPoint(x: 0, y: yCenter)

        let anim = CABasicAnimation(keyPath: "position.x")
        anim.fromValue = 0
        anim.toValue = -cycle
        anim.duration = CFTimeInterval(cycle / speed)
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.isRemovedOnCompletion = false
        contentLayer.add(anim, forKey: "marquee")
        CATransaction.commit()
    }
}

struct ReceiverDisplayView: View {
    @ObservedObject private var api = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared
    @State private var showReplaceAlert = false

    private var inputLabel: String {
        api.powerState == .on && !api.currentInput.isEmpty
            ? HertzAPIService.formatInput(api.currentInput).uppercased()
            : "– – –"
    }

    private var volumeLabel: String {
        guard api.powerState == .on else { return "– – –" }
        if api.isMuted { return "MUTE" }
        return String(format: "%.1f", Double(api.volume) * 0.5)
    }

    private var soundLabel: String {
        guard api.powerState == .on, !api.soundProgram.isEmpty else { return "– – –" }
        return api.soundProgram.replacingOccurrences(of: "_", with: " ").uppercased()
    }

    private var decoderLabel: String {
        guard isOn, api.soundProgram == "surr_decoder", !api.surroundDecoderType.isEmpty else { return "" }
        let map: [String: String] = [
            "dolby_pl2x_music":  "DPL MUSIC",
            "dolby_pl2x_movie":  "DPL MOVIE",
            "dolby_pl2x_game":   "DPL GAME",
            "dts_neo6_cinema":   "NEO:6 CIN",
            "dts_neo6_music":    "NEO:6 MUS",
        ]
        return map[api.surroundDecoderType] ?? api.surroundDecoderType.replacingOccurrences(of: "_", with: " ").uppercased()
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
        ZStack(alignment: .top) {
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

                // ── Row 1: INPUT label ───────────────────────────────────
                Text("INPUT")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundColor(lcdDim).tracking(1.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 8)

                // ── Row 2: Input name (big) ──────────────────────────────
                Text(inputLabel)
                    .font(.custom("BitcountPropSingle-ExtraLight", size: 22))
                    .foregroundColor(isOn ? lcdAmber : lcdDim)
                    .shadow(color: isOn ? lcdAmberGlow : .clear, radius: 4)
                    .tracking(2).lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.top, 4)

                // ── Row 3: Now Playing (always reserved, opacity-gated) ──
                Divider()
                    .background(Color(white: 0.12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)

                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 1) {
                        MarqueeText(
                            text: api.nowPlayingTrack.isEmpty ? " " : api.nowPlayingTrack,
                            fontName: "BitcountPropSingle-ExtraLight",
                            fontSize: 14,
                            color: lcdGreen,
                            glow: lcdGlow
                        )
                        .frame(height: 18)
                        .opacity(hasNowPlaying && !api.nowPlayingTrack.isEmpty ? 1 : 0)

                        MarqueeText(
                            text: api.nowPlayingArtist.isEmpty ? " " : api.nowPlayingArtist,
                            fontName: "BitcountPropSingle-ExtraLight",
                            fontSize: 14,
                            color: lcdAmber,
                            glow: lcdAmberGlow
                        )
                        .frame(height: 18)
                        .opacity(hasNowPlaying && !api.nowPlayingArtist.isEmpty ? 1 : 0)

                        if hasNowPlaying && api.currentInput.lowercased() == "net_radio" {
                            Button { handleFavouriteTap() } label: {
                                Image(systemName: api.currentPresetSlot != nil ? "heart.fill" : "heart")
                                    .font(.system(size: 12))
                                    .foregroundColor(api.currentPresetSlot != nil ? lcdGreen : Color(white: 0.5))
                                    .shadow(color: api.currentPresetSlot != nil ? lcdGlow : .clear, radius: 4)
                            }
                            .buttonStyle(.plain)
                            .frame(height: 14)
                        }
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
                                ? (api.isMuted ? Color(red: 1.0, green: 0.35, blue: 0.2) : lcdAmber)
                                : lcdDim)
                            .shadow(color: isOn && !api.isMuted ? lcdAmberGlow : .clear, radius: 3)
                            .tracking(1)
                    }

                    Spacer()

                    HStack(spacing: 5) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(lcdGreen)
                            .shadow(color: lcdGlow, radius: 7)
                            .opacity(isOn && api.shuffleMode != "off" ? 1 : 0)
                        Image(systemName: api.repeatMode == "one" ? "repeat.1" : "repeat")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(lcdGreen)
                            .shadow(color: lcdGlow, radius: 7)
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
                        if !decoderLabel.isEmpty {
                            Text(decoderLabel)
                                .font(.custom("BitcountPropSingle-ExtraLight", size: 9))
                                .foregroundColor(lcdAmber.opacity(0.7))
                                .shadow(color: lcdAmberGlow, radius: 2)
                                .tracking(0.5).lineLimit(1)
                        }
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
        .alert("All presets are used", isPresented: $showReplaceAlert) {
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Right-click a Favourite in Music Center to remove it, then save \"\(api.nowPlayingStationName)\".")
        }
    }

    private func handleFavouriteTap() {
        if let slot = api.currentPresetSlot {
            api.clearPreset(slot)
        } else if let freeSlot = api.firstFreePresetSlot {
            api.storePreset(freeSlot)
        } else {
            showReplaceAlert = true
        }
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
