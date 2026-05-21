import AppKit
import SwiftUI
import Combine
import UserNotifications
import CoreGraphics

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var playbackMenu: NSMenu?
    private var aboutWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        requestNotificationPermission()
        setupStatusItem()
        setupPopover()
        observePowerState()
        HertzAPIService.shared.startPolling()
        // asyncAfter gives SwiftUI time to finish its default menu setup before we replace it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.buildMainMenu() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows {
            NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon(for: .unknown)
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
    }

    private func observePowerState() {
        HertzAPIService.shared.$powerState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.updateIcon(for: state) }
            .store(in: &cancellables)

        HertzAPIService.shared.$shuffleMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.playbackMenu?.item(withTitle: "Shuffle")?.state = mode != "off" ? .on : .off
            }.store(in: &cancellables)

        HertzAPIService.shared.$repeatMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.playbackMenu?.item(withTitle: "Repeat")?.state = mode != "off" ? .on : .off
            }.store(in: &cancellables)
    }

    private func updateIcon(for state: PowerState) {
        statusItem?.button?.image = menuBarIcon(for: state)
    }

    // MARK: - Menu bar icon

    private func menuBarIcon(for state: PowerState) -> NSImage? {
        let name: String
        switch state {
        case .on:      name = "hertz_green"
        case .standby: name = "hertz_red"
        case .unknown: return sfSymbolFallback(for: state)
        }
        guard let path = Bundle.main.path(forResource: name, ofType: "png"),
              let img = NSImage(contentsOfFile: path) else {
            return sfSymbolFallback(for: state)
        }
        img.size = NSSize(width: 18, height: 18)
        img.isTemplate = false
        return img
    }

    private func sfSymbolFallback(for state: PowerState) -> NSImage? {
        let name: String
        switch state {
        case .on:      name = "circle.fill"
        case .standby: name = "circle"
        case .unknown: name = "questionmark.circle"
        }
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = true
        return img
    }

    // MARK: - Popover

    private func setupPopover() {
        let popover = NSPopover()
        popover.behavior = .transient
        let hc = NSHostingController(rootView: PopoverView())
        hc.sizingOptions = .intrinsicContentSize
        popover.contentViewController = hc
        self.popover = popover

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(closePopover),
                                               name: .init("closePopover"), object: nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover else { return }
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            DispatchQueue.main.async { [weak self] in
                self?.popover?.contentViewController?.view.window?.makeKey()
            }
            HertzAPIService.shared.fetchStatus()
        }
    }

    @objc private func closePopover() {
        popover?.performClose(nil)
    }

    // MARK: - Main Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // ── App menu ─────────────────────────────────────────────────────
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu

        appMenu.addItem(withTitle: "About HertzCast", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        let settingsItem = appMenu.addItem(withTitle: "Settings…", action: #selector(menuToggleSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = .command
        appMenu.addItem(.separator())
        let hideItem = appMenu.addItem(withTitle: "Hide HertzCast", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hideItem.keyEquivalentModifierMask = .command
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        let quitItem = appMenu.addItem(withTitle: "Quit HertzCast", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = .command

        // ── Playback menu ────────────────────────────────────────────────
        let pbItem = NSMenuItem()
        mainMenu.addItem(pbItem)
        let pbMenu = NSMenu(title: "Playback")
        pbItem.submenu = pbMenu
        playbackMenu = pbMenu

        let repeatItem = NSMenuItem(title: "Repeat", action: #selector(menuRepeat), keyEquivalent: "r")
        repeatItem.keyEquivalentModifierMask = []
        pbMenu.addItem(repeatItem)

        let prevItem = NSMenuItem(title: "Previous", action: #selector(menuPrevious),
                                  keyEquivalent: String(UnicodeScalar(NSLeftArrowFunctionKey)!))
        prevItem.keyEquivalentModifierMask = .command
        pbMenu.addItem(prevItem)

        let playItem = NSMenuItem(title: "Play", action: #selector(menuPlay), keyEquivalent: "p")
        playItem.keyEquivalentModifierMask = []
        pbMenu.addItem(playItem)

        let nextItem = NSMenuItem(title: "Next", action: #selector(menuNext),
                                  keyEquivalent: String(UnicodeScalar(NSRightArrowFunctionKey)!))
        nextItem.keyEquivalentModifierMask = .command
        pbMenu.addItem(nextItem)

        let shuffleItem = NSMenuItem(title: "Shuffle", action: #selector(menuShuffle), keyEquivalent: "s")
        shuffleItem.keyEquivalentModifierMask = []
        pbMenu.addItem(shuffleItem)

        pbMenu.addItem(.separator())

        let volUpItem = NSMenuItem(title: "Volume Up", action: #selector(menuVolumeUp),
                                   keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!))
        volUpItem.keyEquivalentModifierMask = .command
        pbMenu.addItem(volUpItem)

        let volDownItem = NSMenuItem(title: "Volume Down", action: #selector(menuVolumeDown),
                                     keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!))
        volDownItem.keyEquivalentModifierMask = .command
        pbMenu.addItem(volDownItem)

        let muteItem = NSMenuItem(title: "Mute", action: #selector(menuMute), keyEquivalent: "m")
        muteItem.keyEquivalentModifierMask = []
        pbMenu.addItem(muteItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - About

    @objc private func showAbout() {
        if aboutWindow == nil {
            let hosting = NSHostingController(rootView: AboutView())
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 280, height: 230),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            win.title = "About HertzCast"
            win.contentViewController = hosting
            win.isReleasedWhenClosed = false
            win.center()
            aboutWindow = win
        }
        aboutWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Playback menu actions

    @objc private func menuToggleSettings() {
        AppUIState.shared.toggleSettings()
        NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func menuRepeat()     { HertzAPIService.shared.cycleRepeat() }
    @objc private func menuPrevious()   { HertzAPIService.shared.setPlayback("previous") }
    @objc private func menuPlay()       { HertzAPIService.shared.togglePlayback() }
    @objc private func menuNext()       { HertzAPIService.shared.setPlayback("next") }
    @objc private func menuShuffle()    { HertzAPIService.shared.toggleShuffle() }
    @objc private func menuVolumeUp()   { HertzAPIService.shared.volumeUp() }
    @objc private func menuVolumeDown() { HertzAPIService.shared.volumeDown() }
    @objc private func menuMute()       { HertzAPIService.shared.toggleMute() }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
