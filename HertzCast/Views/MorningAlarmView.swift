import SwiftUI

struct MorningAlarmView: View {
    @ObservedObject private var settings = HertzSettings.shared
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable", isOn: $settings.morningEnabled)

                if settings.morningEnabled {
                    HStack {
                        Text("Time")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $settings.morningHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu).frame(width: 60)
                        Text(":").foregroundColor(.secondary)
                        Picker("", selection: $settings.morningMinute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu).frame(width: 60)
                    }

                    // Day-of-week selector
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Days")
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            let weekdayOrder: [(Int, String)] = [(1,"Mo"),(2,"Tu"),(3,"We"),(4,"Th"),(5,"Fr"),(6,"Sa"),(0,"Su")]
                            ForEach(weekdayOrder, id: \.0) { day, label in
                                let selected = settings.morningWeekdays.contains(day)
                                Button {
                                    var days = settings.morningWeekdays
                                    if selected { days.removeAll { $0 == day } }
                                    else { days.append(day) }
                                    if !days.isEmpty { settings.morningWeekdays = days }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .frame(width: 28, height: 22)
                                        .background(selected ? Color.accentColor : Color(white: 0.18))
                                        .foregroundColor(selected ? .white : .secondary)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack {
                        Text("Source")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $settings.morningSource) {
                            ForEach(HertzAPIService.allSources, id: \.value) { s in
                                Text(s.label).tag(s.value)
                            }
                        }
                        .pickerStyle(.menu).frame(width: 140)
                    }

                    HStack {
                        Text("Volume")
                            .foregroundColor(.secondary)
                        Spacer()
                        Slider(value: Binding(
                            get: { Double(settings.morningVolume) },
                            set: { settings.morningVolume = Int($0) }
                        ), in: 1...Double(HertzAPIService.shared.maxVolume), step: 1)
                        .frame(width: 100)
                        Text("\(settings.morningVolume)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }

                    if settings.morningSource == "net_radio" {
                        HStack {
                            Text("Preset")
                                .foregroundColor(.secondary)
                            Spacer()
                            Picker("", selection: $settings.morningPreset) {
                                ForEach(1...5, id: \.self) { p in
                                    Text("Preset \(p)").tag(p)
                                }
                            }
                            .pickerStyle(.menu).frame(width: 120)
                        }
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Text("Morning Alarm")
                    .font(.headline)
                if settings.morningEnabled {
                    Circle()
                        .fill(settings.schemeColor)
                        .frame(width: 7, height: 7)
                }
            }
        }
    }
}
