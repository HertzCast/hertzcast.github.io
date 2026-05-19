import SwiftUI
import AppKit

struct AboutView: View {
    @ObservedObject private var api = YamahaAPIService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Icon + name + version
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 64, height: 64)

                Text("Yamaha Controller")
                    .font(.title2).bold()

                Text("Version 1.4.0")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Device info
            VStack(spacing: 6) {
                if !api.deviceModel.isEmpty {
                    HStack {
                        Text("Device")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(api.deviceModel)
                            .bold()
                    }
                }
                if !api.deviceFirmware.isEmpty {
                    HStack {
                        Text("Firmware")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(api.deviceFirmware)
                    }
                }
                if api.deviceModel.isEmpty {
                    Text("Receiver not connected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            Spacer()
        }
        .frame(width: 280, height: 230)
        .onAppear { api.fetchDeviceInfo() }
    }
}
