import SwiftUI
import AppKit

private final class VolumeRef {
    var value: Int
    init(_ v: Int) { value = v }
}

struct VolumeKnobView: View {
    let volume: Int
    let maxVolume: Int
    let isDisabled: Bool
    let onCommit: (Int) -> Void

    @ObservedObject private var settings = HertzSettings.shared

    private let size: CGFloat = 145
    private let totalSize: CGFloat = 193
    private let startAngle: Double = -135
    private let endAngle: Double = 135
    private let tickCount: Int = 31

    @State private var isDragging = false
    @State private var dragStartFraction: Double = 0
    @State private var dragStartAngle: Double = 0
    @State private var dragVolume: Int? = nil
    @State private var lastSentDragVolume: Int? = nil
    @State private var scrollAccumulator: CGFloat = 0
    @State private var scrollMonitor: Any? = nil
    @State private var volRef = VolumeRef(0)
    @State private var cachedKnobImage: NSImage = NSImage()

    private var displayVolume: Int { dragVolume ?? volume }

    private var fraction: Double {
        maxVolume > 0 ? Double(displayVolume) / Double(maxVolume) : 0
    }

    private var rotationDegrees: Double {
        startAngle + fraction * (endAngle - startAngle)
    }

    private func loadKnobImage() {
        let name = settings.isLight ? "Volume White" : "Volume"
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let img = NSImage(contentsOf: url) { cachedKnobImage = img }
    }

    var body: some View {
        ZStack {
            graduationRing

            // Knob + indicator rotate together
            ZStack {
                Image(nsImage: cachedKnobImage)
                    .resizable()
                    .frame(width: size, height: size)

                // Theme-colored indicator dot (covers the blue PNG dot)
                Circle()
                    .fill(settings.schemeColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: settings.isLight ? .clear : settings.schemeMid.opacity(0.95), radius: 5)
                    .offset(y: -(size / 2 - 13))
            }
            .rotationEffect(Angle(degrees: rotationDegrees))
            .animation(isDragging ? nil : .easeOut(duration: 0.12), value: rotationDegrees)

            minMaxLabels
        }
        .frame(width: totalSize, height: totalSize)
        .gesture(dragGesture)
        .onAppear {
            volRef.value = volume
            loadKnobImage()
            setupScrollMonitor()
        }
        .onChange(of: settings.isLight) { _ in loadKnobImage() }
        .onChange(of: volume) { newVal in
            if !isDragging { volRef.value = newVal }
        }
        .onDisappear {
            if let m = scrollMonitor { NSEvent.removeMonitor(m) }
            scrollMonitor = nil
        }
    }

    // MARK: - Graduation ring

    private var graduationRing: some View {
        let litCount = Int((fraction * Double(tickCount - 1)).rounded())
        let innerR = size / 2 + 5.0
        let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
        let litColor = settings.schemeColor
        let isLightTheme = settings.isLight

        return Canvas { ctx, _ in
            for i in 0..<tickCount {
                let t = Double(i) / Double(tickCount - 1)
                let angleDeg = startAngle + t * (endAngle - startAngle)
                let rad = angleDeg * .pi / 180.0
                let isMajor = i % 5 == 0
                let tickLen: CGFloat = isMajor ? 9 : 5
                let outerR = innerR + tickLen
                let isLit = i <= litCount

                let x1 = center.x + innerR * CGFloat(sin(rad))
                let y1 = center.y - innerR * CGFloat(cos(rad))
                let x2 = center.x + outerR * CGFloat(sin(rad))
                let y2 = center.y - outerR * CGFloat(cos(rad))

                var path = Path()
                path.move(to: CGPoint(x: x1, y: y1))
                path.addLine(to: CGPoint(x: x2, y: y2))

                let color: Color
                if isLit {
                    color = litColor.opacity(isMajor ? 1.0 : 0.75)
                } else {
                    color = isLightTheme
                        ? Color.black.opacity(isMajor ? 0.30 : 0.18)
                        : Color.white.opacity(isMajor ? 0.28 : 0.16)
                }
                ctx.stroke(path, with: .color(color), lineWidth: isMajor ? 2.0 : 1.2)
            }
        }
        .drawingGroup()
        .frame(width: totalSize, height: totalSize)
    }

    // MARK: - MIN / MAX labels

    private var minMaxLabels: some View {
        let labelR = size / 2 + 20.0
        let minRad = startAngle * .pi / 180.0
        let maxRad = endAngle * .pi / 180.0
        return ZStack {
            Text("MIN")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(settings.appTextDim)
                .tracking(0.5)
                .offset(x: CGFloat(sin(minRad)) * labelR,
                        y: -CGFloat(cos(minRad)) * labelR + 4)
            Text("MAX")
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(settings.appTextDim)
                .tracking(0.5)
                .offset(x: CGFloat(sin(maxRad)) * labelR,
                        y: -CGFloat(cos(maxRad)) * labelR + 4)
        }
    }

    // MARK: - Interaction

    private func setupScrollMonitor() {
        let ref = volRef
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [self] event in
            guard !isDisabled else { return event }
            let step: Int
            if event.hasPreciseScrollingDeltas {
                scrollAccumulator += event.scrollingDeltaY * 0.3
                let s = Int(scrollAccumulator)
                guard s != 0 else { return event }
                scrollAccumulator -= CGFloat(s)
                step = s
            } else {
                let raw = event.deltaY
                guard abs(raw) > 0.1 else { return event }
                step = raw > 0 ? 1 : -1
            }
            let newVol = max(0, min(maxVolume, ref.value + step))
            ref.value = newVol
            DispatchQueue.main.async { onCommit(newVol) }
            return event
        }
    }

    private func angleFromPoint(_ point: CGPoint) -> Double {
        let center = CGPoint(x: totalSize / 2, y: totalSize / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dx, -dy) * 180.0 / .pi
    }

    private func normalizedDelta(_ delta: Double) -> Double {
        var d = delta
        while d > 180 { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { val in
                guard !isDisabled else { return }
                if !isDragging {
                    isDragging = true
                    dragStartFraction = fraction
                    dragStartAngle = angleFromPoint(val.startLocation)
                }
                let currentAngle = angleFromPoint(val.location)
                let delta = normalizedDelta(currentAngle - dragStartAngle)
                let newFrac = max(0, min(1, dragStartFraction + delta / 270.0))
                let newVol = Int((newFrac * Double(maxVolume)).rounded())
                dragVolume = newVol
                if newVol != lastSentDragVolume {
                    lastSentDragVolume = newVol
                    volRef.value = newVol
                    onCommit(newVol)
                }
            }
            .onEnded { val in
                guard !isDisabled else { return }
                isDragging = false
                let currentAngle = angleFromPoint(val.location)
                let delta = normalizedDelta(currentAngle - dragStartAngle)
                let newFrac = max(0, min(1, dragStartFraction + delta / 270.0))
                let newVol = Int((newFrac * Double(maxVolume)).rounded())
                dragVolume = nil
                lastSentDragVolume = nil
                if newVol != volRef.value {
                    volRef.value = newVol
                    onCommit(newVol)
                }
            }
    }
}
