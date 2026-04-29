import SwiftUI
import SwiftData
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ClipboardManager {
    var modelContext: ModelContext

    func cleanUpOldClips() {
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        let descriptor = FetchDescriptor<ClipItem>()
        do {
            let allItems = try modelContext.fetch(descriptor)
            let itemsToDelete = allItems.filter { item in
                return item.timestamp < cutoffDate && !item.isPinned
            }
            for item in itemsToDelete {
                modelContext.delete(item)
            }
        } catch {
            print("Erro ao limpar clips antigos: \(error)")
        }
    }

    func readFromClipboard() {
        cleanUpOldClips()
        let copiedText: String?
        #if canImport(UIKit)
        copiedText = UIPasteboard.general.string
        #elseif canImport(AppKit)
        copiedText = NSPasteboard.general.string(forType: .string)
        #endif

        if let validText = copiedText {
            if !validText.isEmpty {
                let descriptor = FetchDescriptor<ClipItem>()
                if let allItems = try? modelContext.fetch(descriptor),
                   allItems.contains(where: { $0.text == validText }) {
                    return
                }
                let newItem = ClipItem(text: validText)
                modelContext.insert(newItem)
            }
        }
    }
}

struct ClipRowView: View {
    let clip: ClipItem
    let isSelected: Bool
    let onCopy: (ClipItem) -> Void
    let onDelete: (ClipItem) -> Void
    let onTogglePin: (ClipItem) -> Void
    
    @Environment(\.openURL) private var openURL
    
    private var categoryIcon: String {
        switch clip.type {
        case .link: return "safari"
        case .image: return "photo"
        case .code: return "chevron.left.forward.slash"
        case .email: return "envelope"
        case .text: return "text.alignleft"
        }
    }
    
    private var categoryColor: Color {
        switch clip.type {
        case .link: return .blue
        case .image: return .purple
        case .code: return .orange
        case .email: return .red
        case .text: return .secondary
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: categoryIcon)
                    .foregroundColor(categoryColor)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(clip.text)
                        .lineLimit(clip.type == .image ? 1 : 2)
                        .font(.headline)
                        .foregroundStyle(clip.type == .link || clip.type == .image ? .blue : .primary)
                    
                    if clip.type == .image, let url = URL(string: clip.text) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                                    .clipped()
                                    .cornerRadius(12)
                            case .failure:
                                ContentUnavailableView("Falha ao carregar imagem", systemImage: "exclamationmark.triangle")
                                    .frame(height: 120)
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 120)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .background(Color.black.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            HStack {
                Text(clip.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if clip.isPinned {
                    Image(systemName: "pin.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.05))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .contentShape(Rectangle())
        .onTapGesture {
            onCopy(clip)
        }
        .contextMenu {
            Button("Copiar novamente") {
                onCopy(clip)
            }
            ShareLink(item: clip.text) {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                onDelete(clip)
            } label: {
                Label("Apagar", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onTogglePin(clip)
            } label: {
                Label(clip.isPinned ? "Desfixar" : "Fixar", systemImage: clip.isPinned ? "pin.slash" : "pin")
            }
            .tint(.orange)
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    
    @State private var searchText = ""
    @State private var selection: PersistentIdentifier?
    @State private var isSearchPresented = false

    // Pagination state
    @State private var fetchLimit = 50
    
    @Query private var allItems: [ClipItem]

    private var totalFilteredCount: Int {
        searchText.isEmpty
            ? allItems.count
            : allItems.filter { $0.text.localizedCaseInsensitiveContains(searchText) }.count
    }

    var filteredItems: [ClipItem] {
        let items = searchText.isEmpty
            ? allItems
            : allItems.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        
        let sorted = items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.timestamp > $1.timestamp
        }
        
        return Array(sorted.prefix(fetchLimit))
    }

    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var clipboardTimer: Timer?
    
    private func showToast(message: String) {
        toastMessage = message
        withAnimation(.spring()) {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut) {
                showToast = false
            }
        }
    }
    
    private func copyItem(_ clip: ClipItem) {
        triggerHapticFeedback()
        
        if clip.type == .link || clip.type == .image {
            let safeURLString = clip.text.lowercased().hasPrefix("www") ? "https://" + clip.text : clip.text
            if let validURL = URL(string: safeURLString) {
                openURL(validURL)
                return
            }
        }
        
        #if canImport(UIKit)
        UIPasteboard.general.string = clip.text
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(clip.text, forType: .string)
        #endif
        
        showToast(message: "Copiado!")
    }
    
    private func triggerHapticFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func checkPagination(for clip: ClipItem) {
        if let lastItem = filteredItems.last, clip.id == lastItem.id {
            if filteredItems.count < totalFilteredCount {
                fetchLimit += 50
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                Group {
                    if allItems.isEmpty {
                        ContentUnavailableView("Nenhum recorte salvo", systemImage: "clipboard")
                    } else {
                        List(selection: $selection) {
                            ForEach(filteredItems) { clip in
                                ClipRowView(
                                    clip: clip,
                                    isSelected: selection == clip.id,
                                    onCopy: { item in copyItem(item) },
                                    onDelete: { item in modelContext.delete(item) },
                                    onTogglePin: { item in item.isPinned.toggle() }
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .bottom).combined(with: .opacity)
                                ))
                                .onAppear {
                                    checkPagination(for: clip)
                                }
                            }

                            if filteredItems.count < totalFilteredCount {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .padding()
                                    Spacer()
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: filteredItems)
                        .onKeyPress(.return) {
                            if let selectedId = selection,
                               let selectedItem = allItems.first(where: { $0.id == selectedId }) {
                                copyItem(selectedItem)
                                return .handled
                            }
                            return .ignored
                        }
                    }
                }
                .navigationTitle("Minhas Notas")
                .searchable(text: $searchText, isPresented: $isSearchPresented, prompt: "Buscar recortes")
                .toolbar {
                    ToolbarItem {
                        Button(action: {
                            isSearchPresented = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                        .keyboardShortcut("f", modifiers: .command)
                    }
                    
                    ToolbarItem {
                        Button(action: {
                            let manager = ClipboardManager(modelContext: modelContext)
                            manager.readFromClipboard()
                        }) {
                            Image(systemName: "doc.on.clipboard")
                        }
                    }
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        let manager = ClipboardManager(modelContext: modelContext)
                        manager.readFromClipboard()
                    }
                }
                .onAppear {
                    clipboardTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                        let manager = ClipboardManager(modelContext: modelContext)
                        manager.readFromClipboard()
                    }
                }
                .onDisappear {
                    clipboardTimer?.invalidate()
                    clipboardTimer = nil
                }
                
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .background(.ultraThinMaterial)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Capsule())
                            .shadow(radius: 10)
                            .padding(.bottom, 40)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .ignoresSafeArea()
                    .zIndex(1)
                }
            }
        }
    }
}
