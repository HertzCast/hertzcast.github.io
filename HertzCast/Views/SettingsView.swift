import SwiftUI

private struct SettingsActionButton: View {
    let label: String
    var systemImage: String? = nil
    var isDestructive: Bool = false
    let onTap: () -> Void

    @ObservedObject private var settings = HertzSettings.shared
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                if let img = systemImage {
                    Image(systemName: img).font(.system(size: 11, weight: .medium))
                }
                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(0.3)
            }
            .foregroundColor(
                isDestructive
                    ? Color(red: 1.0, green: 0.30, blue: 0.25)
                    : (settings.isLight ? Color(white: 0.15) : .white)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(
                        colors: settings.isLight
                            ? [Color(white: 0.98), Color(white: 0.93)]
                            : [Color(white: 0.17), Color(white: 0.11)],
                        startPoint: .top, endPoint: .bottom
                    ))
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            settings.isLight ? Color(white: 0.82) : Color(white: 0.25),
                            lineWidth: 0.5
                        ))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.52), value: isPressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in isPressed = true }
            .onEnded   { _ in isPressed = false }
        )
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = HertzSettings.shared
    @ObservedObject private var api = HertzAPIService.shared
    @StateObject private var discovery = DiscoveryService()
    @State private var draft: String = ""
    @State private var showManual = false
    @State private var scheduleExpanded = false
    @State private var buttonsExpanded = false
    @State private var showRebootConfirm = false
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {

                // ── Receiver ─────────────────────────────────────────────
                discoverSection

                Divider()

                // ── Theme ────────────────────────────────────────────────
                HStack {
                    Text("Theme")
                        .foregroundColor(.secondary)
                    Spacer()
                    ThemeToggleView()
                }

                Divider()

                // ── Source Buttons ───────────────────────────────────────
                DisclosureGroup(isExpanded: $buttonsExpanded) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Array(zip(1...4, [
                            $settings.button1Source,
                            $settings.button2Source,
                            $settings.button3Source,
                            $settings.button4Source
                        ])), id: \.0) { index, binding in
                            HStack {
                                Text("Button \(index)")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("", selection: binding) {
                                    ForEach(HertzAPIService.allSources, id: \.value) { s in
                                        Text(s.label).tag(s.value)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 140)
                            }
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Text("Source Buttons")
                        .font(.headline)
                }

                Divider()

                // ── Schedule ─────────────────────────────────────────────
                DisclosureGroup(isExpanded: $scheduleExpanded) {
                    VStack(alignment: .leading, spacing: 0) {
                        MorningAlarmView()
                            .padding(.top, 8)
                            .padding(.bottom, 6)
                        Divider()
                        AutoOffView()
                            .padding(.top, 6)
                            .padding(.bottom, 6)
                        Divider()
                        HStack {
                            Text("Sleep Timer")
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: Binding(
                                get: { api.sleepTimer },
                                set: { api.setSleep($0) }
                            )) {
                                Text("Off").tag(0)
                                ForEach([15, 30, 45, 60, 90, 120], id: \.self) { min in
                                    Text("\(min) min").tag(min)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 8)
                    }
                } label: {
                    Text("Schedule")
                        .font(.headline)
                }

                Spacer()

                // ── Reboot ───────────────────────────────────────────────
                Divider()
                SettingsActionButton(
                    label: "Reboot Receiver",
                    systemImage: "arrow.clockwise",
                    isDestructive: true
                ) { showRebootConfirm = true }
                .padding(.top, 8)
                .alert("Reboot Receiver?", isPresented: $showRebootConfirm) {
                    Button("Reboot", role: .destructive) { api.reboot() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("The receiver will restart and be offline for ~30 seconds.")
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Discovery section

    @ViewBuilder
    private var discoverSection: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ── Discover button ───────────────────────────────────────────
            if discovery.isScanning {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Cancel") { discovery.stopScan() }
                        .font(.caption)
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            } else {
                SettingsActionButton(
                    label: "Discover Receiver",
                    systemImage: "antenna.radiowaves.left.and.right"
                ) { discovery.startScan() }
            }

            // ── Discovery results ─────────────────────────────────────────
            if !discovery.discovered.isEmpty {
                deviceList
            }

            // ── Manual IP entry (always visible) ─────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Text("Receiver IP Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    TextField("192.168.x.x", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .onAppear { draft = settings.ipAddress }
                        .onSubmit { commit() }
                        .focused($focused)
                    Button("Save") { commit() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(settings.isLight ? Color(white: 0.15) : .white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(LinearGradient(
                                    colors: settings.isLight
                                        ? [Color(white: 0.98), Color(white: 0.93)]
                                        : [Color(white: 0.17), Color(white: 0.11)],
                                    startPoint: .top, endPoint: .bottom
                                ))
                                .overlay(RoundedRectangle(cornerRadius: 5)
                                    .stroke(settings.isLight ? Color(white: 0.82) : Color(white: 0.25), lineWidth: 0.5))
                        )
                        .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !settings.ipAddress.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Connected to \(settings.ipAddress)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Found \(discovery.discovered.count) receiver\(discovery.discovered.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Scan again") { discovery.startScan() }
                    .font(.caption)
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            ForEach(discovery.discovered) { device in
                Button {
                    draft = device.host
                    commit()
                    discovery.discovered = []
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(device.name)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                            Text(device.host)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(white: 0.15).cornerRadius(6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commit() {

        settings.ipAddress = draft.trimmingCharacters(in: .whitespaces)
        focused = false
        showManual = false
    }
}
