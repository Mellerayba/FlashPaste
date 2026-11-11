import AppKit

/// Optional capture feedback: a short sound plus a small floating HUD near the top of the screen.
final class Feedback {
    var enabled = false
    private var panel: NSPanel?
    private var label: NSTextField?
    private var hide: DispatchWorkItem?

    func show(_ text: String) {
        guard enabled else { return }
        NSSound(named: "Pop")?.play()
        let panel = self.panel ?? makePanel()
        label?.stringValue = text
        label?.sizeToFit()
        let size = NSSize(width: min(label!.frame.width + 32, 600), height: 40)
        guard let screen = NSScreen.main else { return }
        let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        label?.frame = NSRect(x: 16, y: 0, width: size.width - 32, height: size.height)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hide?.cancel()
        let item = DispatchWorkItem { [weak self] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel.animator().alphaValue = 0 }) { self?.panel?.orderOut(nil) }
        }
        hide = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: item)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.material = .hudWindow
        effect.state = .active
        effect.autoresizingMask = [.width, .height]
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        effect.addSubview(label)
        panel.contentView = effect
        self.panel = panel
        self.label = label
        return panel
    }
}
