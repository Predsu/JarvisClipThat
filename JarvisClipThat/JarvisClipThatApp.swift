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
    
    var contextMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = ContentView(clipboard: clipboardManager, hideAction: { [weak self] in
            self?.hidePopover()
        })
        
        popover.contentSize = NSSize(width: 260, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "JarvisClipThat")
            button.action = #selector(statusBarClicked)
            button.target = self
            
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        setupContextMenu()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if event.keyCode == 9 && modifiers == [.shift, .option] {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }

    func setupContextMenu() {
        let menu = NSMenu()
        
        let titleItem = NSMenuItem(title: "JarvisClipThat v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        // for future
        // let settingsItem = NSMenuItem(title: "Ustawienia...", action: #selector(openSettings), keyEquivalent: ",")
        // menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.contextMenu = menu
    }

    @objc func statusBarClicked() {
        let event = NSApp.currentEvent
        
        if event?.type == .rightMouseUp || (event?.type == .leftMouseUp && event?.modifierFlags.contains(.control) == true) {
            if popover.isShown {
                hidePopover()
            }
            
            if let button = statusItem?.button, let menu = contextMenu {
                statusItem?.menu = menu
                button.performClick(nil)
                statusItem?.menu = nil
            }
        } else {
            togglePopover()
        }
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

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
