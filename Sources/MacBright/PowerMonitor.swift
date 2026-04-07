import Foundation
import IOKit.ps

/// Event-driven power-source watcher. No polling.
final class PowerMonitor {
    private(set) var isOnPower: Bool = PowerMonitor.readIsOnPower()
    var onChange: ((Bool) -> Void)?

    private var runLoopSource: CFRunLoopSource?

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let me = Unmanaged<PowerMonitor>.fromOpaque(ctx).takeUnretainedValue()
            let now = PowerMonitor.readIsOnPower()
            if now != me.isOnPower {
                me.isOnPower = now
                me.onChange?(now)
            }
        }, context).takeRetainedValue()
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
    }

    func stop() {
        if let s = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), s, .defaultMode)
        }
        runLoopSource = nil
    }

    static func readIsOnPower() -> Bool {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() else { return true }
        let providing = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        return providing == kIOPMACPowerKey
    }
}
