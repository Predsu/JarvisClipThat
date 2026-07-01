import SwiftUI
import AppKit

class ClipboardManager: ObservableObject {
    @Published var currentActive: String = ""
    @Published var history: [String] = []
    
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private var isInternalPaste = false

    init() {
        self.changeCount = pasteboard.changeCount
        if let initial = pasteboard.string(forType: .string) {
            let trimmed = initial.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { self.currentActive = trimmed }
        }
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        if let newString = pasteboard.string(forType: .string) {
            let trimmed = newString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            
            DispatchQueue.main.async {
                if self.isInternalPaste {
                    self.currentActive = trimmed
                    self.isInternalPaste = false
                    return
                }
                
                if !self.currentActive.isEmpty && self.currentActive != trimmed {
                    self.history.removeAll { $0 == trimmed }
                    self.history.insert(self.currentActive, at: 0)
                }
                
                self.currentActive = trimmed
                
                if self.history.count > 30 { self.history.removeLast() }
            }
        }
    }

    func pasteItem(_ text: String) {
        self.isInternalPaste = true
        
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        DispatchQueue.main.async {
            self.history.removeAll { $0 == text }
            if !self.currentActive.isEmpty && self.currentActive != text {
                self.history.insert(self.currentActive, at: 0)
            }
            self.currentActive = text
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .combinedSessionState)
            let vKeyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
            vKeyDown?.flags = .maskCommand
            let vKeyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
            vKeyUp?.flags = .maskCommand
            
            vKeyDown?.post(tap: .cghidEventTap)
            vKeyUp?.post(tap: .cghidEventTap)
        }
    }
    func clearAll() {
        DispatchQueue.main.async {
            self.currentActive = ""
            self.history.removeAll()
            self.pasteboard.clearContents()
        }
    }
}

struct ContentView: View {
    @ObservedObject var clipboard: ClipboardManager
    var hideAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("JarvisClipThat")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    clipboard.clearAll()
                    hideAction()
                }) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear history")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider().background(Color.white.opacity(0.1))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENTLY COPIED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan)
                
                if clipboard.currentActive.isEmpty {
                    Text("Clipboard is empty")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                        .italic()
                } else {
                    Text(clipboard.currentActive)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                        )
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
                    VStack(spacing: 4) {
                        ForEach(clipboard.history, id: \.self) { item in
                            Button(action: {
                                clipboard.pasteItem(item)
                                hideAction()
                            }) {
                                Text(item)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 6)
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
        .frame(width: 260, height: 350)
    }
}
