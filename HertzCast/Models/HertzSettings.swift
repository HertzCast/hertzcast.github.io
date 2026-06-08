import Foundation
import Combine

private let groupID = "group.com.danbutuc.hertzcast"

class HertzSettings: ObservableObject {
    static let shared = HertzSettings()

    // Shared UserDefaults — accessible by both main app and HertzCastHelper
    static let ud: UserDefaults = UserDefaults(suiteName: groupID) ?? .standard

    @Published var ipAddress: String {
        didSet { Self.ud.set(ipAddress, forKey: "yamaha_ip"); rescheduleAll() }
    }
    @Published var morningEnabled: Bool {
        didSet { Self.ud.set(morningEnabled, forKey: "morning_enabled"); reschedule() }
    }
    @Published var morningHour: Int {
        didSet { Self.ud.set(morningHour, forKey: "morning_hour"); reschedule() }
    }
    @Published var morningMinute: Int {
        didSet { Self.ud.set(morningMinute, forKey: "morning_minute"); reschedule() }
    }
    @Published var morningSource: String {
        didSet { Self.ud.set(morningSource, forKey: "morning_source"); reschedule() }
    }
    @Published var morningPreset: Int {
        didSet { Self.ud.set(morningPreset, forKey: "morning_preset"); reschedule() }
    }
    @Published var morningWeekdays: [Int] {
        didSet { Self.ud.set(morningWeekdays, forKey: "morning_weekdays"); reschedule() }
    }
    @Published var morningVolume: Int {
        didSet { Self.ud.set(morningVolume, forKey: "morning_volume"); reschedule() }
    }
    @Published var autoOffEnabled: Bool {
        didSet { Self.ud.set(autoOffEnabled, forKey: "autooff_enabled"); reschedule() }
    }
    @Published var autoOffHour: Int {
        didSet { Self.ud.set(autoOffHour, forKey: "autooff_hour"); reschedule() }
    }
    @Published var autoOffMinute: Int {
        didSet { Self.ud.set(autoOffMinute, forKey: "autooff_minute"); reschedule() }
    }
    @Published var autoOffWeekdays: [Int] {
        didSet { Self.ud.set(autoOffWeekdays, forKey: "autooff_weekdays"); reschedule() }
    }
    @Published var button1Source: String {
        didSet { UserDefaults.standard.set(button1Source, forKey: "button1_source") }
    }
    @Published var button2Source: String {
        didSet { UserDefaults.standard.set(button2Source, forKey: "button2_source") }
    }
    @Published var button3Source: String {
        didSet { UserDefaults.standard.set(button3Source, forKey: "button3_source") }
    }
    @Published var button4Source: String {
        didSet { UserDefaults.standard.set(button4Source, forKey: "button4_source") }
    }
    @Published var colorScheme: String {
        didSet { UserDefaults.standard.set(colorScheme, forKey: "color_scheme") }
    }
    @Published var appTheme: String {
        didSet { UserDefaults.standard.set(appTheme, forKey: "app_theme") }
    }
    var isLight: Bool { appTheme == "light" }
    @Published var hiddenSources: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenSources), forKey: "hidden_sources") }
    }

    private init() {
        let ud  = Self.ud
        let std = UserDefaults.standard
        ipAddress      = ud.string(forKey: "yamaha_ip") ?? ""
        morningEnabled = ud.bool(forKey: "morning_enabled")
        morningHour    = ud.integer(forKey: "morning_hour")
        morningMinute  = ud.integer(forKey: "morning_minute")
        morningSource  = ud.string(forKey: "morning_source") ?? "net_radio"
        let preset     = ud.integer(forKey: "morning_preset")
        morningPreset  = preset == 0 ? 1 : preset
        morningWeekdays = ud.array(forKey: "morning_weekdays") as? [Int] ?? [0,1,2,3,4,5,6]
        let vol         = ud.integer(forKey: "morning_volume")
        morningVolume   = vol == 0 ? 50 : vol
        autoOffEnabled  = ud.bool(forKey: "autooff_enabled")
        autoOffHour     = ud.integer(forKey: "autooff_hour")
        autoOffMinute   = ud.integer(forKey: "autooff_minute")
        autoOffWeekdays = ud.array(forKey: "autooff_weekdays") as? [Int] ?? [0,1,2,3,4,5,6]
        button1Source   = std.string(forKey: "button1_source") ?? "tv"
        button2Source   = std.string(forKey: "button2_source") ?? "hdmi2"
        button3Source   = std.string(forKey: "button3_source") ?? "spotify"
        button4Source   = std.string(forKey: "button4_source") ?? "net_radio"
        colorScheme     = std.string(forKey: "color_scheme") ?? "green"
        appTheme        = std.string(forKey: "app_theme") ?? "dark"
        hiddenSources   = Set(std.array(forKey: "hidden_sources") as? [String] ?? [])

        // Migrate IP from any previous app version (standard UserDefaults or old bundle)
        if ipAddress.isEmpty {
            let legacySuites = [
                "group.com.danbutuc.hertzcast.legacy",
                "group.com.yamaha-controller"
            ]
            let legacyIP = legacySuites.compactMap {
                UserDefaults(suiteName: $0)?.string(forKey: "yamaha_ip")
            }.first(where: { !$0.isEmpty })
            ?? std.string(forKey: "yamaha_ip")

            if let ip = legacyIP, !ip.isEmpty {
                ipAddress = ip
                Self.ud.set(ip, forKey: "yamaha_ip")
            }
        }
    }

    private func reschedule() {
        SchedulerService.shared.scheduleIfNeeded(
            morningEnabled: morningEnabled,
            autoOffEnabled: autoOffEnabled
        )
    }

    private func rescheduleAll() {
        Self.ud.set(ipAddress, forKey: "yamaha_ip")
        reschedule()
    }
}
