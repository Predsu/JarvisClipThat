import SwiftUI
import AppKit

struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String?
    let image: NSImage?
    var isImage: Bool { image != nil }
    var categoryId: UUID? = nil
}

struct ClipboardCategory: Identifiable, Equatable, Codable {
    let id = UUID()
    let name: String
    let iconName: String
}

struct UserSnippet: Identifiable, Equatable, Codable {
    let id = UUID()
    let title: String
    let content: String
}

class ClipboardManager: ObservableObject {
    @Published var currentActive: ClipboardItem? = nil
    @Published var history: [ClipboardItem] = []
    @Published var isPrivateMode: Bool = false
    
    @Published var categories: [ClipboardCategory] = [] {
        didSet {
            DataStorageHelper.saveData(categories, to: "categories.json")
        }
    }
    @Published var userSnippets: [UserSnippet] = [] {
        didSet {
            DataStorageHelper.saveData(userSnippets, to: "snippets.json")
        }
    }
    
    private let pasteboard = NSPasteboard.general
    private var changeCount: Int
    private var timer: Timer?
    private var isInternalPaste = false

    init() {
        self.changeCount = pasteboard.changeCount
        if let initial = getClipboardContent() {
            self.currentActive = initial
        }
        
        loadPersistedData()
        
        self.timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    private func loadPersistedData() {
        if let loadedCats = DataStorageHelper.loadData("categories.json", as: [ClipboardCategory].self) {
            self.categories = loadedCats
        } else {
            self.categories = []
        }
        
        if let loadedSnippets = DataStorageHelper.loadData("snippets.json", as: [UserSnippet].self) {
            self.userSnippets = loadedSnippets
        }
    }

    private func getClipboardContent() -> ClipboardItem? {
        if let imageTypes = pasteboard.types, imageTypes.contains(.tiff) || imageTypes.contains(.png) {
            if let img = NSImage(pasteboard: pasteboard) {
                return ClipboardItem(text: nil, image: img, categoryId: nil)
            }
        }
        if let str = pasteboard.string(forType: .string) {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let safeText = trimmed.count > 20000 ? String(trimmed.prefix(20000)) + "..." : trimmed
                return ClipboardItem(text: safeText, image: nil, categoryId: nil)
            }
        }
        return nil
    }

    private func checkClipboard() {
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount

        guard let newItem = getClipboardContent() else {
            DispatchQueue.main.async { self.currentActive = nil }
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
            } else {
                if let active = self.currentActive, !(active.text == newItem.text && active.image == newItem.image) {
                    self.history.removeAll { $0.text == active.text && $0.image == active.image }
                    self.history.insert(active, at: 0)
                }
                self.currentActive = newItem
            }
            
            if let active = self.currentActive {
                let existingCategory = self.history.first(where: { $0.text == newItem.text && $0.image == newItem.image })?.categoryId
                self.history.removeAll { $0.text == newItem.text && $0.image == newItem.image }
                
                var itemToInsert = active
                if let cat = existingCategory { itemToInsert.categoryId = cat }
                self.history.insert(itemToInsert, at: 0)
            }
            
            self.currentActive = newItem
            if self.history.count > 20 { self.history.removeLast() }
        }
    }

    func assignCategory(to itemID: UUID, categoryID: UUID?) {
        DispatchQueue.main.async {
            if let index = self.history.firstIndex(where: { $0.id == itemID }) {
                self.history[index].categoryId = categoryID
            } else if self.currentActive?.id == itemID {
                self.currentActive?.categoryId = categoryID
            }
        }
    }
    
    func addCategory(name: String, icon: String) {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        DispatchQueue.main.async {
            self.categories.append(ClipboardCategory(name: name, iconName: icon))
        }
    }
    
    func removeCategory(categoryId: UUID?) {
        DispatchQueue.main.async {
            self.categories.removeAll { $0.id == categoryId }
            
            if let active = self.currentActive, active.categoryId == categoryId {
                self.currentActive?.categoryId = nil
            }
            for index in self.history.indices {
                if self.history[index].categoryId == categoryId {
                    self.history[index].categoryId = nil
                }
            }
        }
    }
    
    func addSnippet(title: String, content: String) {
        guard !title.isEmpty && !content.isEmpty else { return }
        DispatchQueue.main.async {
            self.userSnippets.append(UserSnippet(title: title, content: content))
        }
    }
    
    func removeSnippet(snippetId: UUID?) {
        DispatchQueue.main.async {
            self.userSnippets.removeAll { $0.id == snippetId }
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
        
        updateHistoryState(for: item)
        postCommandVEvent()
    }
    
    func pasteRawText(_ text: String) {
        self.isInternalPaste = true
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        postCommandVEvent()
    }
    
    private func updateHistoryState(for item: ClipboardItem) {
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
    }
    
    private func postCommandVEvent() {
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
    
    @State private var currentTab: AppTab = .history
    @State private var selectedFilterCategoryId: UUID? = nil
    @State private var showAllInHistory = true
    
    @State private var newCategoryName = ""
    @State private var newSnippetTitle = ""
    @State private var newSnippetContent = ""
    @State private var isAddingCategory = false
    @State private var isAddingSnippet = false
    
    @State private var isClearConfirmationWindowVisible = false
    
    enum AppTab { case history, snippets }

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
                
                Picker("", selection: $currentTab) {
                    Image(systemName: "clock.fill").tag(AppTab.history)
                    Image(systemName: "doc.text.fill").tag(AppTab.snippets)
                }
                .pickerStyle(.segmented)
                .frame(width: 70)
                
                Spacer()
                
                
                
                Button(action: {
                    isClearConfirmationWindowVisible = true
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
            
            switch currentTab {
            case .history:
                historyTabView
            case .snippets:
                snippetsTabView
            }
        }
        .frame(width: 260, height: 380)
        .alert("Jarvis Clear That?", isPresented: $isClearConfirmationWindowVisible) {
            Button("Jarvis Clear That", role: .destructive) {
                clipboard.clearAll()
                hideAction()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action will clear all clipboard history and cannot be undone")
        }
    }
    
    private var historyTabView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("CURRENTLY COPIED")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(clipboard.isPrivateMode ? .purple : .cyan)
                
                if let active = clipboard.currentActive {
                    HStack {
                        currentActiveCard(active)
                        if !clipboard.isPrivateMode {
                            categoryPickerMenu(for: active)
                        }
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
            
            categoryFilterBar
            
            ScrollView {
                let filteredHistory = clipboard.history.filter { item in
                    showAllInHistory ? true : item.categoryId == selectedFilterCategoryId
                }
                
                if filteredHistory.isEmpty {
                    Text("No matching items")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 5) {
                        ForEach(filteredHistory) { item in
                            HStack(spacing: 4) {
                                Button(action: {
                                    clipboard.pasteItem(item)
                                    hideAction()
                                }) {
                                    historyRowContent(item)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                categoryPickerMenu(for: item)
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
    }
    
    private var snippetsTabView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("YOUR SNIPPETS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: { isAddingSnippet.toggle() }) {
                    Image(systemName: isAddingSnippet ? "chevron.up" : "plus.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            
            if isAddingSnippet {
                VStack(spacing: 4) {
                    TextField("Title", text: $newSnippetTitle)
                        .textFieldStyle(.roundedBorder)
                    TextField("Content", text: $newSnippetContent)
                        .textFieldStyle(.roundedBorder)
                    Button("Save Snippet") {
                        clipboard.addSnippet(title: newSnippetTitle, content: newSnippetContent)
                        newSnippetTitle = ""
                        newSnippetContent = ""
                        isAddingSnippet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.black.opacity(0.1))
            }
            
            ScrollView {
                if clipboard.userSnippets.isEmpty {
                    Text("No snippets saved")
                        .font(.footnote)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                } else {
                    VStack(spacing: 5) {
                        ForEach(clipboard.userSnippets) { snippet in
                            HStack {
                                Button(action: {
                                    clipboard.pasteRawText(snippet.content)
                                    hideAction()
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(snippet.title)
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.cyan)
                                            Spacer()
                                            Image(systemName: "doc.on.doc")
                                                .font(.system(size: 8))
                                                .foregroundColor(.gray)
                                        }
                                        Text(snippet.content)
                                            .font(.system(size: 10, design: .monospaced))
                                            .lineLimit(1)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 8)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Button(action: {
                                    clipboard.removeSnippet(snippetId: snippet.id)
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 9))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }
        }
    }
    
    @ViewBuilder
    private func currentActiveCard(_ active: ClipboardItem) -> some View {
        if active.isImage, let img = active.image {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.black.opacity(0.2))
                .cornerRadius(6)
        } else if let text = active.text {
            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(clipboard.isPrivateMode ? Color.purple.opacity(0.15) : Color.cyan.opacity(0.15))
                .cornerRadius(6)
        }
    }
    
    private var categoryFilterBar: some View {
        VStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    Button(action: { showAllInHistory = true }) {
                        Text("All")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(showAllInHistory ? Color.cyan : Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }.buttonStyle(.plain)
                    
                    Button(action: {
                        showAllInHistory = false
                        selectedFilterCategoryId = nil
                    }) {
                        Text("Uncategorized")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(!showAllInHistory && selectedFilterCategoryId == nil ? Color.secondary : Color.white.opacity(0.1))
                            .cornerRadius(4)
                    }.buttonStyle(.plain)
                    
                    ForEach(clipboard.categories) { cat in
                        Button(action: {
                            showAllInHistory = false
                            selectedFilterCategoryId = cat.id
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: cat.iconName).font(.system(size: 8))
                                Text(cat.name)
                            }
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(!showAllInHistory && selectedFilterCategoryId == cat.id ? Color.purple : Color.white.opacity(0.1))
                            .cornerRadius(4)
                        }.buttonStyle(.plain)
                            .contextMenu {
                                Button(action: {
                                    clipboard.removeCategory(categoryId: cat.id)
                                }) {
                                    Text("Remove")
                                }
                            }
                    }
                    
                    Button(action: { isAddingCategory.toggle() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                            .padding(2)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 6)
            }
            .frame(height: 22)
            
            if isAddingCategory {
                HStack {
                    TextField("New category...", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    Button("Add") {
                        clipboard.addCategory(name: newCategoryName, icon: "tag.fill")
                        newCategoryName = ""
                        isAddingCategory = false
                    }
                    .controlSize(.small)
                }
                .padding(.horizontal, 6)
            }
            Divider().background(Color.white.opacity(0.1))
        }
        .padding(.top, 2)
    }
    
    @ViewBuilder
    private func historyRowContent(_ item: ClipboardItem) -> some View {
        Group {
            if item.isImage, let img = item.image {
                HStack {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 30)
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
    
    private func categoryPickerMenu(for item: ClipboardItem) -> some View {
        Menu {
            Button("Uncategorized") {
                clipboard.assignCategory(to: item.id, categoryID: nil)
            }
            ForEach(clipboard.categories) { cat in
                Button(action: {
                    clipboard.assignCategory(to: item.id, categoryID: cat.id)
                }) {
                    HStack {
                        Text(cat.name)
                        if item.categoryId == cat.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: item.categoryId == nil ? "tag" : "tag.fill")
                .font(.system(size: 9))
                .foregroundColor(item.categoryId == nil ? .gray : .purple)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 18)
    }
}
