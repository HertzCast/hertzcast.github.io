import SwiftUI
import AppKit

struct PowerButtonView: View {
    let isOn: Bool
    let isDisabled: Bool
    let isBusy: Bool
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

            if isBusy {
                ProgressView().scaleEffect(0.62)
            } else {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isOn ? settings.schemeColor : (settings.isLight ? .black : .white))
                    .shadow(color: isOn && !settings.isLight ? settings.schemeMid.opacity(0.9) : .clear, radius: 5)
                    .animation(.easeInOut(duration: 0.15), value: isOn)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.91 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .onAppear { loadButtonImage() }
        .onChange(of: settings.isLight) { _ in loadButtonImage() }
        .onTapGesture {
            guard !isDisabled && !isBusy else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            onTap()
        }
    }
}
