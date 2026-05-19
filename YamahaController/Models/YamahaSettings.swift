import Foundation
import Combine

class YamahaSettings: ObservableObject {
    static let shared = YamahaSettings()

    @Published var ipAddress: String {
        didSet { UserDefaults.standard.set(ipAddress, forKey: "yamaha_ip"); rescheduleAll() }
    }
    @Published var morningEnabled: Bool {
        didSet { UserDefaults.standard.set(morningEnabled, forKey: "morning_enabled"); scheduleMorning() }
    }
    @Published var morningHour: Int {
        didSet { UserDefaults.standard.set(morningHour, forKey: "morning_hour"); scheduleMorning() }
    }
    @Published var morningMinute: Int {
        didSet { UserDefaults.standard.set(morningMinute, forKey: "morning_minute"); scheduleMorning() }
    }
    @Published var morningSource: String {
        didSet { UserDefaults.standard.set(morningSource, forKey: "morning_source"); scheduleMorning() }
    }
    @Published var morningPreset: Int {
        didSet { UserDefaults.standard.set(morningPreset, forKey: "morning_preset"); scheduleMorning() }
    }
    @Published var morningWeekdays: [Int] {
        didSet { UserDefaults.standard.set(morningWeekdays, forKey: "morning_weekdays"); scheduleMorning() }
    }
    @Published var morningVolume: Int {
        didSet { UserDefaults.standard.set(morningVolume, forKey: "morning_volume"); scheduleMorning() }
    }
    @Published var autoOffEnabled: Bool {
        didSet { UserDefaults.standard.set(autoOffEnabled, forKey: "autooff_enabled"); scheduleAutoOff() }
    }
    @Published var autoOffHour: Int {
        didSet { UserDefaults.standard.set(autoOffHour, forKey: "autooff_hour"); scheduleAutoOff() }
    }
    @Published var autoOffMinute: Int {
        didSet { UserDefaults.standard.set(autoOffMinute, forKey: "autooff_minute"); scheduleAutoOff() }
    }
    @Published var autoOffWeekdays: [Int] {
        didSet { UserDefaults.standard.set(autoOffWeekdays, forKey: "autooff_weekdays"); scheduleAutoOff() }
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
    @Published var hiddenSources: Set<String> {
        didSet { UserDefaults.standard.set(Array(hiddenSources), forKey: "hidden_sources") }
    }

    private init() {
        let ud = UserDefaults.standard
        ipAddress    = ud.string(forKey: "yamaha_ip") ?? "192.168.178.65"
        morningEnabled = ud.bool(forKey: "morning_enabled")
        morningHour    = ud.integer(forKey: "morning_hour")
        morningMinute  = ud.integer(forKey: "morning_minute")
        morningSource  = ud.string(forKey: "morning_source") ?? "net_radio"
        let preset     = ud.integer(forKey: "morning_preset")
        morningPreset  = preset == 0 ? 1 : preset
        let savedDays  = ud.array(forKey: "morning_weekdays") as? [Int]
        morningWeekdays = savedDays ?? [0,1,2,3,4,5,6]
        let vol = ud.integer(forKey: "morning_volume")
        morningVolume = vol == 0 ? 50 : vol
        autoOffEnabled  = ud.bool(forKey: "autooff_enabled")
        autoOffHour     = ud.integer(forKey: "autooff_hour")
        autoOffMinute   = ud.integer(forKey: "autooff_minute")
        let savedOffDays = ud.array(forKey: "autooff_weekdays") as? [Int]
        autoOffWeekdays  = savedOffDays ?? [0,1,2,3,4,5,6]
        button1Source   = ud.string(forKey: "button1_source") ?? "tv"
        button2Source   = ud.string(forKey: "button2_source") ?? "hdmi2"
        button3Source   = ud.string(forKey: "button3_source") ?? "spotify"
        button4Source   = ud.string(forKey: "button4_source") ?? "net_radio"
        colorScheme     = ud.string(forKey: "color_scheme") ?? "green"
        hiddenSources   = Set(ud.array(forKey: "hidden_sources") as? [String] ?? [])
    }

    private func scheduleMorning() {
        if morningEnabled {
            SchedulerService.shared.scheduleMorningAlarm(
                hour: morningHour, minute: morningMinute,
                ip: ipAddress, source: morningSource, preset: morningPreset,
                weekdays: morningWeekdays, volume: morningVolume
            )
        } else {
            SchedulerService.shared.unscheduleMorningAlarm()
        }
    }

    private func scheduleAutoOff() {
        if autoOffEnabled {
            SchedulerService.shared.scheduleAutoOff(
                hour: autoOffHour, minute: autoOffMinute,
                ip: ipAddress, weekdays: autoOffWeekdays
            )
        } else {
            SchedulerService.shared.unscheduleAutoOff()
        }
    }

    private func rescheduleAll() {
        scheduleMorning()
        scheduleAutoOff()
    }
}
