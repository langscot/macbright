import Cocoa

/// Watches which app is currently frontmost and fires a callback whenever it
/// changes. Used by `BoostController` to auto-disable the boost while the
/// user is in an HDR game / video player where the extra brightness blows
/// out highlights.
///
/// Pure public API — `NSWorkspace` notifications, no private CGS calls.
final class AppMonitor {
    var onChange: ((String?) -> Void)?

    /// Bundle ID of the current frontmost app, or nil if unknown (e.g. Finder
    /// during login). Updated synchronously before each `onChange` call.
    private(set) var currentBundleID: String?

    func start() {
        currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self,
                       selector: #selector(activated(_:)),
                       name: NSWorkspace.didActivateApplicationNotification,
                       object: nil)
    }

    @objc private func activated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        let id = app?.bundleIdentifier
        guard id != currentBundleID else { return }
        currentBundleID = id
        onChange?(id)
    }
}
