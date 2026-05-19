# Sandbox Migration Plan — Yamaha Controller
## Goal: Mac App Store compatibility

---

## Why This Change Is Necessary

The current implementation writes `.plist` files directly to `~/Library/LaunchAgents/` and manages them via `launchctl` shell commands. This approach requires **unsandboxed** access to the filesystem outside the app container.

The Mac App Store **mandates App Sandbox** for all submitted apps. A sandboxed app cannot write to `~/Library/LaunchAgents/` — making the current Morning Alarm and Auto Off scheduling completely non-functional under sandbox.

---

## Proposed Solution: Replace launchd with `SMAppService`

`SMAppService` (introduced in macOS 13 / Ventura) is Apple's modern, **sandbox-compatible** replacement for manual launchd plist management. It allows apps to register background helper executables and login items without writing files outside the sandbox container.

This is the correct solution because:
- It is fully compatible with App Sandbox
- It supports scheduling via a helper executable that runs at login and after sleep/wake
- It is the Apple-recommended approach for exactly this use case
- Yamaha Controller already requires macOS 13+, so there are no compatibility concerns

---

## Scope of Changes

### Files to modify:
- `Services/SchedulerService.swift` — replace all `launchctl` shell commands and plist file writing with `SMAppService` registration/unregistration
- `YamahaController.xcodeproj` — enable App Sandbox capability in Signing & Capabilities
- Add a new **Login Item Helper target** (a minimal executable) that the main app registers via `SMAppService`

### Files unchanged:
- `Views/MorningAlarmView.swift` — UI stays the same
- `Views/AutoOffView.swift` — UI stays the same
- All scheduling settings in `UserDefaults` — persist as-is

---

## Implementation Steps

### Step 1 — Add App Sandbox entitlement
In Xcode: Target → Signing & Capabilities → + Capability → App Sandbox.  
Enable only the entitlements actually needed (network client access for YXC HTTP calls).

### Step 2 — Create a Login Item Helper target
Add a new target to the project: a minimal macOS command-line tool or `SMLoginItemHelperApp`.  
This helper reads the scheduling settings from shared `UserDefaults` (via App Group) and performs the power on/off actions at the scheduled times.

### Step 3 — Add App Group entitlement
Both the main app and the helper need to share `UserDefaults`.  
Add `com.apple.security.application-groups` entitlement with a shared group ID (e.g. `group.com.yamaha-controller`).  
Replace all `UserDefaults.standard` scheduling keys with `UserDefaults(suiteName: "group.com.yamaha-controller")`.

### Step 4 — Rewrite `SchedulerService.swift`
Remove:
- All `Process()` / shell calls to `launchctl`
- All plist file generation and writing to `~/Library/LaunchAgents/`

Replace with:
- `SMAppService.loginItem(identifier:)` to register/unregister the helper
- The helper itself handles the time-based logic using `Timer` or `DispatchQueue` with wake detection via `NSWorkspace.didWakeNotification`

### Step 5 — Handle sleep/wake in the helper
The helper must re-evaluate scheduled times after Mac wakes from sleep:
```swift
NSWorkspace.shared.notificationCenter.addObserver(
    forName: NSWorkspace.didWakeNotification,
    object: nil,
    queue: .main
) { _ in
    // Re-check if alarm should fire now
}
```

---

## Prompt for Claude Code

```
I need to migrate Yamaha Controller from manual launchd plist management to SMAppService 
for Mac App Store sandbox compatibility.

Current situation:
- SchedulerService.swift writes .plist files to ~/Library/LaunchAgents/ and manages 
  them via launchctl shell commands
- The app is not sandboxed (required for App Store submission)
- Morning Alarm and Auto Off scheduling must continue to work after migration

Required changes:
1. Enable App Sandbox entitlement in the Xcode project
2. Create a Login Item Helper target that handles scheduled power on/off
3. Add an App Group entitlement shared between main app and helper for UserDefaults access
4. Rewrite SchedulerService.swift to use SMAppService instead of launchd
5. Add sleep/wake detection in the helper via NSWorkspace.didWakeNotification

Constraints:
- Target: macOS 13.0+ (Ventura) — SMAppService is available
- No external dependencies — keep pure Apple frameworks only
- MorningAlarmView.swift and AutoOffView.swift UI must remain unchanged
- All existing UserDefaults keys for scheduling settings must continue to work 
  (migrate to App Group suite name: group.com.yamaha-controller)
- The helper must survive Mac sleep/wake cycles and re-evaluate scheduled times on wake

Please analyse the current SchedulerService.swift first, then propose the full 
migration with all necessary code changes across all affected files.
```
