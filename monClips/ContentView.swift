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
        // Data limite: 24 horas atrás
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)

        let descriptor = FetchDescriptor<ClipItem>()
        do {
            let allItems = try modelContext.fetch(descriptor)

            // Filtra os itens mais velhos que 24h e que não estão fixados
            let itemsToDelete = allItems.filter { item in
                return item.timestamp < cutoffDate && !item.isPinned
            }

            // Deleta os itens encontrados
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    
    @State private var searchText = ""
    
    @Query private var copiedItems: [ClipItem]

    var filteredItems: [ClipItem] {
        let items = searchText.isEmpty
            ? copiedItems
            : copiedItems.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        
        return items.sorted {
            if $0.isPinned != $1.isPinned {
                return $0.isPinned && !$1.isPinned
            }
            return $0.timestamp > $1.timestamp
        }
    }

    @State private var copiedItemId: PersistentIdentifier?
    @State private var clipboardTimer: Timer?
    
    private func triggerHapticFeedback() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.1, green: 0.1, blue: 0.15), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                Group {
                    if copiedItems.isEmpty {
                        ContentUnavailableView("Nenhum recorte salvo", systemImage: "clipboard")
                    } else {
                        List {
                            ForEach(filteredItems) { clip in
                                let isLink = clip.text.lowercased().hasPrefix("http") || clip.text.lowercased().hasPrefix("www")
                                let safeURLString = clip.text.lowercased().hasPrefix("www") ? "https://" + clip.text : clip.text
                                let displayURL = URL(string: safeURLString)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        if isLink {
                                            Image(systemName: "safari")
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Text(clip.text)
                                            .lineLimit(2)
                                            .font(.headline)
                                            .foregroundStyle(copiedItemId == clip.id ? .green : (isLink ? .blue : .primary))
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
                                        
                                        if copiedItemId == clip.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.caption)
                                                .transition(.scale.combined(with: .opacity))
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.white.opacity(0.05))
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                                .padding(.vertical, 4)
                                .accessibilityElement(children: .combine)
                                .accessibilityHint(isLink ? "Toque duas vezes para abrir no navegador" : "Toque duas vezes para copiar para a área de transferência")
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    triggerHapticFeedback()
                                    
                                    if isLink, let validURL = displayURL {
                                        openURL(validURL)
                                        return
                                    }
                                    
                                    #if canImport(UIKit)
                                    UIPasteboard.general.string = clip.text
                                    #elseif canImport(AppKit)
                                    let pasteboard = NSPasteboard.general
                                    pasteboard.clearContents()
                                    pasteboard.setString(clip.text, forType: .string)
                                    #endif
                                    
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        copiedItemId = clip.id
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation(.easeOut) {
                                            if copiedItemId == clip.id {
                                                copiedItemId = nil
                                            }
                                        }
                                    }
                                }
                                .contextMenu {
                                    Button("Copiar novamente") {
                                        #if canImport(UIKit)
                                        UIPasteboard.general.string = clip.text
                                        #elseif canImport(AppKit)
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(clip.text, forType: .string)
                                        #endif
                                    }
                                    ShareLink(item: clip.text) {
                                        Label("Compartilhar", systemImage: "square.and.arrow.up")
                                    }
                                }
                                .swipeActions {
                                    Button(role: .destructive) {
                                        modelContext.delete(clip)
                                    } label: {
                                        Label("Apagar", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        clip.isPinned.toggle()
                                    } label: {
                                        Label(clip.isPinned ? "Desfixar" : "Fixar", systemImage: clip.isPinned ? "pin.slash" : "pin")
                                    }
                                    .tint(.orange)
                                }
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .navigationTitle("Minhas Notas")
                .searchable(text: $searchText, prompt: "Buscar recortes")
                .toolbar {
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
            }
        }
    }
}
