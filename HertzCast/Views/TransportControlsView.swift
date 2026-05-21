import SwiftUI

struct TransportButton: View {
    let label: String
    let systemImage: String?
    let width: CGFloat
    let isActive: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared

    init(label: String, systemImage: String? = nil, width: CGFloat = 54,
         isActive: Bool = false, isDisabled: Bool, onTap: @escaping () -> Void) {
        self.label = label
        self.systemImage = systemImage
        self.width = width
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.onTap = onTap
    }

    private let h: CGFloat = 15

    private var iconColor: Color {
        isActive ? settings.schemeColor : .white
    }

    var body: some View {
        Button(action: { if !isDisabled { onTap() } }) {
            ZStack(alignment: .bottom) {

                // Housing
                KeycapShape(cornerRadius: 3, cutSize: 4)
                    .fill(Color(white: 0.05))
                    .frame(width: width, height: h + 2)
                    .offset(y: 1)

                // Key face
                ZStack {
                    KeycapShape(cornerRadius: 3, cutSize: 4)
                        .fill(LinearGradient(
                            colors: [Color(white: 0.17), Color(white: 0.11)],
                            startPoint: .top, endPoint: .bottom
                        ))

                    KeycapShape(cornerRadius: 3, cutSize: 4)
                        .stroke(
                            LinearGradient(
                                colors: [Color(white: 0.30), Color(white: 0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )

                    LinearGradient(
                        colors: [Color(white: 1.0, opacity: 0.06), .clear],
                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.4)
                    )
                    .clipShape(KeycapShape(cornerRadius: 3, cutSize: 4))

                    if let sysImg = systemImage {
                        Image(systemName: sysImg)
                            .font(.system(size: 7, weight: .medium))
                            .foregroundColor(iconColor)
                            .shadow(color: isActive ? settings.schemeMid.opacity(0.9) : .clear, radius: 4)
                            .animation(.easeInOut(duration: 0.15), value: isActive)
                    } else {
                        Text(label)
                            .font(.system(size: 6, weight: .bold, design: .monospaced))
                            .foregroundColor(iconColor)
                            .shadow(color: isActive ? settings.schemeMid.opacity(0.9) : .clear, radius: 4)
                            .tracking(0.3)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.15), value: isActive)
                    }
                }
                .frame(width: width, height: h)
            }
            .frame(width: width, height: h + 4)
        }
        .buttonStyle(KeycapPressStyle(isDisabled: isDisabled))
        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 2)
        .opacity(isDisabled ? 0.35 : 1)
    }
}

struct TransportControlsView: View {
    @ObservedObject private var api = HertzAPIService.shared

    private var off: Bool { api.powerState != .on }
    private var isTuner: Bool { api.currentInput.lowercased() == "tuner" }
    private var isNetRadio: Bool { api.currentInput.lowercased() == "net_radio" }
    private var isNetUsb: Bool { !isTuner && api.powerState == .on }

    private var isPlaying: Bool { api.playbackStatus == "play" }
    private var isPaused:  Bool { api.playbackStatus == "pause" }
    private var isStopped: Bool { api.playbackStatus == "stop" }
    private var isShuffled: Bool { api.shuffleMode != "off" }
    private var isRepeating: Bool { api.repeatMode != "off" }
    private var repeatIcon: String {
        api.repeatMode == "one" ? "repeat.1" : "repeat"
    }

    var body: some View {
        VStack(spacing: 4) {

            // Row 1: [shuffle]  |<<  ►  >>|  [repeat]
            HStack(spacing: 6) {
                TransportButton(
                    label: "shuffle", systemImage: "shuffle",
                    width: 40, isActive: isShuffled,
                    isDisabled: off || isTuner
                ) { api.toggleShuffle() }

                TransportButton(label: "|<<", systemImage: "backward.end.fill", isDisabled: off) {
                    api.setPlayback("previous")
                }
                TransportButton(
                    label: "▶", systemImage: "play.fill",
                    isActive: isPlaying, isDisabled: off
                ) { api.setPlayback("play") }
                TransportButton(label: ">>|", systemImage: "forward.end.fill", isDisabled: off) {
                    api.setPlayback("next")
                }

                TransportButton(
                    label: "repeat", systemImage: repeatIcon,
                    width: 40, isActive: isRepeating,
                    isDisabled: off || isTuner
                ) { api.cycleRepeat() }
            }

            // Row 2: <<  ■  ‖  >>
            HStack(spacing: 6) {
                TransportButton(label: "<<", systemImage: "backward.fill", isDisabled: off) {
                    api.tuneStep("down")
                }
                TransportButton(
                    label: "■", systemImage: "stop.fill",
                    isActive: isStopped && isNetUsb, isDisabled: off
                ) {
                    if isTuner { api.cycleSoundProgram() }
                    else       { api.setPlayback("stop") }
                }
                TransportButton(
                    label: "‖", systemImage: "pause.fill",
                    isActive: isPaused, isDisabled: off
                ) {
                    if isTuner {
                        let next = api.tunerBand == "fm" ? "am" : "fm"
                        api.setBand(next)
                    } else {
                        api.setPlayback("pause")
                    }
                }
                TransportButton(label: ">>", systemImage: "forward.fill", isDisabled: off) {
                    api.tuneStep("up")
                }
            }

            // Row 3: <  >
            HStack(spacing: 6) {
                TransportButton(label: "<", isDisabled: off) {
                    if isNetRadio { api.prevNetPreset() }
                    else          { api.switchTunerPreset("previous") }
                }
                TransportButton(label: ">", isDisabled: off) {
                    if isNetRadio { api.nextNetPreset() }
                    else          { api.switchTunerPreset("next") }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}
