import SwiftUI
import AppKit

struct MusicCenterView: View {
    @ObservedObject private var api = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    @AppStorage("mc_recent_expanded")     private var recentExpanded     = true
    @AppStorage("mc_favourites_expanded") private var favouritesExpanded = true
    @AppStorage("mc_sources_expanded")    private var sourcesExpanded    = true
    @AppStorage("mc_browse_expanded")     private var browseExpanded     = false

    @State private var savePresetSlot: Int = 1
    @State private var showSaveConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Recent Played ─────────────────────────────────────
                DisclosureGroup(isExpanded: $recentExpanded) {
                    if api.recentItems.isEmpty {
                        Text("No recent stations")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(api.recentItems) { item in
                                Button {
                                    api.recallRecentItem(item.id + 1)
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "dot.radiowaves.left.and.right")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(white: 0.5))
                                            .frame(width: 20)
                                        Text(item.text)
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if item.id != api.recentItems.last?.id {
                                    Divider().padding(.leading, 34)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } label: {
                    Text("RECENT PLAYED")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)
                }
                .padding(.vertical, 8)

                Divider()

                // ── Favourites ────────────────────────────────────────
                DisclosureGroup(isExpanded: $favouritesExpanded) {
                    if api.presetItems.isEmpty {
                        Text("No presets saved")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.4))
                            .padding(.vertical, 6)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(api.presetItems) { preset in
                                Button {
                                    api.playPresetInMusicCenter(preset.id)
                                } label: {
                                    HStack(spacing: 10) {
                                        ZStack {
                                            Circle()
                                                .fill(settings.schemeColor.opacity(0.15))
                                                .frame(width: 20, height: 20)
                                            Text("\(preset.id)")
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(settings.schemeColor)
                                        }
                                        Text(preset.text)
                                            .font(.system(size: 12))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 7)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if preset.id != api.presetItems.last?.id {
                                    Divider().padding(.leading, 34)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                } label: {
                    HStack {
                        Text("FAVOURITES")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.5))
                            .tracking(1)
                        Spacer()
                        // Save current station button (only when Net Radio is playing)
                        if api.powerState == .on &&
                           api.currentInput.lowercased() == "net_radio" &&
                           !api.nowPlayingTrack.isEmpty {
                            Menu {
                                ForEach(1...5, id: \.self) { slot in
                                    Button("Save to Preset \(slot)") {
                                        api.storePreset(slot)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 13))
                                    .foregroundColor(settings.schemeColor)
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 20)
                            .onTapGesture {} // prevent disclosure toggle
                        }
                    }
                }
                .padding(.vertical, 8)

                Divider()

                // ── Browse Net Radio ──────────────────────────────────
                DisclosureGroup(isExpanded: $browseExpanded) {
                    NetRadioBrowserView()
                        .padding(.top, 4)
                        .id("net-radio-browser")
                } label: {
                    Text("BROWSE NET RADIO")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)
                }
                .padding(.vertical, 8)

                Divider()

                // ── Sources ───────────────────────────────────────────
                DisclosureGroup(isExpanded: $sourcesExpanded) {
                    let allInputs = api.availableInputs.isEmpty
                        ? HertzAPIService.allSources.map { $0.value }
                        : api.availableInputs
                    let inputs = allInputs.filter { !settings.hiddenSources.contains($0) }

                    VStack(spacing: 0) {
                        ForEach(inputs, id: \.self) { inputId in
                            let isActive = api.currentInput.lowercased() == inputId.lowercased()
                            Button {
                                api.setInput(inputId) { _ in }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: sfSymbol(for: inputId))
                                        .font(.system(size: 13))
                                        .foregroundColor(isActive ? settings.schemeColor : Color(white: 0.5))
                                        .frame(width: 20)
                                    Text(shortLabel(for: inputId))
                                        .font(.system(size: 12))
                                        .foregroundColor(isActive ? settings.schemeColor : .primary)
                                    Spacer()
                                    if isActive {
                                        Circle()
                                            .fill(settings.schemeColor)
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 7)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if inputId != inputs.last {
                                Divider().padding(.leading, 34)
                            }
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    Text("SOURCES")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)
                }
                .padding(.vertical, 8)

                // ── Visible Sources ───────────────────────────────────
                DisclosureGroup {
                    let allInputs = api.availableInputs.isEmpty
                        ? HertzAPIService.allSources.map { $0.value }
                        : api.availableInputs
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(allInputs, id: \.self) { inputId in
                            let hidden = settings.hiddenSources.contains(inputId)
                            Toggle(isOn: Binding(
                                get: { !hidden },
                                set: { show in
                                    if show { settings.hiddenSources.remove(inputId) }
                                    else    { settings.hiddenSources.insert(inputId) }
                                }
                            )) {
                                Text(HertzAPIService.formatInput(inputId))
                                    .font(.system(size: 12))
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.top, 6)
                } label: {
                    Text("VISIBLE SOURCES")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                        .tracking(1)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            api.fetchRecentInfo()
            api.fetchPresetInfo()
            if api.availableInputs.isEmpty { api.fetchFuncStatus() }
        }
    }
}

// MARK: - Helpers

private func sfSymbol(for input: String) -> String {
    switch input.lowercased() {
    case "net_radio":                   return "dot.radiowaves.left.and.right"
    case "spotify":                     return "music.note"
    case "airplay":                     return "airplayaudio"
    case "bluetooth":                   return "wave.3.right"
    case "tuner":                       return "radio"
    case "tv":                          return "tv"
    case "hdmi1", "hdmi2", "hdmi3",
         "hdmi4", "hdmi5", "hdmi6":     return "display"
    case "av1", "av2", "av3":           return "rectangle.connected.to.line.below"
    case "cd":                          return "opticaldisc"
    case "usb":                         return "externaldrive"
    case "server":                      return "server.rack"
    case "audio1", "audio2":            return "headphones"
    case "optical1", "optical2",
         "coaxial1", "coaxial2":        return "cable.connector"
    case "tidal", "qobuz", "deezer",
         "pandora", "sirius_xm",
         "amazon_music", "roon":        return "music.note.list"
    default:                            return "music.note"
    }
}

private func shortLabel(for input: String) -> String {
    switch input.lowercased() {
    case "net_radio":     return "Net Radio"
    case "spotify":       return "Spotify"
    case "airplay":       return "AirPlay"
    case "bluetooth":     return "Bluetooth"
    case "tuner":         return "FM Tuner"
    case "tv":            return "TV"
    case "hdmi1":         return "HDMI 1"
    case "hdmi2":         return "HDMI 2"
    case "hdmi3":         return "HDMI 3"
    case "hdmi4":         return "HDMI 4"
    case "hdmi5":         return "HDMI 5"
    case "hdmi6":         return "HDMI 6"
    case "av1":           return "AV 1"
    case "av2":           return "AV 2"
    case "cd":            return "CD"
    case "usb":           return "USB"
    case "server":        return "Server"
    case "audio1":        return "Audio 1"
    case "audio2":        return "Audio 2"
    case "tidal":         return "TIDAL"
    case "qobuz":         return "Qobuz"
    case "deezer":        return "Deezer"
    case "pandora":       return "Pandora"
    case "sirius_xm":     return "SiriusXM"
    case "amazon_music":  return "Amazon Music"
    case "roon":          return "Roon"
    default:
        return input.replacingOccurrences(of: "_", with: " ").capitalized
    }
}
