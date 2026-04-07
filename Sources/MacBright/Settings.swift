import Foundation

/// Tiny wrapper around UserDefaults. Three keys, that's it.
enum Settings {
    private static let d = UserDefaults.standard

    private enum Key {
        static let enabled = "enabled"
        static let onlyOnPower = "onlyOnPower"
        static let intensity = "intensity"  // 0.0 ... 1.0
        static let excludedApps = "excludedApps"  // [String] of bundle IDs
    }

    static var enabled: Bool {
        get { d.object(forKey: Key.enabled) as? Bool ?? false }
        set { d.set(newValue, forKey: Key.enabled) }
    }

    /// Defaults to ON — battery-friendly out of the box.
    static var onlyOnPower: Bool {
        get { d.object(forKey: Key.onlyOnPower) as? Bool ?? true }
        set { d.set(newValue, forKey: Key.onlyOnPower) }
    }

    /// 0.0 = no boost, 1.0 = full available headroom.
    static var intensity: Double {
        get { d.object(forKey: Key.intensity) as? Double ?? 1.0 }
        set { d.set(max(0, min(1, newValue)), forKey: Key.intensity) }
    }

    /// Bundle IDs of apps where the boost should auto-disable while they're
    /// frontmost. HDR games and video players are the obvious ones — boost
    /// over already-bright HDR content blows out highlights.
    static var excludedApps: Set<String> {
        get { Set(d.stringArray(forKey: Key.excludedApps) ?? []) }
        set { d.set(Array(newValue).sorted(), forKey: Key.excludedApps) }
    }

    static func isExcluded(_ bundleID: String) -> Bool {
        excludedApps.contains(bundleID)
    }

    static func setExcluded(_ bundleID: String, _ excluded: Bool) {
        var s = excludedApps
        if excluded { s.insert(bundleID) } else { s.remove(bundleID) }
        excludedApps = s
    }
}
