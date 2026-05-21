import Foundation
import ServiceManagement

class SchedulerService {
    static let shared = SchedulerService()
    private init() {}

    private let helperID = "com.danbutuc.hertzcast.helper"

    func scheduleIfNeeded(morningEnabled: Bool, autoOffEnabled: Bool) {
        if morningEnabled || autoOffEnabled {
            register()
        } else {
            unregister()
        }
    }

    func register() {
        let service = SMAppService.loginItem(identifier: helperID)
        guard service.status != .enabled else { return }
        do {
            try service.register()
        } catch {
            print("[Scheduler] register error: \(error)")
        }
    }

    func unregister() {
        let service = SMAppService.loginItem(identifier: helperID)
        guard service.status == .enabled else { return }
        do {
            try service.unregister()
        } catch {
            print("[Scheduler] unregister error: \(error)")
        }
    }
}
