import SwiftUI
import AppKit
import Carbon

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
        setupGlobalShortcut()
    }

    func setupContextMenu() {
        let menu = NSMenu()
        menu.delegate = self
        
        let titleItem = NSMenuItem(title: "JarvisClipThat v1.0", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let privateModeItem = NSMenuItem(title: "Burner mode", action: #selector(togglePrivateMode), keyEquivalent: "p")
        privateModeItem.target = self
        menu.addItem(privateModeItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        self.contextMenu = menu
    }

    func setupGlobalShortcut() {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Utils.stringToFourCharCode("JVCT"), id: 1)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        let eventHandler: EventHandlerUPP = { (_, event, userData) -> OSStatus in
            guard let event = event else { return OSStatus(noErr) }
            
            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if hotKeyID.id == 1 && userData != nil {
                let unmanaged = Unmanaged<AppDelegate>.fromOpaque(userData!)
                let delegate = unmanaged.takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.togglePopover()
                }
            }
            return OSStatus(noErr)
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), eventHandler, 1, &eventType, selfPtr, nil)
        
        RegisterEventHotKey(9, UInt32(controlKey | optionKey), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    @objc func togglePrivateMode() {
        clipboardManager.isPrivateMode.toggle()
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
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if let privateItem = menu.items.first(where: { $0.action == #selector(togglePrivateMode) }) {
            privateItem.state = clipboardManager.isPrivateMode ? .on : .off
        }
    }
}

struct Utils {
    static func stringToFourCharCode(_ string: String) -> FourCharCode {
        var result: FourCharCode = 0
        let utf8 = string.utf8
        for byte in utf8 {
            result = (result << 8) | FourCharCode(byte)
        }
        return result
    }
}
