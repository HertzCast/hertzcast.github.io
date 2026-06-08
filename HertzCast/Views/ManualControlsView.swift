import SwiftUI

struct IndustrialPowerSwitch: View {
    let isOn: Bool
    let isDisabled: Bool
    let isBusy: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared

    private let housingW: CGFloat = 64
    private let housingH: CGFloat = 128
    private let handleW: CGFloat = 54
    private let handleH: CGFloat = 62
    private let railPad: CGFloat = 10

    private var topPos: CGFloat    { -(housingH / 2 - railPad - handleH / 2) }
    private var bottomPos: CGFloat {   housingH / 2 - railPad - handleH / 2  }

    @State private var handleY: CGFloat = 0

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 3) {
                ledBar
                housing
            }
            .opacity(isDisabled ? 0.4 : 1)

            if isBusy {
                ProgressView().scaleEffect(0.8)
            }
        }
        .onAppear { handleY = isOn ? bottomPos : topPos }
        .onChange(of: isOn) { newVal in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                handleY = newVal ? bottomPos : topPos
            }
        }
    }

    private var ledBar: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(isOn ? settings.schemeMid : Color(red: 0.35, green: 0.08, blue: 0.08))
            .shadow(color: isOn ? settings.schemeGlow : .clear, radius: 8)
            .frame(width: 44, height: 7)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }

    private var housing: some View {
        ZStack {
            // Shell
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.1))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(white: 0.18), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.7), radius: 16, x: 0, y: 8)

            // Rail slot
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black)
                .overlay(Rectangle().fill(Color(white: 0.12)).frame(width: 1))
                .frame(width: 10, height: housingH - railPad * 2 - 4)

            // Handle
            handle
                .offset(y: handleY)
                .gesture(dragGesture)
                .onTapGesture { if !isDisabled && !isBusy { onTap() } }

            // Side labels
            Text("OFF")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.3))
                .rotationEffect(.degrees(90))
                .offset(x: housingW / 2 - 6, y: topPos)

            Text("ON")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.3))
                .rotationEffect(.degrees(90))
                .offset(x: housingW / 2 - 6, y: bottomPos)
        }
        .frame(width: housingW, height: housingH)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(isOn
                  ? LinearGradient(
                        colors: [settings.schemeDarkTop, settings.schemeDarkBottom],
                        startPoint: .top, endPoint: .bottom)
                  : LinearGradient(
                        colors: [Color(white: 0.25), Color(white: 0.15)],
                        startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(white: 0.25), lineWidth: 0.5))
            .overlay(handleContent)
            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
            .frame(width: handleW, height: handleH)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isOn)
    }

    @ViewBuilder
    private var handleContent: some View {
        VStack(spacing: 5) {
            // Grip lines
            VStack(spacing: 4) {
                ForEach(0..<2, id: \.self) { _ in
                    Capsule()
                        .fill(Color(white: 0, opacity: 0.45))
                        .frame(width: 30, height: 1.5)
                }
            }
            .padding(.top, 8)

            Spacer()

            // Status text
            ZStack {
                Text("STANDBY")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(Color(white: 0.35))
                    .tracking(1)
                    .opacity(isOn ? 0 : 1)
                Text("ONLINE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundColor(settings.schemeColor)
                    .tracking(1)
                    .shadow(color: settings.isLight ? .clear : settings.schemeMid.opacity(0.8), radius: 5)
                    .opacity(isOn ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.15), value: isOn)
            .padding(.bottom, 10)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { val in
                guard !isDisabled && !isBusy else { return }
                let base: CGFloat = isOn ? bottomPos : topPos
                handleY = max(topPos, min(bottomPos, base + val.translation.height))
            }
            .onEnded { val in
                guard !isDisabled && !isBusy else { return }
                let base: CGFloat = isOn ? bottomPos : topPos
                let finalPos = base + val.translation.height
                let shouldBeOn = finalPos > (topPos + bottomPos) / 2
                withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                    handleY = shouldBeOn ? bottomPos : topPos
                }
                if shouldBeOn != isOn { onTap() }
            }
    }
}

private struct MuteButton: View {
    let isMuted: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isPressed = false
    @State private var cachedButtonImage: NSImage = NSImage()

    private let size: CGFloat = 40

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

            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isMuted ? settings.schemeColor : (settings.isLight ? .black : .white))
                .shadow(color: isMuted && !settings.isLight ? settings.schemeMid.opacity(0.9) : .clear, radius: 5)
                .animation(.easeInOut(duration: 0.15), value: isMuted)
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.91 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .onAppear { loadButtonImage() }
        .onChange(of: settings.isLight) { _ in loadButtonImage() }
        .onTapGesture {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            onTap()
        }
    }
}

struct ManualControlsView: View {
    @ObservedObject private var api = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared
    @State private var isBusy = false
    @State private var feedback: String? = nil

    private var isOn: Bool { api.powerState == .on }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Volume knob — centered
                VolumeKnobView(
                    volume: api.volume,
                    maxVolume: api.maxVolume,
                    isDisabled: api.powerState != .on,
                    onCommit: { newVol in api.setVolume(newVol) { _ in } }
                )

                // Power button — top-left
                VStack {
                    HStack {
                        PowerButtonView(
                            isOn: isOn,
                            isDisabled: api.powerState == .unknown,
                            isBusy: isBusy,
                            onTap: togglePower
                        )
                        Spacer()
                    }
                    Spacer()
                }

                // Mute button — bottom-right, slightly lower than before
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MuteButton(isMuted: api.isMuted, onTap: { api.toggleMute() })
                            .padding(.trailing, 4)
                    }
                    .padding(.bottom, 2)
                }

                // VOLUME label — centered, small gap below knob
                VStack {
                    Spacer()
                    Text("VOLUME")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(settings.appTextDim)
                        .tracking(1.5)
                        .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)

            if let feedback {
                Text(feedback)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func togglePower() {
        isBusy = true
        feedback = nil
        switch api.powerState {
        case .on:
            api.setPower("standby") { error in finish(error: error) }
        case .standby, .unknown:
            api.powerOnSequence { error in finish(error: error) }
        }
    }

    private func finish(error: Error?) {
        isBusy = false
        if let error {
            feedback = error.localizedDescription
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.api.fetchStatus()
                self.feedback = nil
            }
        }
    }
}
