import SwiftUI
import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String?
    let image: NSImage?
    var isImage: Bool { image != nil }
}

class ClipboardManager: ObservableObject {
    @Published var currentActive: ClipboardItem? = nil
    @Published var history: [ClipboardItem] = []
    @Published var isPrivateMode: Bool = false
    
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private var isInternalPaste = false

    init() {
        self.changeCount = pasteboard.changeCount
        if let initial = getClipboardContent() {
            self.currentActive = initial
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func getClipboardContent() -> ClipboardItem? {
        if let imageTypes = pasteboard.types, imageTypes.contains(.tiff) || imageTypes.contains(.png) {
            if let img = NSImage(pasteboard: pasteboard) {
                return ClipboardItem(text: nil, image: img)
            }
        }
        if let str = pasteboard.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return ClipboardItem(text: trimmed, image: nil) }
        }
        return nil
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        guard let newItem = getClipboardContent() else {
            DispatchQueue.main.async {
                self.currentActive = nil
            }
            return
        }

        DispatchQueue.main.async {
            if self.isInternalPaste {
                self.currentActive = newItem
                self.isInternalPaste = false
                
                if self.isPrivateMode {
                    self.burnActiveItem()
                }
                return
            }
            
            if let active = self.currentActive, active.text == newItem.text && active.image == newItem.image {
                return
            }
            
            if self.isPrivateMode {
                self.currentActive = newItem
                return
            }
            
            if let active = self.currentActive {
                self.history.removeAll { $0.text == newItem.text && $0.image == newItem.image }
                self.history.insert(active, at: 0)
            }
            
            self.currentActive = newItem
            if self.history.count > 20 { self.history.removeLast() }
        }
    }

    func pasteItem(_ item: ClipboardItem) {
        self.isInternalPaste = true
        pasteboard.clearContents()
        
        if let img = item.image {
            pasteboard.writeObjects([img])
        } else if let text = item.text {
            pasteboard.setString(text, forType: .string)
        }
        
        DispatchQueue.main.async {
            if self.isPrivateMode {
                self.currentActive = item
            } else {
                self.history.removeAll { $0.id == item.id }
                if let active = self.currentActive, active.id != item.id {
                    self.history.insert(active, at: 0)
                }
                self.currentActive = item
            }
        }
        
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKeyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        vKeyDown?.flags = .maskCommand
        let vKeyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        vKeyUp?.flags = .maskCommand
        
        vKeyDown?.post(tap: .cghidEventTap)
        vKeyUp?.post(tap: .cghidEventTap)
        
        if self.isPrivateMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.burnActiveItem()
            }
        }
    }

    private func burnActiveItem() {
        DispatchQueue.main.async {
            self.currentActive = nil
            self.pasteboard.clearContents()
            self.changeCount = self.pasteboard.changeCount
        }
    }

    func clearAll() {
        DispatchQueue.main.async {
            self.currentActive = nil
            self.history.removeAll()
            self.pasteboard.clearContents()
            self.changeCount = self.pasteboard.changeCount
        }
    }
}

struct ContentView: View {
    @ObservedObject var clipboard: ClipboardManager
    var hideAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 4) {
                    Text("JarvisClipThat")
                        .font(.system(size: 11, weight: .bold))
                    if clipboard.isPrivateMode {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                    }
                }
                .foregroundColor(.secondary)
                
                Spacer()
                Button(action: {
                    clipboard.clearAll()
                    hideAction()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider().background(Color.white.opacity(0.1))
            
            if clipboard.isPrivateMode {
                HStack {
                    Spacer()
                    Text("BURNER MODE ACTIVE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple)
                    Spacer()
                }
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.15))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENTLY COPIED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(clipboard.isPrivateMode ? .purple : .cyan)
                
                if let active = clipboard.currentActive {
                    if active.isImage, let img = active.image {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 70)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(clipboard.isPrivateMode ? Color.purple.opacity(0.4) : Color.cyan.opacity(0.4), lineWidth: 1)
                            )
                    } else if let text = active.text {
                        Text(text)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(clipboard.isPrivateMode ? Color.purple.opacity(0.15) : Color.cyan.opacity(0.15))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(clipboard.isPrivateMode ? Color.purple.opacity(0.3) : Color.cyan.opacity(0.3), lineWidth: 1)
                            )
                    }
                } else {
                    Text(clipboard.isPrivateMode ? "Burned data" : "Clipboard is empty")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                }
            }
            .padding(8)
            
            Divider().background(Color.white.opacity(0.1))
            
            HStack {
                Text("HISTORY")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            ScrollView {
                if clipboard.history.isEmpty {
                    Text("No history available")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 5) {
                        ForEach(clipboard.history) { item in
                            Button(action: {
                                clipboard.pasteItem(item)
                                hideAction()
                            }) {
                                Group {
                                    if item.isImage, let img = item.image {
                                        HStack {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 60, height: 40)
                                                .background(Color.black.opacity(0.2))
                                                .cornerRadius(4)
                                            Text("Image")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                        }
                                    } else if let text = item.text {
                                        Text(text)
                                            .font(.system(size: 11, design: .monospaced))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                .padding(.vertical, 5)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(6)
                }
            }
        }
        .frame(width: 260, height: 380)
    }
}
