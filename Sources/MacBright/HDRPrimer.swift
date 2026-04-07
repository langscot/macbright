import Cocoa
import Metal
import QuartzCore

/// A 1×1-pixel invisible window whose only job is to keep a CAMetalLayer
/// rendering HDR content so the system stays in EDR-rendering mode. Without
/// an active HDR surface on the display, gamma table outputs above 1.0 are
/// clamped back to SDR — which is why a naked `CGSetDisplayTransferByTable`
/// call only produces washout instead of actual extra backlight.
///
/// We use a Metal layer cleared to a high EDR value, which is cheap and
/// doesn't need any video / codec resources.
final class HDRPrimer {
    private var window: NSWindow?
    private var device: MTLDevice?
    private var queue: MTLCommandQueue?
    private var metalLayer: CAMetalLayer?
    private var displayLink: CVDisplayLink?

    func start() {
        guard window == nil else { return }
        guard let dev = MTLCreateSystemDefaultDevice(),
              let q = dev.makeCommandQueue() else { return }
        device = dev
        queue = q

        let frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        let w = NSWindow(
            contentRect: frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        // Below the menu bar so we never cover the status item.
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.normalWindow)))
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        w.alphaValue = 0.01

        let host = NSView(frame: frame)
        host.wantsLayer = true
        let layer = CAMetalLayer()
        layer.device = dev
        layer.pixelFormat = .rgba16Float
        layer.framebufferOnly = true
        layer.wantsExtendedDynamicRangeContent = true
        layer.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3)
        layer.isOpaque = false
        layer.drawableSize = CGSize(width: 1, height: 1)
        host.layer = layer
        metalLayer = layer

        w.contentView = host
        w.orderFrontRegardless()
        window = w

        // Render once. CAMetalLayer only needs occasional refresh to keep
        // the display in EDR mode; a single bright pixel persists in the
        // compositor until torn down.
        renderOnce()
    }

    func stop() {
        window?.orderOut(nil)
        window?.contentView = nil
        window = nil
        metalLayer = nil
        queue = nil
        device = nil
    }

    private func renderOnce() {
        guard let layer = metalLayer, let queue = queue else { return }
        guard let drawable = layer.nextDrawable() else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        // High EDR clear value — way above SDR white. The compositor uses the
        // brightest onscreen EDR pixel to decide how much headroom to grant.
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 8, green: 8, blue: 8, alpha: 1)
        guard let buf = queue.makeCommandBuffer(),
              let enc = buf.makeRenderCommandEncoder(descriptor: pass) else { return }
        enc.endEncoding()
        buf.present(drawable)
        buf.commit()
    }
}
