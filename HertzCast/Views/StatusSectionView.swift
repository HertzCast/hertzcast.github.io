import SwiftUI

struct StatusSectionView: View {
    @ObservedObject private var api = HertzAPIService.shared
    @ObservedObject private var settings = HertzSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Status")
                    .font(.headline)
                Spacer()
                Button {
                    api.fetchStatus()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(api.isLoading)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                Text(statusLabel)
                    .foregroundColor(.secondary)
            }

            if let error = api.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var dotColor: Color {
        switch api.powerState {
        case .on:      return settings.schemeColor
        case .standby: return .gray
        case .unknown: return .orange
        }
    }

    private var statusLabel: String {
        switch api.powerState {
        case .on:      return "On"
        case .standby: return "Standby"
        case .unknown: return "Unreachable"
        }
    }
}
