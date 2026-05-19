import Foundation

class SchedulerService {
    static let shared = SchedulerService()
    private init() {}

    private let morningLabel   = "com.yamaha-controller.morning"
    private let autoOffLabel   = "com.yamaha-controller.poweroff"
    private let launchAgentsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/LaunchAgents")

    private var uid: String { String(getuid()) }

    // MARK: - Morning Alarm

    func scheduleMorningAlarm(hour: Int, minute: Int, ip: String, source: String, preset: Int, weekdays: [Int] = [0,1,2,3,4,5,6], volume: Int = 0) {
        guard !ip.isEmpty else { return }

        let scriptURL = launchAgentsURL.appendingPathComponent("\(morningLabel).sh")
        let plistURL  = launchAgentsURL.appendingPathComponent("\(morningLabel).plist")

        let base = "http://\(ip)/YamahaExtendedControl/v1"
        var script = "#!/bin/bash\n"
        if volume > 0 {
            script += "/usr/bin/curl -s \"\(base)/main/setVolume?volume=\(volume)\"\n"
        }
        script += """
        /usr/bin/curl -s "\(base)/main/setPower?power=on"
        sleep 3
        /usr/bin/curl -s "\(base)/main/setInput?input=\(source)"
        """
        if source == "net_radio" {
            script += """
            \nsleep 2
            /usr/bin/curl -s "\(base)/netusb/recallPreset?zone=main&num=\(preset)"
            """
        }
        script += "\n"

        let plist = buildPlist(
            label: morningLabel,
            programArgs: ["/bin/bash", scriptURL.path],
            hour: hour,
            minute: minute,
            weekdays: weekdays
        )

        do {
            try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)
            unloadAgent(label: morningLabel, plistURL: plistURL)
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            bootstrapAgent(plistURL: plistURL)
        } catch {
            print("[Scheduler] Morning alarm write error: \(error)")
        }
    }

    func unscheduleMorningAlarm() {
        let plistURL  = launchAgentsURL.appendingPathComponent("\(morningLabel).plist")
        let scriptURL = launchAgentsURL.appendingPathComponent("\(morningLabel).sh")
        unloadAgent(label: morningLabel, plistURL: plistURL)
        try? FileManager.default.removeItem(at: plistURL)
        try? FileManager.default.removeItem(at: scriptURL)
    }

    // MARK: - Auto Off

    func scheduleAutoOff(hour: Int, minute: Int, ip: String, weekdays: [Int] = [0,1,2,3,4,5,6]) {
        guard !ip.isEmpty else { return }

        let plistURL = launchAgentsURL.appendingPathComponent("\(autoOffLabel).plist")
        let base = "http://\(ip)/YamahaExtendedControl/v1"
        let plist = buildPlist(
            label: autoOffLabel,
            programArgs: ["/usr/bin/curl", "-s", "\(base)/main/setPower?power=standby"],
            hour: hour,
            minute: minute,
            weekdays: weekdays
        )

        do {
            try FileManager.default.createDirectory(at: launchAgentsURL, withIntermediateDirectories: true)
            unloadAgent(label: autoOffLabel, plistURL: plistURL)
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            bootstrapAgent(plistURL: plistURL)
        } catch {
            print("[Scheduler] Auto off write error: \(error)")
        }
    }

    func unscheduleAutoOff() {
        let plistURL = launchAgentsURL.appendingPathComponent("\(autoOffLabel).plist")
        unloadAgent(label: autoOffLabel, plistURL: plistURL)
        try? FileManager.default.removeItem(at: plistURL)
    }

    // MARK: - launchctl helpers

    private func bootstrapAgent(plistURL: URL) {
        run("/bin/launchctl", args: ["bootstrap", "gui/\(uid)", plistURL.path])
    }

    private func unloadAgent(label: String, plistURL: URL) {
        // Try modern bootout first, fall back to legacy unload
        let result = run("/bin/launchctl", args: ["bootout", "gui/\(uid)/\(label)"])
        if result != 0 {
            _ = run("/bin/launchctl", args: ["unload", plistURL.path])
        }
    }

    @discardableResult
    private func run(_ executable: String, args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError  = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus
    }

    // MARK: - plist builder

    private func buildPlist(label: String, programArgs: [String], hour: Int, minute: Int, weekdays: [Int] = []) -> String {
        let argsXML = programArgs.map { "        <string>\($0)</string>" }.joined(separator: "\n")

        // If all 7 days or no filter → fire every day (no Weekday key)
        let allDays = weekdays.isEmpty || weekdays.count == 7
        let calendarInterval: String
        if allDays {
            calendarInterval = """
                <key>StartCalendarInterval</key>
                <dict>
                    <key>Hour</key>
                    <integer>\(hour)</integer>
                    <key>Minute</key>
                    <integer>\(minute)</integer>
                </dict>
            """
        } else {
            let entries = weekdays.sorted().map { day in
                """
                    <dict>
                        <key>Hour</key>
                        <integer>\(hour)</integer>
                        <key>Minute</key>
                        <integer>\(minute)</integer>
                        <key>Weekday</key>
                        <integer>\(day)</integer>
                    </dict>
                """
            }.joined(separator: "\n")
            calendarInterval = """
                <key>StartCalendarInterval</key>
                <array>
            \(entries)
                </array>
            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
        \(argsXML)
            </array>
        \(calendarInterval)
            <key>RunAtLoad</key>
            <false/>
        </dict>
        </plist>
        """
    }
}
