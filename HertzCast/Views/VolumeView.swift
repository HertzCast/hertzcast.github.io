import SwiftUI
import AppKit

// Reference-type box so the scroll closure always reads the latest volume,
// not the stale value captured at onAppear time.
private final class VolumeRef {
    var value: Int
    init(_ v: Int) { value = v }
}

struct MixerFader: View {
    let volume: Int
    let maxVolume: Int
    let isDisabled: Bool
    let onCommit: (Int) -> Void
    var trackH: CGFloat = 160

    private let housingW: CGFloat = 64
    private let housingH: CGFloat = 128
    private let handleW: CGFloat = 52
    private let handleH: CGFloat = 38
    private let railPad: CGFloat = 10

    private var topPos: CGFloat    { -(housingH / 2 - railPad - handleH / 2) }
    private var bottomPos: CGFloat {   housingH / 2 - railPad - handleH / 2  }

    private var fraction: Double {
        maxVolume > 0 ? Double(volume) / Double(maxVolume) : 0
    }

    @State private var handleY: CGFloat = 0
    @State private var dragStartFraction: Double = 0
    @State private var isDragging = false
    @State private var scrollAccumulator: CGFloat = 0
    @State private var scrollMonitor: Any? = nil
    @State private var volRef = VolumeRef(0)

    private func posY(for frac: Double) -> CGFloat {
        bottomPos - CGFloat(frac) * (bottomPos - topPos)
    }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(white: 0.15))
                    .frame(width: 44, height: 7)

                housing
            }
            .opacity(isDisabled ? 0.4 : 1)
        }
        .onAppear {
            handleY = posY(for: fraction)
            volRef.value = volume
            let ref = volRef
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard !isDisabled else { return event }
                let step: Int
                if event.hasPreciseScrollingDeltas {
                    scrollAccumulator += event.scrollingDeltaY * 0.25
                    step = Int(scrollAccumulator)
                    guard step != 0 else { return event }
                    scrollAccumulator -= CGFloat(step)
                } else {
                    let raw = event.deltaY
                    guard abs(raw) > 0.1 else { return event }
                    step = raw > 0 ? 1 : -1
                }
                let newVol = max(0, min(maxVolume, ref.value + step))
                ref.value = newVol  // update immediately so rapid scrolls stack correctly
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        handleY = posY(for: Double(newVol) / Double(maxVolume))
                    }
                    onCommit(newVol)
                }
                return event
            }
        }
        .onChange(of: volume) { newVal in
            if !isDragging {
                volRef.value = newVal
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    handleY = posY(for: Double(newVal) / Double(maxVolume))
                }
            }
        }
        .onDisappear {
            if let m = scrollMonitor { NSEvent.removeMonitor(m) }
            scrollMonitor = nil
        }
    }

    private var housing: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.1))
                .overlay(RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(white: 0.18), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.7), radius: 16, x: 0, y: 8)

            RoundedRectangle(cornerRadius: 5)
                .fill(Color.black)
                .overlay(Rectangle().fill(Color(white: 0.12)).frame(width: 1))
                .frame(width: 10, height: housingH - railPad * 2 - 4)

            handle
                .offset(y: handleY)
                .gesture(dragGesture)

            Text("MAX")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.3))
                .rotationEffect(.degrees(90))
                .offset(x: housingW / 2 - 6, y: topPos)

            Text("0")
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Color(white: 0.3))
                .rotationEffect(.degrees(90))
                .offset(x: housingW / 2 - 6, y: bottomPos)
        }
        .frame(width: housingW, height: housingH)
    }

    private var handle: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(LinearGradient(
                colors: [Color(white: 0.28), Color(white: 0.16)],
                startPoint: .top, endPoint: .bottom))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color(white: 0.25), lineWidth: 0.5))
            .overlay(gripLines)
            .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 3)
            .frame(width: handleW, height: handleH)
    }

    private var gripLines: some View {
        VStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(i == 2
                          ? Color(white: 0.75)
                          : Color(white: 0, opacity: 0.45))
                    .frame(width: 30, height: i == 2 ? 1.5 : 1)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { val in
                guard !isDisabled else { return }
                if !isDragging {
                    isDragging = true
                    dragStartFraction = fraction
                }
                let range = bottomPos - topPos
                let delta = -val.translation.height / range
                let newFrac = max(0, min(1, dragStartFraction + delta))
                handleY = posY(for: newFrac)
                let newVol = Int((newFrac * Double(maxVolume)).rounded())
                if newVol != volume { onCommit(newVol) }
            }
            .onEnded { val in
                guard !isDisabled else { return }
                isDragging = false
                let range = bottomPos - topPos
                let delta = -val.translation.height / range
                let newFrac = max(0, min(1, dragStartFraction + delta))
                let newVol = Int((newFrac * Double(maxVolume)).rounded())
                onCommit(newVol)
            }
    }
}
