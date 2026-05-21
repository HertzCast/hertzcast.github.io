import SwiftUI

struct AutoOffView: View {
    @ObservedObject private var settings = HertzSettings.shared
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Enable", isOn: $settings.autoOffEnabled)

                if settings.autoOffEnabled {
                    HStack {
                        Text("Time")
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("", selection: $settings.autoOffHour) {
                            ForEach(0..<24, id: \.self) { h in
                                Text(String(format: "%02d", h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu).frame(width: 60)
                        Text(":").foregroundColor(.secondary)
                        Picker("", selection: $settings.autoOffMinute) {
                            ForEach(0..<60, id: \.self) { m in
                                Text(String(format: "%02d", m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu).frame(width: 60)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Days")
                            .foregroundColor(.secondary)
                        HStack(spacing: 4) {
                            let weekdayOrder: [(Int, String)] = [(1,"Mo"),(2,"Tu"),(3,"We"),(4,"Th"),(5,"Fr"),(6,"Sa"),(0,"Su")]
                            ForEach(weekdayOrder, id: \.0) { day, label in
                                let selected = settings.autoOffWeekdays.contains(day)
                                Button {
                                    var days = settings.autoOffWeekdays
                                    if selected { days.removeAll { $0 == day } }
                                    else { days.append(day) }
                                    if !days.isEmpty { settings.autoOffWeekdays = days }
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
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 6) {
                Text("Auto Off")
                    .font(.headline)
                if settings.autoOffEnabled {
                    Circle()
                        .fill(.orange)
                        .frame(width: 7, height: 7)
                }
            }
        }
    }
}
