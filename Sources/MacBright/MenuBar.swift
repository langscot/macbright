import Cocoa

/// Menu bar UI: an icon, a tiny menu, that's it.
final class MenuBar: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let controller: BoostController
    private weak var enabledItem: NSMenuItem?
    private weak var onlyOnPowerItem: NSMenuItem?
    private weak var sliderItem: NSMenuItem?
    private weak var excludeItem: NSMenuItem?

    init(controller: BoostController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "MacBright") {
                image.isTemplate = true
                button.image = image
            } else {
                // Always fall back to text so there's *something* visible in
                // the menu bar — never leave the button empty.
                button.title = "☀︎"
            }
        }

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false

        let enabled = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        menu.addItem(enabled)
        self.enabledItem = enabled

        menu.addItem(.separator())

        // Brightness slider as a menu item with a custom view.
        let sliderHost = NSMenuItem()
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 38))
        let label = NSTextField(labelWithString: "Boost")
        label.frame = NSRect(x: 14, y: 18, width: 60, height: 16)
        label.font = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        container.addSubview(label)

        let slider = NSSlider(value: Settings.intensity,
                              minValue: 0.0,
                              maxValue: 1.0,
                              target: self,
                              action: #selector(sliderChanged(_:)))
        slider.frame = NSRect(x: 14, y: 2, width: 192, height: 18)
        slider.isContinuous = true
        container.addSubview(slider)
        sliderHost.view = container
        menu.addItem(sliderHost)
        self.sliderItem = sliderHost

        menu.addItem(.separator())

        let power = NSMenuItem(title: "Only when plugged in", action: #selector(toggleOnlyOnPower), keyEquivalent: "")
        power.target = self
        menu.addItem(power)
        self.onlyOnPowerItem = power

        let exclude = NSMenuItem(title: "Disable for current app", action: #selector(toggleExcludeFrontmost), keyEquivalent: "")
        exclude.target = self
        menu.addItem(exclude)
        self.excludeItem = exclude

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit MacBright", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        refreshState()
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshState()
    }

    private func refreshState() {
        enabledItem?.state = Settings.enabled ? .on : .off
        onlyOnPowerItem?.state = Settings.onlyOnPower ? .on : .off

        // Resolve the frontmost app *at menu-open time*. The user opening
        // our menu makes us the frontmost app momentarily, so we need the
        // *previous* frontmost — which is what AppMonitor remembers.
        if let id = controller.frontmostBundleID,
           id != Bundle.main.bundleIdentifier {
            let name = NSRunningApplication.runningApplications(withBundleIdentifier: id)
                .first?.localizedName ?? id
            excludeItem?.title = "Disable for \(name)"
            excludeItem?.state = Settings.isExcluded(id) ? .on : .off
            excludeItem?.isEnabled = true
        } else {
            excludeItem?.title = "Disable for current app"
            excludeItem?.state = .off
            excludeItem?.isEnabled = false
        }
    }

    @objc private func toggleEnabled() {
        Settings.enabled.toggle()
        refreshState()
        controller.apply()
    }

    @objc private func toggleOnlyOnPower() {
        Settings.onlyOnPower.toggle()
        refreshState()
        controller.apply()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        Settings.intensity = sender.doubleValue
        controller.apply()
    }

    @objc private func toggleExcludeFrontmost() {
        guard let id = controller.frontmostBundleID,
              id != Bundle.main.bundleIdentifier else { return }
        Settings.setExcluded(id, !Settings.isExcluded(id))
        refreshState()
        controller.apply()
    }
}
