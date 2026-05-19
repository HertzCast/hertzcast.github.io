import Foundation
import Combine
import Network
import UserNotifications

enum PowerState: Equatable {
    case on
    case standby
    case unknown
}

class YamahaAPIService: ObservableObject {
    static let shared = YamahaAPIService()

    @Published var powerState: PowerState = .unknown
    @Published var isLoading: Bool = false
    @Published var lastError: String? = nil
    @Published var currentInput: String = ""
    @Published var volume: Int = 0
    @Published var maxVolume: Int = 100
    @Published var soundProgram: String = ""
    @Published var isMuted: Bool = false
    @Published var actualVolumeDb: Double? = nil
    private var volumeDbBase: Double? = nil   // actualVolumeDb - volume * 0.5, calibrated on first poll
    @Published var nowPlayingTrack: String = ""
    @Published var nowPlayingArtist: String = ""
    @Published var albumArtURLString: String = ""
    @Published var tunerBand: String = "fm"
    @Published var soundProgramList: [String] = []
    @Published var currentNetPreset: Int = 1
    @Published var activeScene: Int? = {
        UserDefaults.standard.object(forKey: "active_scene") as? Int
    }()
    @Published var playbackStatus: String = ""
    @Published var shuffleMode: String = "off"
    @Published var repeatMode: String = "off"
    @Published var shuffleAvailable: Bool = false
    @Published var repeatAvailable: [String] = []
    @Published var audioFormat: String = ""
    @Published var playTime: Int = 0
    @Published var totalTime: Int = 0
    @Published var audioChannels: String = ""
    @Published var audioBitrate: Int = 0
    @Published var audioBitDepth: String = ""
    @Published var deviceModel: String = ""
    @Published var deviceFirmware: String = ""
    @Published var sleepTimer: Int = 0

    // Zone 2
    @Published var zone2Power: PowerState = .unknown
    @Published var zone2Volume: Int = 0
    @Published var zone2MaxVolume: Int = 161
    @Published var zone2IsMuted: Bool = false
    @Published var zone2Input: String = ""
    @Published var zone2ActualVolumeDb: Double? = nil

    // Music Center
    @Published var recentItems: [NetRadioRecentItem] = []
    @Published var presetItems: [NetRadioPreset] = []
    @Published var availableInputs: [String] = []

    // Audio settings
    @Published var pureDirectMode: Bool = false
    @Published var enhancerMode: Bool = false
    @Published var extraBassMode: Bool = false
    @Published var adaptiveDRC: Bool = false
    @Published var toneControlBass: Int = 0
    @Published var toneControlTreble: Int = 0
    @Published var subwooferVolume: Int = 0
    @Published var dialogueLevel: Int = 0
    @Published var surroundDecoderType: String = ""

    private var shuffleRepeatFrozenUntil: Date? = nil

    private var pollingTimer: Timer?
    private var playInfoTimer: Timer?
    private var zone2Timer: Timer?
    private var previousState: PowerState = .unknown
    private var isFetchingStatus = false
    private var udpListener: NWListener?
    private var udpDebounce: DispatchWorkItem?

    // URLSession with X-AppName / X-AppPort headers so the receiver
    // knows to send UDP unicast notifications back to us on port 41100
    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpAdditionalHeaders = ["X-AppName": "YamahaController", "X-AppPort": "41100"]
        return URLSession(configuration: cfg)
    }()

    private init() {}

    private var baseURL: String {
        "http://\(YamahaSettings.shared.ipAddress)/YamahaExtendedControl/v1"
    }

    // MARK: - Polling

    func startPolling() {
        startUDPListener()
        fetchStatus()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.fetchStatus()
        }
        playInfoTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.fetchPlayInfoIfNeeded()
        }
        fetchDeviceInfo()
        fetchZone2Status()
        zone2Timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.fetchZone2Status()
        }
    }

    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        playInfoTimer?.invalidate()
        playInfoTimer = nil
        zone2Timer?.invalidate()
        zone2Timer = nil
        stopUDPListener()
    }

    // MARK: - UDP Event Listener (port 41100)

    private func startUDPListener() {
        stopUDPListener()
        guard let listener = try? NWListener(using: .udp, on: 41100) else { return }
        udpListener = listener
        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global(qos: .utility))
            self?.receiveUDP(on: conn)
        }
        listener.start(queue: .global(qos: .utility))
    }

    private func stopUDPListener() {
        udpListener?.cancel()
        udpListener = nil
    }

    private func receiveUDP(on conn: NWConnection) {
        conn.receiveMessage { [weak self] data, _, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            self.handleUDPEvent(json)
        }
    }

    private func handleUDPEvent(_ json: [String: Any]) {
        let features = json["features_changed"] as? [String] ?? []
        let hasMain   = features.isEmpty || features.contains("main")   || json["main"]   != nil
        let hasNetusb = features.contains("netusb") || json["netusb"] != nil
        let hasTuner  = features.contains("tuner")  || json["tuner"]  != nil

        udpDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if hasMain   { self.fetchStatus() }
            if hasNetusb { self.fetchPlayInfoIfNeeded() }
            if hasTuner  { self.fetchTunerInfoIfNeeded() }
        }
        udpDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func fetchStatus() {
        guard !isFetchingStatus else { return }
        isFetchingStatus = true
        guard !YamahaSettings.shared.ipAddress.isEmpty else {
            DispatchQueue.main.async {
                self.powerState = .unknown
                self.lastError = "No IP address configured."
            }
            return
        }
        guard let url = URL(string: "\(baseURL)/main/getStatus") else { return }

        session.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            DispatchQueue.main.async {
                defer { self.isFetchingStatus = false }
                if let error = error {
                    self.powerState = .unknown
                    self.lastError = error.localizedDescription
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let power = json["power"] as? String else {
                    self.powerState = .unknown
                    self.lastError = "Unexpected response from receiver."
                    return
                }
                self.lastError = nil
                let newState: PowerState = power == "on" ? .on : .standby

                if self.previousState != .unknown && self.previousState != newState {
                    self.sendTransitionNotification(newState: newState)
                }
                self.previousState = newState
                self.powerState = newState

                // Current input source
                if let input = json["input"] as? String {
                    self.currentInput = input
                    if newState == .on {
                        UserDefaults.standard.set(input, forKey: "last_input")
                    }
                }

                // Volume
                if let vol = json["volume"] as? Int { self.volume = vol }
                if let maxVol = json["max_volume"] as? Int { self.maxVolume = maxVol }
                if let mute = json["mute"] as? Bool { self.isMuted = mute }

                // Actual volume in dB (e.g. -30.5)
                if let av = json["actual_volume"] as? [String: Any],
                   let val = av["value"] as? Double {
                    self.actualVolumeDb = val
                    self.volumeDbBase = val - Double(self.volume) * 0.5
                } else if let val = json["actual_volume"] as? Double {
                    self.actualVolumeDb = val
                    self.volumeDbBase = val - Double(self.volume) * 0.5
                }

                // Sleep timer
                if let sl = json["sleep"] as? Int { self.sleepTimer = sl }

                // Sound program (DSP mode)
                if let sp = json["sound_program"] as? String { self.soundProgram = sp }
                if let sdt = json["surr_decoder_type"] as? String { self.surroundDecoderType = sdt }

                // Audio controls
                if let pd  = json["pure_direct"]   as? Bool { self.pureDirectMode = pd }
                if let enh = json["enhancer"]       as? Bool { self.enhancerMode   = enh }
                if let eb  = json["extra_bass"]     as? Bool { self.extraBassMode  = eb }
                if let adr = json["adaptive_drc"]   as? Bool { self.adaptiveDRC    = adr }
                if let dl  = json["dialogue_level"] as? Int  { self.dialogueLevel  = dl }
                if let sv  = json["subwoofer_volume"] as? Int { self.subwooferVolume = sv }
                if let tc  = json["tone_control"]   as? [String: Any] {
                    if let b = tc["bass"]   as? Int { self.toneControlBass   = b }
                    if let t = tc["treble"] as? Int { self.toneControlTreble = t }
                }

                // Active scene — clear on standby, keep persisted value on "on"
                if newState == .standby {
                    self.setActiveScene(nil)
                    self.nowPlayingTrack = ""
                    self.nowPlayingArtist = ""
                    self.albumArtURLString = ""
                    self.playbackStatus = ""
                    self.shuffleMode = "off"
                    self.repeatMode = "off"
                    self.audioFormat = ""
                    self.audioChannels = ""
                    self.audioBitrate = 0
                    self.audioBitDepth = ""
                } else {
                    self.fetchPlayInfoIfNeeded()
                    self.fetchTunerInfoIfNeeded()
                    self.fetchSignalInfo()
                }
            }
        }.resume()
    }

    // MARK: - Commands

    func setPower(_ state: String, completion: @escaping (Error?) -> Void) {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/main/setPower?power=\(state)") else {
            completion(URLError(.badURL))
            return
        }
        session.dataTask(with: url) { _, _, error in
            DispatchQueue.main.async { completion(error) }
        }.resume()
    }

    func setInput(_ input: String, completion: @escaping (Error?) -> Void) {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/main/setInput?input=\(input)") else {
            completion(URLError(.badURL))
            return
        }
        let previous = currentInput
        currentInput = input
        nowPlayingTrack = ""
        nowPlayingArtist = ""
        albumArtURLString = ""
        session.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if error != nil {
                    self?.currentInput = previous
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self?.fetchPlayInfoIfNeeded()
                    }
                }
                completion(error)
            }
        }.resume()
    }

    func setVolume(_ value: Int, completion: @escaping (Error?) -> Void) {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/main/setVolume?volume=\(value)") else {
            completion(URLError(.badURL))
            return
        }
        let previous = volume
        let previousDb = actualVolumeDb
        volume = value
        if let base = volumeDbBase { actualVolumeDb = base + Double(value) * 0.5 }
        session.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if error != nil {
                    self?.volume = previous
                    self?.actualVolumeDb = previousDb
                }
                completion(error)
            }
        }.resume()
    }

    func recallPreset(_ preset: Int, completion: @escaping (Error?) -> Void) {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/netusb/recallPreset?zone=main&num=\(preset)") else {
            completion(URLError(.badURL))
            return
        }
        session.dataTask(with: url) { _, _, error in
            DispatchQueue.main.async { completion(error) }
        }.resume()
    }

    func recallScene(_ num: Int) {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/main/recallScene?num=\(num)") else { return }
        setActiveScene(num)
        session.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async {
                if error != nil { self?.setActiveScene(nil) }
            }
        }.resume()
    }

    // MARK: - Transport / Tuner Commands

    func setPlayback(_ playback: String) {
        guard let url = URL(string: "\(baseURL)/netusb/setPlayback?playback=\(playback)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func fetchSoundProgramList(completion: @escaping () -> Void = {}) {
        guard !soundProgramList.isEmpty else {
            guard let url = URL(string: "\(baseURL)/main/getSoundProgramList") else { completion(); return }
            session.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let list = json["sound_program_list"] as? [String] else {
                    DispatchQueue.main.async { completion() }
                    return
                }
                DispatchQueue.main.async {
                    self.soundProgramList = list
                    completion()
                }
            }.resume()
            return
        }
        completion()
    }

    func cycleSoundProgram() {
        fetchSoundProgramList { [weak self] in
            guard let self, !self.soundProgramList.isEmpty else { return }
            let current = self.soundProgram
            let idx = self.soundProgramList.firstIndex(of: current) ?? -1
            let next = self.soundProgramList[(idx + 1) % self.soundProgramList.count]
            guard let url = URL(string: "\(self.baseURL)/main/setSoundProgram?program=\(next.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? next)") else { return }
            session.dataTask(with: url) { [weak self] _, _, error in
                if error == nil {
                    DispatchQueue.main.async { self?.soundProgram = next }
                }
            }.resume()
        }
    }

    func setBand(_ band: String) {
        guard let url = URL(string: "\(baseURL)/tuner/setBand?band=\(band)") else { return }
        tunerBand = band
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func tuneStep(_ dir: String) {
        guard let url = URL(string: "\(baseURL)/tuner/setFreq?band=\(tunerBand)&tuning=\(dir)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func switchTunerPreset(_ dir: String) {
        guard let url = URL(string: "\(baseURL)/tuner/switchPreset?zone=main&dir=\(dir)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func toggleShuffle() {
        guard let url = URL(string: "\(baseURL)/netusb/toggleShuffle") else { return }
        shuffleRepeatFrozenUntil = Date().addingTimeInterval(4)
        session.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil { self.shuffleRepeatFrozenUntil = nil; return }
                if let data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["response_code"] as? Int, code == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.shuffleRepeatFrozenUntil = nil
                        self.fetchPlayInfoIfNeeded()
                    }
                } else {
                    self.shuffleRepeatFrozenUntil = nil
                }
            }
        }.resume()
    }

    func cycleRepeat() {
        guard let url = URL(string: "\(baseURL)/netusb/toggleRepeat") else { return }
        shuffleRepeatFrozenUntil = Date().addingTimeInterval(4)
        session.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil { self.shuffleRepeatFrozenUntil = nil; return }
                if let data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let code = json["response_code"] as? Int, code == 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.shuffleRepeatFrozenUntil = nil
                        self.fetchPlayInfoIfNeeded()
                    }
                } else {
                    self.shuffleRepeatFrozenUntil = nil
                }
            }
        }.resume()
    }

    func nextNetPreset() {
        currentNetPreset = (currentNetPreset % 5) + 1
        recallPreset(currentNetPreset) { _ in }
    }

    func prevNetPreset() {
        currentNetPreset = currentNetPreset == 1 ? 5 : currentNetPreset - 1
        recallPreset(currentNetPreset) { _ in }
    }

    // MARK: - Volume / Mute Helpers

    func volumeUp()   { setVolume(min(volume + 1, maxVolume)) { _ in } }
    func volumeDown() { setVolume(max(volume - 1, 0))         { _ in } }

    func toggleMute() {
        let enable = !isMuted
        guard let url = URL(string: "\(baseURL)/main/setMute?enable=\(enable)") else { return }
        isMuted = enable
        session.dataTask(with: url) { [weak self] _, _, error in
            DispatchQueue.main.async { if error != nil { self?.isMuted = !enable } }
        }.resume()
    }

    // MARK: - Audio settings

    func setPureDirect(_ enabled: Bool) {
        guard let url = URL(string: "\(baseURL)/main/setPureDirect?enable=\(enabled)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.pureDirectMode = enabled } }
        }.resume()
    }

    func setEnhancer(_ enabled: Bool) {
        guard let url = URL(string: "\(baseURL)/main/setEnhancer?enable=\(enabled)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.enhancerMode = enabled } }
        }.resume()
    }

    func setExtraBass(_ enabled: Bool) {
        guard let url = URL(string: "\(baseURL)/main/setExtraBass?enable=\(enabled)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.extraBassMode = enabled } }
        }.resume()
    }

    func setAdaptiveDRC(_ enabled: Bool) {
        guard let url = URL(string: "\(baseURL)/main/setAdaptiveDrc?enable=\(enabled)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.adaptiveDRC = enabled } }
        }.resume()
    }

    func setToneControl(bass: Int, treble: Int) {
        guard let url = URL(string: "\(baseURL)/main/setToneControl?mode=manual&bass=\(bass)&treble=\(treble)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil {
                DispatchQueue.main.async {
                    self?.toneControlBass = bass
                    self?.toneControlTreble = treble
                }
            }
        }.resume()
    }

    func setSubwooferVolume(_ value: Int) {
        guard let url = URL(string: "\(baseURL)/main/setSubwooferVolume?volume=\(value)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.subwooferVolume = value } }
        }.resume()
    }

    func setDialogueLevel(_ value: Int) {
        dialogueLevel = value
        guard let url = URL(string: "\(baseURL)/main/setDialogueLevel?value=\(value)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func setSoundProgram(_ program: String) {
        guard let enc = program.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/main/setSoundProgram?program=\(enc)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.soundProgram = program } }
        }.resume()
    }

    // MARK: - Zone 2

    func fetchZone2Status() {
        guard !YamahaSettings.shared.ipAddress.isEmpty,
              let url = URL(string: "\(baseURL)/zone2/getStatus") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["response_code"] as? Int) == 0 else { return }
            DispatchQueue.main.async {
                self.zone2Power = (json["power"] as? String) == "on" ? .on : .standby
                if let v = json["volume"]     as? Int { self.zone2Volume    = v }
                if let m = json["max_volume"] as? Int { self.zone2MaxVolume = m }
                if let mu = json["mute"]      as? Bool { self.zone2IsMuted  = mu }
                if let inp = json["input"]    as? String { self.zone2Input  = inp }
                if let av = json["actual_volume"] as? [String: Any],
                   let val = av["value"] as? Double { self.zone2ActualVolumeDb = val }
            }
        }.resume()
    }

    func setZone2Power(_ on: Bool) {
        let power = on ? "on" : "standby"
        guard let url = URL(string: "\(baseURL)/zone2/setPower?power=\(power)") else { return }
        zone2Power = on ? .on : .standby
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func setZone2Volume(_ value: Int) {
        let v = max(0, min(value, zone2MaxVolume))
        zone2Volume = v
        guard let url = URL(string: "\(baseURL)/zone2/setVolume?volume=\(v)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func zone2VolumeUp()   { setZone2Volume(zone2Volume + 1) }
    func zone2VolumeDown() { setZone2Volume(zone2Volume - 1) }

    func toggleZone2Mute() {
        let newMute = !zone2IsMuted
        zone2IsMuted = newMute
        guard let url = URL(string: "\(baseURL)/zone2/setMute?enable=\(newMute)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func setZone2Input(_ input: String) {
        guard let enc = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/zone2/setInput?input=\(enc)") else { return }
        zone2Input = input
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    private func prefetchArtwork(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let req = URLRequest(url: url)
        guard URLCache.shared.cachedResponse(for: req) == nil else { return }
        URLSession.shared.dataTask(with: req) { data, response, _ in
            guard let data, let response else { return }
            URLCache.shared.storeCachedResponse(
                CachedURLResponse(response: response, data: data), for: req)
        }.resume()
    }

    func setSleep(_ minutes: Int) {
        sleepTimer = minutes
        guard let url = URL(string: "\(baseURL)/main/setSleep?sleep=\(minutes)") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func reboot() {
        guard let url = URL(string: "\(baseURL)/system/reboot") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        session.dataTask(with: request) { _, _, _ in }.resume()
    }

    // MARK: - Music Center

    func fetchRecentInfo() {
        guard let url = URL(string: "\(baseURL)/netusb/getRecentInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["recent_info"] as? [[String: Any]] else { return }
            DispatchQueue.main.async {
                self.recentItems = Array(list.enumerated().compactMap { idx, item in
                    let inputId = item["input"] as? String ?? "unknown"
                    guard inputId != "unknown" else { return nil }
                    let text   = item["text"] as? String ?? ""
                    let artURL = item["albumart_url"] as? String ?? ""
                    return NetRadioRecentItem(id: idx, text: text, albumArtURL: artURL)
                }.prefix(9))
            }
        }.resume()
    }

    func fetchPresetInfo() {
        guard let url = URL(string: "\(baseURL)/netusb/getPresetInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let list = json["preset_info"] as? [[String: Any]] else { return }
            DispatchQueue.main.async {
                self.presetItems = list.enumerated().compactMap { idx, item in
                    let inputId = item["input"] as? String ?? "unknown"
                    let text    = item["text"]  as? String ?? ""
                    guard inputId != "unknown",
                          !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
                    return NetRadioPreset(id: idx + 1, text: text)
                }
            }
        }.resume()
    }

    func fetchFuncStatus() {
        guard let url = URL(string: "\(baseURL)/system/getFuncStatus") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let inputList = json["input_list"] as? [[String: Any]] {
                    let ids = inputList.compactMap { $0["id"] as? String }
                    if !ids.isEmpty {
                        self.availableInputs = ids
                        return
                    }
                }
                self.availableInputs = YamahaAPIService.allSources.map { $0.value }
            }
        }.resume()
    }

    func recallRecentItem(_ num: Int) {
        guard let url = URL(string: "\(baseURL)/netusb/recallRecentItem?num=\(num)&zone=main") else { return }
        session.dataTask(with: url) { _, _, _ in }.resume()
    }

    func playPresetInMusicCenter(_ num: Int) {
        let wasOnNetRadio = currentInput.lowercased() == "net_radio"
        if wasOnNetRadio {
            recallPreset(num) { _ in }
        } else {
            setInput("net_radio") { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self?.recallPreset(num) { _ in }
                }
            }
        }
    }

    func setSurroundDecoderType(_ type: String) {
        guard let enc = type.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/main/setSurroundDecoderType?type=\(enc)") else { return }
        session.dataTask(with: url) { [weak self] _, _, error in
            if error == nil { DispatchQueue.main.async { self?.surroundDecoderType = type } }
        }.resume()
    }

    // MARK: - Helpers

    private func setActiveScene(_ scene: Int?) {
        activeScene = scene
        if let scene {
            UserDefaults.standard.set(scene, forKey: "active_scene")
        } else {
            UserDefaults.standard.removeObject(forKey: "active_scene")
        }
    }

    // Full source list — shared across Morning Alarm, Settings, and button config
    static let allSources: [(label: String, value: String)] = [
        ("TV (HDMI ARC)", "tv"),
        ("HDMI 1",        "hdmi1"),
        ("HDMI 2",        "hdmi2"),
        ("HDMI 3",        "hdmi3"),
        ("HDMI 4",        "hdmi4"),
        ("HDMI 5",        "hdmi5"),
        ("HDMI 6",        "hdmi6"),
        ("Net Radio",     "net_radio"),
        ("Spotify",       "spotify"),
        ("SiriusXM",      "sirius_xm"),
        ("Pandora",       "pandora"),
        ("Qobuz",         "qobuz"),
        ("TIDAL",         "tidal"),
        ("Deezer",        "deezer"),
        ("Amazon Music",  "amazon_music"),
        ("Roon",          "roon"),
        ("Bluetooth",     "bluetooth"),
        ("AirPlay",       "airplay"),
        ("FM Tuner",      "tuner"),
        ("Server",        "server"),
        ("USB",           "usb"),
        ("Audio 1",       "audio1"),
        ("Audio 2",       "audio2"),
        ("AV 1",          "av1"),
        ("AV 2",          "av2"),
    ]

    // Short label for keycap buttons
    static func buttonLabel(_ input: String) -> String {
        switch input.lowercased() {
        case "tv":        return "TV"
        case "hdmi1":     return "HDMI1"
        case "hdmi2":     return "HDMI2"
        case "hdmi3":     return "HDMI3"
        case "hdmi4":     return "HDMI4"
        case "hdmi5":     return "HDMI5"
        case "hdmi6":     return "HDMI6"
        case "net_radio":     return "RADIO"
        case "spotify":       return "SPOTIFY"
        case "sirius_xm":     return "SIRIUS"
        case "pandora":       return "PANDORA"
        case "qobuz":         return "QOBUZ"
        case "tidal":         return "TIDAL"
        case "deezer":        return "DEEZER"
        case "amazon_music":  return "AMAZON"
        case "roon":          return "ROON"
        case "bluetooth":     return "BT"
        case "airplay":   return "APLAY"
        case "tuner":     return "TUNER"
        case "server":    return "SERVER"
        case "usb":       return "USB"
        case "audio1":    return "AUD 1"
        case "audio2":    return "AUD 2"
        case "av1":       return "AV 1"
        case "av2":       return "AV 2"
        default:          return String(input.uppercased().prefix(6))
        }
    }

    static func formatInput(_ raw: String) -> String {
        switch raw.lowercased() {
        case "hdmi1":      return "HDMI 1"
        case "hdmi2":      return "HDMI 2"
        case "hdmi3":      return "HDMI 3"
        case "hdmi4":      return "HDMI 4"
        case "hdmi5":      return "HDMI 5"
        case "hdmi6":      return "HDMI 6"
        case "av1":        return "AV 1"
        case "av2":        return "AV 2"
        case "av3":        return "AV 3"
        case "audio1":     return "Audio 1"
        case "audio2":     return "Audio 2"
        case "audio3":     return "Audio 3"
        case "audio4":     return "Audio 4"
        case "optical1":   return "Optical 1"
        case "optical2":   return "Optical 2"
        case "coaxial1":   return "Coaxial 1"
        case "coaxial2":   return "Coaxial 2"
        case "net_radio":    return "Net Radio"
        case "tuner":        return "Tuner"
        case "bluetooth":    return "Bluetooth"
        case "airplay":      return "AirPlay"
        case "spotify":      return "Spotify"
        case "sirius_xm":    return "SiriusXM"
        case "pandora":      return "Pandora"
        case "qobuz":        return "Qobuz"
        case "tidal":        return "TIDAL"
        case "deezer":       return "Deezer"
        case "amazon_music": return "Amazon Music"
        case "roon":         return "Roon"
        case "server":       return "Server"
        case "usb":          return "USB"
        case "tv":           return "TV"
        case "multi_ch":   return "Multi Ch"
        default:
            return raw.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Play Info

    func fetchPlayInfoIfNeeded() {
        let input = currentInput.lowercased()
        guard powerState == .on,
              input == "net_radio" || input == "spotify" else {
            nowPlayingTrack = ""
            nowPlayingArtist = ""
            albumArtURLString = ""
            playTime = 0
            totalTime = 0
            if powerState == .on && currentInput.lowercased() == "tuner" {
                fetchTunerInfoIfNeeded()
            }
            return
        }
        guard let url = URL(string: "\(baseURL)/netusb/getPlayInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                let track  = json["track"]  as? String ?? ""
                let artist = json["artist"] as? String ?? ""
                // Only update if receiver returned meaningful data — avoids
                // briefly wiping track/artist during Spotify song transitions
                if !track.isEmpty || !artist.isEmpty {
                    self.nowPlayingTrack  = track
                    self.nowPlayingArtist = artist
                }

                if let pb = json["playback"] as? String { self.playbackStatus = pb }
                self.playTime  = json["play_time"]  as? Int ?? 0
                self.totalTime = json["total_time"] as? Int ?? 0
                self.shuffleAvailable = (json["shuffle_available"] as? [String])?.isEmpty == false
                self.repeatAvailable  = json["repeat_available"]  as? [String] ?? []
                let frozen = self.shuffleRepeatFrozenUntil.map { Date() < $0 } ?? false
                if !frozen {
                    if let sh = json["shuffle"] as? String { self.shuffleMode = sh }
                    if let rp = json["repeat"]  as? String { self.repeatMode = rp }
                }

                if let artPath = json["albumart_url"] as? String,
                   let artId   = json["albumart_id"]  as? Int,
                   artId > 0,
                   !artPath.isEmpty {
                    let newURL = "http://\(YamahaSettings.shared.ipAddress)\(artPath)"
                    if newURL != self.albumArtURLString {
                        self.albumArtURLString = newURL
                        self.prefetchArtwork(urlString: newURL)
                    }
                }
                // artId == 0 means receiver is still loading art — keep showing old artwork
            }
        }.resume()
    }

    func fetchTunerInfoIfNeeded() {
        guard powerState == .on,
              currentInput.lowercased() == "tuner",
              let url = URL(string: "\(baseURL)/tuner/getPlayInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            DispatchQueue.main.async {
                if let band = json["band"] as? String { self.tunerBand = band }
            }
        }.resume()
    }

    func fetchSignalInfo() {
        guard powerState == .on,
              let url = URL(string: "\(baseURL)/main/getSignalInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["response_code"] as? Int) == 0,
                  let audio = json["audio"] as? [String: Any] else { return }
            DispatchQueue.main.async {
                self.audioFormat   = (audio["format"]    as? String) ?? ""
                self.audioChannels = (audio["fs"]        as? String) ?? ""
                self.audioBitrate  = (audio["bitrate"]   as? Int)    ?? 0
                self.audioBitDepth = (audio["bit"] as? String) ?? ""
            }
        }.resume()
    }

    func fetchDeviceInfo() {
        guard let url = URL(string: "\(baseURL)/system/getDeviceInfo") else { return }
        session.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  (json["response_code"] as? Int) == 0 else { return }
            DispatchQueue.main.async {
                self.deviceModel = (json["model_name"] as? String) ?? ""
                if let ver = json["system_version"] as? Double {
                    self.deviceFirmware = String(format: "%.2f", ver)
                } else if let ver = json["system_version"] as? String {
                    self.deviceFirmware = ver
                }
            }
        }.resume()
    }

    func togglePlayback() {
        guard powerState == .on else { return }
        let action = playbackStatus == "play" ? "pause" : "play"
        setPlayback(action)
    }

    // MARK: - Sequence

    func powerOnWithInput(_ input: String, completion: @escaping (Error?) -> Void) {
        setPower("on") { error in
            if let error { completion(error); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                self.setInput(input, completion: completion)
            }
        }
    }

    func powerOnSequence(completion: @escaping (Error?) -> Void) {
        let lastInput = UserDefaults.standard.string(forKey: "last_input") ?? ""

        setPower("on") { error in
            if let error { completion(error); return }
            guard !lastInput.isEmpty else { completion(nil); return }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                self.setInput(lastInput, completion: completion)
            }
        }
    }

    // MARK: - Notifications

    // MARK: - Notifications

    private func sendTransitionNotification(newState: PowerState) {
        let content = UNMutableNotificationContent()
        content.title = "Yamaha Controller"
        content.sound = .default
        switch newState {
        case .on:
            content.body = "Receiver turned on automatically."
        case .standby:
            content.body = "Receiver turned off automatically."
        case .unknown:
            return
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

// MARK: - Music Center Models

struct NetRadioRecentItem: Identifiable, Equatable {
    let id: Int
    let text: String
    let albumArtURL: String
}

struct NetRadioPreset: Identifiable {
    let id: Int
    let text: String
}
