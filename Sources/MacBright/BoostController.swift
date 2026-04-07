import Cocoa
import CoreGraphics

/// Owns the boost on/off state. On enable, writes a scaled linear gamma
/// table to every built-in display so values >1.0 land in EDR headroom and
/// physically raise the backlight. On disable, restores ColorSync defaults.
final class BoostController {
    private let powerMonitor = PowerMonitor()
    private let appMonitor = AppMonitor()
    private let primer = HDRPrimer()
    private var isBoosting = false

    /// Maps `Settings.intensity` (0…1) to a gamma ceiling. 1.0 is identity,
    /// 2.0 is roughly the practical XDR ceiling — beyond that the firmware
    /// stops granting more headroom and you just get clipping.
    private let maxCeiling: Float = 2.0

    func start() {
        powerMonitor.onChange = { [weak self] _ in self?.apply() }
        powerMonitor.start()
        appMonitor.onChange = { [weak self] _ in self?.apply() }
        appMonitor.start()
        apply()
    }

    /// Frontmost app's bundle ID — exposed so the menu can show "Disable for
    /// <current app>" against the right thing.
    var frontmostBundleID: String? { appMonitor.currentBundleID }

    private var shouldBeActive: Bool {
        guard Settings.enabled else { return false }
        if Settings.onlyOnPower && !powerMonitor.isOnPower { return false }
        if let id = appMonitor.currentBundleID, Settings.isExcluded(id) { return false }
        return true
    }

    func apply() {
        if shouldBeActive {
            engage()
        } else {
            disengage()
        }
    }

    private func engage() {
        // Prime EDR mode FIRST. The gamma table outputs above 1.0 only land
        // in the HDR backlight range when the display is already rendering
        // HDR content; otherwise they get clamped and just look washed out.
        primer.start()
        let ceiling = 1.0 + (maxCeiling - 1.0) * Float(Settings.intensity)
        for id in builtinDisplays() {
            GammaBoost.enable(id, ceiling: ceiling)
        }
        isBoosting = true
    }

    private func disengage() {
        guard isBoosting else { return }
        GammaBoost.disableAll()
        primer.stop()
        isBoosting = false
    }

    /// Only built-in displays — external monitors with DDC have a totally
    /// different brightness path and we'd risk surprising the user.
    private func builtinDisplays() -> [CGDirectDisplayID] {
        GammaBoost.allDisplayIDs().filter { CGDisplayIsBuiltin($0) != 0 }
    }

    static var isSupported: Bool {
        !GammaBoost.allDisplayIDs().filter { CGDisplayIsBuiltin($0) != 0 }.isEmpty
    }
}
