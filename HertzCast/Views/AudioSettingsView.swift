import SwiftUI
import AppKit

// MARK: - Shared button image

private func buttonNSImage() -> NSImage {
    if let url = Bundle.main.url(forResource: "Button", withExtension: "png"),
       let img = NSImage(contentsOf: url) { return img }
    return NSImage()
}

// MARK: - MetallicToggleButton

private struct MetallicToggleButton: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isPressed = false

    let size: CGFloat
    var fontSize: CGFloat? = nil

    var body: some View {
        ZStack {
            Image(nsImage: buttonNSImage())
                .resizable()
                .frame(width: size, height: size)

            Text(label.uppercased())
                .font(.system(size: fontSize ?? max(7, size * 0.145), weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .tracking(0.4)
                .foregroundColor(isActive ? settings.schemeColor : .white)
                .shadow(color: isActive ? settings.schemeMid.opacity(0.9) : .clear, radius: 5)
                .frame(width: size - 8)
                .animation(.easeInOut(duration: 0.15), value: isActive)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.91 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            onTap()
        }
    }
}

// MARK: - MetallicSlider

private struct MetallicSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let onRelease: () -> Void
    var onLiveChange: ((Double) -> Void)? = nil

    @State private var isDragging = false
    @State private var lastSentInt: Int? = nil
    private let thumbSize: CGFloat = 20
    private let trackH: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let usable = max(1, geo.size.width - thumbSize)
            let pct = max(0, min(1, (value - range.lowerBound) / (range.upperBound - range.lowerBound)))
            let thumbX = pct * usable

            ZStack(alignment: .leading) {
                // Continuous full-width track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.25))
                    .frame(height: trackH)
                    .padding(.horizontal, thumbSize / 2)

                // Thumb on top
                Image(nsImage: buttonNSImage())
                    .resizable()
                    .frame(width: thumbSize, height: thumbSize)
                    .offset(x: thumbX)
                    .scaleEffect(isDragging ? 0.88 : 1.0)
                    .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isDragging)
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        isDragging = true
                        let pct = max(0, min(1, (g.location.x - thumbSize / 2) / usable))
                        let newVal = (range.lowerBound + pct * (range.upperBound - range.lowerBound)).rounded()
                        value = newVal
                        let intVal = Int(newVal)
                        if intVal != lastSentInt {
                            lastSentInt = intVal
                            onLiveChange?(newVal)
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        lastSentInt = nil
                        onRelease()
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    value = 0
                    onRelease()
                }
            )
        }
        .frame(height: thumbSize)
    }
}

// MARK: - AudioSettingsView

struct AudioSettingsView: View {
    @ObservedObject private var api = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    @State private var subwooferVol: Double = 0
    @State private var bass: Double = 0
    @State private var treble: Double = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Sliders ───────────────────────────────────────────────
                audioSliderRow("SUBWOOFER", value: $subwooferVol, range: -12...12,
                    onLiveChange: { api.setSubwooferVolume(Int($0)) }) {
                    api.setSubwooferVolume(Int(subwooferVol))
                }
                audioSliderRow("BASS", value: $bass, range: -12...12,
                    onLiveChange: { api.setToneControl(bass: Int($0), treble: Int(treble)) }) {
                    api.setToneControl(bass: Int(bass), treble: Int(treble))
                }
                audioSliderRow("TREBLE", value: $treble, range: -12...12,
                    onLiveChange: { api.setToneControl(bass: Int(bass), treble: Int($0)) }) {
                    api.setToneControl(bass: Int(bass), treble: Int(treble))
                }

                // ── Dialogue Level ────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Text("DIALOGUE LEVEL")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)

                    HStack(spacing: 10) {
                        ForEach(0...3, id: \.self) { level in
                            MetallicToggleButton(
                                label: "\(level)",
                                isActive: api.dialogueLevel == level,
                                onTap: { api.setDialogueLevel(level) },
                                size: 28,
                                fontSize: 9
                            )
                        }
                        Spacer()
                    }
                }

                Divider().padding(.vertical, 2)

                // ── Audio Features (4 buttons in one row) ─────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text("AUDIO FEATURES")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)

                    GeometryReader { geo in
                        let spacing: CGFloat = 6
                        let btnSize = (geo.size.width - spacing * 3) / 4
                        HStack(spacing: spacing) {
                            MetallicToggleButton(label: "Pure\nDirect", isActive: api.pureDirectMode,
                                onTap: { api.setPureDirect(!api.pureDirectMode) }, size: btnSize)
                            MetallicToggleButton(label: "Enhancer", isActive: api.enhancerMode,
                                onTap: { api.setEnhancer(!api.enhancerMode) }, size: btnSize)
                            MetallicToggleButton(label: "Extra\nBass", isActive: api.extraBassMode,
                                onTap: { api.setExtraBass(!api.extraBassMode) }, size: btnSize)
                            MetallicToggleButton(label: "Adaptive\nDRC", isActive: api.adaptiveDRC,
                                onTap: { api.setAdaptiveDRC(!api.adaptiveDRC) }, size: btnSize)
                        }
                    }
                    .frame(height: (UIConstants.audioFeatureBtnSize))
                }

                Divider().padding(.vertical, 2)

                // ── Sound Program ─────────────────────────────────────────
                HStack {
                    Text("Sound Program")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { api.soundProgram },
                        set: { api.setSoundProgram($0) }
                    )) {
                        ForEach(api.soundProgramList, id: \.self) { prog in
                            Text(soundProgramLabel(prog)).tag(prog)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }

                // ── Surround Decoder ──────────────────────────────────────
                if api.soundProgram == "surr_decoder" {
                    HStack {
                        Text("Surround Decoder")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { api.surroundDecoderType },
                            set: { api.setSurroundDecoderType($0) }
                        )) {
                            ForEach(surroundDecoderTypes, id: \.value) { item in
                                Text(item.label).tag(item.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 160)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            subwooferVol = Double(api.subwooferVolume)
            bass         = Double(api.toneControlBass)
            treble       = Double(api.toneControlTreble)
            api.fetchSoundProgramList()
        }
        .onChange(of: api.subwooferVolume)   { subwooferVol = Double($0) }
        .onChange(of: api.toneControlBass)   { bass         = Double($0) }
        .onChange(of: api.toneControlTreble) { treble       = Double($0) }
    }

    @ViewBuilder
    private func audioSliderRow(_ label: String, value: Binding<Double>,
                                 range: ClosedRange<Double>,
                                 onLiveChange: ((Double) -> Void)? = nil,
                                 onRelease: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.5))
                    .tracking(1)
                Spacer()
                Text(value.wrappedValue >= 0 ? "+\(Int(value.wrappedValue))" : "\(Int(value.wrappedValue))")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(value.wrappedValue == 0 ? Color(white: 0.45) : settings.schemeColor)
                    .frame(width: 32, alignment: .trailing)
            }
            MetallicSlider(value: value, range: range, onRelease: onRelease, onLiveChange: onLiveChange)
        }
    }
}

private enum UIConstants {
    static let audioFeatureBtnSize: CGFloat = 58
}

private func soundProgramLabel(_ prog: String) -> String {
    let map: [String: String] = [
        "munich":           "Hall in Munich",
        "vienna":           "Hall in Vienna",
        "chamber":          "Chamber",
        "cellar_club":      "Cellar Club",
        "roxy_theatre":     "The Roxy Theatre",
        "bottom_line":      "The Bottom Line",
        "sports":           "Sports",
        "action_game":      "Action Game",
        "roleplaying_game": "Roleplaying Game",
        "music_video":      "Music Video",
        "standard":         "Standard",
        "spectacle":        "Spectacle",
        "sci-fi":           "Sci-Fi",
        "adventure":        "Adventure",
        "drama":            "Drama",
        "mono_movie":       "Mono Movie",
        "2ch_stereo":       "2ch Stereo",
        "all_ch_stereo":    "All Ch Stereo",
        "surr_decoder":     "Surround Decoder",
        "straight":         "Straight",
    ]
    return map[prog] ?? prog.replacingOccurrences(of: "_", with: " ").capitalized
}

private let surroundDecoderTypes: [(value: String, label: String)] = [
    ("dts_neo6_cinema",  "DTS Neo:6 Cinema"),
    ("dts_neo6_music",   "DTS Neo:6 Music"),
    ("dolby_pl2x_movie", "Dolby ProLogic IIx Movie"),
    ("dolby_pl2x_music", "Dolby ProLogic IIx Music"),
    ("dolby_pl2x_game",  "Dolby ProLogic IIx Game"),
]
