import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: BoostController!
    private var menuBar: MenuBar!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log every screen's EDR capability so we can see what the hardware
        // actually reports — don't quit, even on "unsupported" hardware. The
        // menu bar item must always appear so the user has a way out.
        // Create the menu bar FIRST so the user always has a way to quit
        // even if controller startup throws.
        controller = BoostController()
        menuBar = MenuBar(controller: controller)
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Controller's teardown happens implicitly when windows are released.
    }
}
