import SwiftUI
import AppKit

struct PowerButtonView: View {
    let isOn: Bool
    let isDisabled: Bool
    let isBusy: Bool
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isPressed = false

    private let size: CGFloat = 40

    private var buttonImage: NSImage {
        if let url = Bundle.main.url(forResource: "Button", withExtension: "png"),
           let img = NSImage(contentsOf: url) { return img }
        return NSImage()
    }

    var body: some View {
        ZStack {
            Image(nsImage: buttonImage)
                .resizable()
                .frame(width: size, height: size)

            if isBusy {
                ProgressView().scaleEffect(0.62)
            } else {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: isOn ? settings.schemeMid.opacity(0.9) : .clear, radius: 5)
                    .animation(.easeInOut(duration: 0.15), value: isOn)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isPressed ? 0.91 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .onTapGesture {
            guard !isDisabled && !isBusy else { return }
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { isPressed = false }
            onTap()
        }
    }
}
