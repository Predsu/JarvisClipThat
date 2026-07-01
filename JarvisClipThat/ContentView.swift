import SwiftUI
import AppKit

class ClipboardManager: ObservableObject {
    @Published var currentActive: String = "" // Aktualnie gotowy element (na samej górze)
    @Published var history: [String] = []     // Historia poprzednich elementów
    
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private var isInternalPaste = false       // Flaga zapobiegająca duplikowaniu przy kliknięciu

    init() {
        self.changeCount = pasteboard.changeCount
        // Pobieramy startową zawartość schowka, jeśli istnieje
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
                // Jeśli zmiana nastąpiła przez kliknięcie w programie:
                if self.isInternalPaste {
                    self.currentActive = trimmed
                    self.isInternalPaste = false // Resetujemy flagę
                    return
                }
                
                // Jeśli użytkownik skopiował coś nowego z zewnątrz:
                // Przenosimy dotychczasowy aktywny element do historii (jeśli nie był pusty)
                if !self.currentActive.isEmpty && self.currentActive != trimmed {
                    // Usuwamy ewentualne stare wystąpienia tego tekstu, żeby nie dublować w historii
                    self.history.removeAll { $0 == trimmed }
                    self.history.insert(self.currentActive, at: 0)
                }
                
                self.currentActive = trimmed
                
                if self.history.count > 30 { self.history.removeLast() }
            }
        }
    }

    func pasteItem(_ text: String) {
        self.isInternalPaste = true // Informujemy managera, że to nasze własne kliknięcie
        
        // 1. Zapisujemy do schowka systemowego
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        
        // Aktualizujemy lokalny stan: wybrany tekst staje się aktywny,
        // a jeśli był w historii, to go stamtąd usuwamy (bo jest teraz na górze)
        DispatchQueue.main.async {
            self.history.removeAll { $0 == text }
            if !self.currentActive.isEmpty && self.currentActive != text {
                self.history.insert(self.currentActive, at: 0)
            }
            self.currentActive = text
        }
        
        // 2. Symulujemy CMD + V
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
            // Czyścimy też fizyczny schowek systemowy
            self.pasteboard.clearContents()
        }
    }
}

struct ContentView: View {
    @ObservedObject var clipboard: ClipboardManager
    var hideAction: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Nagłówek
            HStack {
                Text("JarvisClipThat")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    clipboard.clearAll()
                    hideAction() // Opcjonalnie zamyka okno po wyczyszczeniu
                }) {
                    Image(systemName: "trash.fill") // Zmiana na ikonę kosza
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Wyczyść całą historię") // Podpowiedź po najechaniu myszką
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 8)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Sekcja: AKTUALNIE W SCHOWKU (Zawsze na górze)
            VStack(alignment: .leading, spacing: 4) {
                Text("AKTUALNIE W SCHOWKU (CMD+V)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.cyan)
                
                if clipboard.currentActive.isEmpty {
                    Text("Schowek jest pusty")
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
            
            // Sekcja: HISTORIA
            HStack {
                Text("STARSZA HISTORIA")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            ScrollView {
                if clipboard.history.isEmpty {
                    Text("Brak starszych elementów")
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
        .frame(width: 260, height: 350) // Lekko zwiększyłem wysokość (z 320 na 350) dla nowej sekcji
    }
}
