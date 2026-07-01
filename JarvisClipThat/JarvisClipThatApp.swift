import SwiftUI
import AppKit

@main
struct JarvisClipThatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var clipboardManager = ClipboardManager()
    var globalMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView(clipboard: clipboardManager, hideAction: { [weak self] in
            self?.hidePopover()
        })
        
        // Zwiększamy wysokość okna popover do 350
        popover.contentSize = NSSize(width: 260, height: 350)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "JarvisClipThat")
            button.action = #selector(statusBarClicked)
            button.target = self
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            // Domyślnie zostawiam Shift + Option + V (klawisz 9), zmień jeśli wolisz inny
            if event.keyCode == 9 && modifiers == [.shift, .option] {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }

    @objc func statusBarClicked() {
        togglePopover()
    }

    func togglePopover() {
        if popover.isShown {
            hidePopover()
        } else {
            showPopover()
        }
    }

    func showPopover() {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func hidePopover() {
        popover.performClose(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
