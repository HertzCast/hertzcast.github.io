import SwiftUI

struct ThemeToggleView: View {
    @ObservedObject private var settings = HertzSettings.shared

    private let pillW: CGFloat = 64
    private let pillH: CGFloat = 32
    private let circleSize: CGFloat = 24

    var body: some View {
        ZStack {
            // Pill background
            Capsule()
                .fill(settings.isLight ? Color.white : Color(white: 0.05))
                .overlay(Capsule()
                    .stroke(settings.isLight ? Color(white: 0.85) : Color(white: 0.18), lineWidth: 1))

            HStack(spacing: 0) {
                // Left slot — Moon
                ZStack {
                    Circle()
                        .fill(settings.isLight ? Color.clear : Color(white: 0.18))
                        .frame(width: circleSize, height: circleSize)

                    Image(systemName: "moon.fill")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(settings.isLight ? Color(white: 0.0).opacity(0.7) : .white)
                }
                .frame(width: circleSize, height: circleSize)

                Spacer()

                // Right slot — Sun
                ZStack {
                    Circle()
                        .fill(settings.isLight ? Color(white: 0.88) : Color.clear)
                        .frame(width: circleSize, height: circleSize)

                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(settings.isLight ? Color(white: 0.35) : Color(white: 0.45))
                }
                .frame(width: circleSize, height: circleSize)
            }
            .padding(.horizontal, 4)
        }
        .frame(width: pillW, height: pillH)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: settings.isLight)
        .onTapGesture {
            settings.appTheme = settings.isLight ? "dark" : "light"
        }
    }
}
