import Cocoa
import CoreGraphics

/// Drives display brightness boost via the gamma transfer table.
///
/// On EDR-capable displays (MBP XDR, Pro Display XDR, Studio Display) the
/// gamma LUT accepts output values above 1.0; the windowserver renders the
/// > 1.0 portion into the display's HDR headroom, which physically raises
/// the backlight. This only works while the display is already in EDR
/// rendering mode — see `HDRPrimer` for that half of the trick.
///
/// Disable is a single `CGDisplayRestoreColorSyncSettings()` — restores the
/// system-default profile across all displays.
enum GammaBoost {
    /// Write a linear ramp `0 → ceiling` to the display's gamma table.
    /// `ceiling > 1.0` is what produces the boost; `ceiling == 1.0` is identity.
    @discardableResult
    static func enable(_ display: CGDirectDisplayID, ceiling: Float) -> Bool {
        let size = 256
        var table = [Float](repeating: 0, count: size)
        for i in 0..<size {
            table[i] = Float(i) / Float(size - 1) * ceiling
        }
        let result = table.withUnsafeBufferPointer { buf -> CGError in
            CGSetDisplayTransferByTable(display, UInt32(size), buf.baseAddress, buf.baseAddress, buf.baseAddress)
        }
        return result == .success
    }

    /// Restore every display to its ColorSync default. Simpler and more
    /// robust than trying to re-write a saved table per display.
    static func disableAll() {
        CGDisplayRestoreColorSyncSettings()
    }

    /// Built-in display ID, or main if there's no built-in.
    static var primaryDisplayID: CGDirectDisplayID {
        let main = CGMainDisplayID()
        if CGDisplayIsBuiltin(main) != 0 { return main }
        for id in allDisplayIDs() where CGDisplayIsBuiltin(id) != 0 {
            return id
        }
        return main
    }

    static func allDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids
    }
}
