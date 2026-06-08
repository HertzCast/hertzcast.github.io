import SwiftUI

private struct KeycapButton: View {
    let label: String
    let isActive: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var cachedButtonImage: NSImage = NSImage()

    private let size: CGFloat = 52

    private func loadButtonImage() {
        let name = settings.isLight ? "Button White" : "Button"
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) { cachedButtonImage = img }
    }

    var body: some View {
        Button(action: { if !isDisabled { onTap() } }) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ZStack {
                        // PNG base
                        Image(nsImage: cachedButtonImage)
                            .resizable()
                            .frame(width: size, height: size)

                        // Label
                        Text(label)
                            .font(.system(size: label.count > 5 ? 7 : 9,
                                          weight: .bold, design: .monospaced))
                            .foregroundColor(isActive ? settings.schemeColor : (settings.isLight ? Color(white: 0.15) : Color.white))
                            .shadow(color: isActive && !settings.isLight ? settings.schemeMid.opacity(0.8) : .clear, radius: 4)
                            .tracking(0.5)
                            .animation(.easeInOut(duration: 0.15), value: isActive)
                    }
                    .frame(width: size, height: size)

                    // LED indicator
                    ZStack {
                        if isActive && !settings.isLight {
                            Circle()
                                .fill(settings.schemeMid.opacity(0.5))
                                .blur(radius: 4)
                                .frame(width: 10, height: 10)
                        }
                        Circle()
                            .fill(isActive ? settings.schemeColor : Color(white: settings.isLight ? 0.65 : 0.10))
                            .frame(width: 4, height: 4)
                            .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 0.5))
                            .shadow(color: isActive && !settings.isLight ? settings.schemeMid : .clear,
                                    radius: isActive && !settings.isLight ? 3 : 0)
                    }
                    .frame(height: 14)
                    .animation(.easeInOut(duration: 0.15), value: isActive)
                }
            }
        }
        .buttonStyle(KeycapPressStyle(isDisabled: isDisabled))
        .shadow(color: .black.opacity(settings.isLight ? 0.15 : 0.75), radius: settings.isLight ? 4 : 8, x: 0, y: 4)
        .opacity(1.0)
        .onAppear { loadButtonImage() }
        .onChange(of: settings.isLight) { _ in loadButtonImage() }
    }
}

struct SceneButtonsView: View {
    @ObservedObject private var api      = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared
    @State private var poweringOn = false

    var body: some View {
        let sources = [settings.button1Source, settings.button2Source,
                       settings.button3Source, settings.button4Source]
        HStack(spacing: 6) {
            ForEach(sources, id: \.self) { input in
                KeycapButton(
                    label: HertzAPIService.buttonLabel(input),
                    isActive: api.currentInput.lowercased() == input.lowercased() && api.powerState == .on,
                    isDisabled: api.powerState == .unknown || poweringOn,
                    onTap: { handleTap(input) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func handleTap(_ input: String) {
        if api.powerState == .on {
            api.setInput(input) { _ in }
        } else if api.powerState == .standby {
            poweringOn = true
            api.powerOnWithInput(input) { _ in
                DispatchQueue.main.async { poweringOn = false }
            }
        }
    }
}
