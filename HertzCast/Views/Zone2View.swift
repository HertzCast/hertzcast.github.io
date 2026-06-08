import SwiftUI

struct Zone2View: View {
    @ObservedObject private var api      = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    private var isOn: Bool { api.zone2Power == .on }

    private var volumeLabel: String {
        guard isOn else { return "– – –" }
        if api.zone2IsMuted { return "MUTE" }
        if let db = api.zone2ActualVolumeDb { return String(format: "%.1f dB", db) }
        return "VOL \(api.zone2Volume)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ── Input ─────────────────────────────────────────────
                HStack {
                    Text("Input")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { api.zone2Input },
                        set: { api.setZone2Input($0) }
                    )) {
                        ForEach(HertzAPIService.allSources, id: \.value) { s in
                            Text(s.label).tag(s.value)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 140)
                    .disabled(!isOn)
                }

                Divider()

                // ── Volume ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Volume")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(volumeLabel)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(api.zone2IsMuted
                                ? Color(red: 1.0, green: 0.35, blue: 0.2)
                                : .primary)
                    }

                    HStack(spacing: 10) {
                        TransportButton(label: "−", width: 36, isDisabled: !isOn) {
                            api.zone2VolumeDown()
                        }
                        Slider(value: Binding(
                            get: { Double(api.zone2Volume) },
                            set: { api.setZone2Volume(Int($0)) }
                        ), in: 0...Double(api.zone2MaxVolume), step: 1)
                        .disabled(!isOn)
                        TransportButton(label: "+", width: 36, isDisabled: !isOn) {
                            api.zone2VolumeUp()
                        }
                    }
                }

                Divider()

                // ── Mute ──────────────────────────────────────────────
                HStack {
                    Text("Mute")
                        .foregroundColor(.secondary)
                    Spacer()
                    TransportButton(
                        label: "",
                        systemImage: api.zone2IsMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                        width: 44,
                        isActive: api.zone2IsMuted,
                        isDisabled: !isOn
                    ) {
                        api.toggleZone2Mute()
                    }
                }

                Spacer()
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
