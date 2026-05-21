import AppKit
import Foundation

// HertzCastHelper — runs as a background Login Item
// Registered by the main app via SMAppService
// Reads scheduling settings from shared App Group UserDefaults
// Fires alarms on wake and every minute

let sharedDefaults = UserDefaults(suiteName: "group.com.danbutuc.hertzcast")!
let baseURLKey     = "yamaha_ip"

// ── Alarm checker ────────────────────────────────────────────────────────

func ip() -> String { sharedDefaults.string(forKey: baseURLKey) ?? "" }
func baseURL() -> String { "http://\(ip())/YamahaExtendedControl/v1" }

func fireGET(_ path: String) {
    guard !ip().isEmpty, let url = URL(string: baseURL() + path) else { return }
    URLSession.shared.dataTask(with: url) { _, _, _ in }.resume()
}

func fireMorningAlarm() {
    let source  = sharedDefaults.string(forKey: "morning_source") ?? "net_radio"
    let preset  = sharedDefaults.integer(forKey: "morning_preset")
    let volume  = sharedDefaults.integer(forKey: "morning_volume")

    if volume > 0 { fireGET("/main/setVolume?volume=\(volume)") }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
        fireGET("/main/setPower?power=on")
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.3) {
        fireGET("/main/setInput?input=\(source)")
    }
    if source == "net_radio" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            fireGET("/netusb/recallPreset?zone=main&num=\(preset)")
        }
    }
}

func fireAutoOff() {
    fireGET("/main/setPower?power=standby")
}

func checkAlarms() {
    let now = Calendar.current.dateComponents([.hour, .minute, .weekday], from: Date())
    guard let hour = now.hour, let minute = now.minute, let weekday = now.weekday else { return }
    let dayIndex = weekday - 1  // Calendar weekday: 1=Sun, converted to 0=Sun

    // Morning Alarm
    if sharedDefaults.bool(forKey: "morning_enabled") {
        let days = sharedDefaults.array(forKey: "morning_weekdays") as? [Int] ?? [0,1,2,3,4,5,6]
        if hour   == sharedDefaults.integer(forKey: "morning_hour") &&
           minute == sharedDefaults.integer(forKey: "morning_minute") &&
           days.contains(dayIndex) {
            fireMorningAlarm()
        }
    }

    // Auto Off
    if sharedDefaults.bool(forKey: "autooff_enabled") {
        let days = sharedDefaults.array(forKey: "autooff_weekdays") as? [Int] ?? [0,1,2,3,4,5,6]
        if hour   == sharedDefaults.integer(forKey: "autooff_hour") &&
           minute == sharedDefaults.integer(forKey: "autooff_minute") &&
           days.contains(dayIndex) {
            fireAutoOff()
        }
    }
}

// ── Wake detection ───────────────────────────────────────────────────────

NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil, queue: .main) { _ in checkAlarms() }

// ── Minute timer ─────────────────────────────────────────────────────────
// Fire at the start of each minute

func scheduleNextMinuteFire() {
    let now = Date()
    let cal = Calendar.current
    guard let nextMinute = cal.nextDate(after: now,
                                        matching: DateComponents(second: 0),
                                        matchingPolicy: .nextTime) else { return }
    let delay = nextMinute.timeIntervalSinceNow
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
        checkAlarms()
        scheduleNextMinuteFire()
    }
}

// Run check immediately on start (handles wake-from-sleep missed alarms)
checkAlarms()
scheduleNextMinuteFire()

// ── Run loop ─────────────────────────────────────────────────────────────

NSApplication.shared.run()
