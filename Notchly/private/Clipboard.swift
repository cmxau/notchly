//
//  Clipboard.swift
//  Notchly
//
//  Clipboard history (text) with search and favourites. The notch tab lists recent items; the search window
//  (⇧⌘C) is a normal panel because the notch can't take keyboard focus.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

struct ClipItem: Codable, Identifiable, Equatable, Defaults.Serializable {
    var id = UUID()
    var text: String
    var date = Date()
    var favorite = false
}

extension Defaults.Keys {
    static let clipboardHistory = Key<[ClipItem]>("clipboardHistory", default: [])
    static let clipboardHistoryEnabled = Key<Bool>("clipboardHistoryEnabled", default: false)
}

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    private static let limit = 60

    @Published private(set) var items: [ClipItem] = Defaults[.clipboardHistory]
    private var lastChange = NSPasteboard.general.changeCount
    private var timer: Timer?

    private var observer: Any?

    private init() {
        // Switching the history off wipes it, so turning it back on never shows what was copied before
        if !Defaults[.clipboardHistoryEnabled] { items = []; save() }
        observer = Defaults.observe(.clipboardHistoryEnabled) { [weak self] change in
            Task { @MainActor in self?.enabledChanged(change.newValue) }
        }
        enabledChanged(Defaults[.clipboardHistoryEnabled])
    }

    private func enabledChanged(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else {
            items = []
            save()
            return
        }
        // Whatever is on the clipboard right now was copied before history was on, so it isn't recorded
        lastChange = NSPasteboard.general.changeCount
        // ponytail: polls the change count; macOS has no clipboard-changed notification
        timer = Timer.scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount
        guard Defaults[.clipboardHistoryEnabled] else { return }
        // Password managers mark what they put on the clipboard as concealed or transient
        let skipped = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        guard !(pasteboard.types ?? []).contains(where: { skipped.contains($0.rawValue) }) else { return }
        guard let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty, items.first?.text != text else { return }
        let wasFavorite = items.first { $0.text == text }?.favorite ?? false
        items.removeAll { $0.text == text }
        items.insert(ClipItem(text: text, favorite: wasFavorite), at: 0)
        var kept = 0
        items.removeAll { item in
            if item.favorite { return false }
            kept += 1
            return kept > Self.limit
        }
        save()
    }

    func copy(_ item: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        lastChange = pasteboard.changeCount
    }

    func toggleFavorite(_ item: ClipItem) {
        guard let i = items.firstIndex(of: item) else { return }
        items[i].favorite.toggle()
        save()
    }

    func remove(_ item: ClipItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearUnfavorited() {
        items.removeAll { !$0.favorite }
        save()
    }

    private func save() { Defaults[.clipboardHistory] = items }
}

struct ClipboardView: View {
    var searchable = false
    @ObservedObject private var manager = ClipboardManager.shared
    @State private var query = ""
    @State private var copiedID: UUID?

    private var shown: [ClipItem] {
        let filtered = query.isEmpty ? manager.items : manager.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
        return filtered.filter(\.favorite) + filtered.filter { !$0.favorite }
    }

    var body: some View {
        VStack(spacing: 8) {
            if searchable {
                TextField("Search clipboard", text: $query)
                    .textFieldStyle(.roundedBorder)
            } else {
                HStack {
                    Label("Clipboard", systemImage: "doc.on.clipboard").font(.caption.weight(.semibold))
                    Text("\(manager.items.count)").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button { ClipboardPanel.toggle() } label: {
                        Label("Search", systemImage: "magnifyingglass").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.1), in: Capsule())
                }
            }
            if shown.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard").font(.title2)
                    Text(Defaults[.clipboardHistoryEnabled] ? "Nothing copied yet" : "History is off (Settings → Tools)")
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: searchable ? 1 : 2), spacing: 8) {
                        ForEach(shown) { item in card(item) }
                    }
                }
            }
        }
    }

    private func card(_ item: ClipItem) -> some View {
        let isLink = URL(string: item.text)?.scheme?.hasPrefix("http") == true
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: copiedID == item.id ? "checkmark.circle.fill" : (isLink ? "link" : "text.alignleft"))
                .foregroundStyle(copiedID == item.id ? .green : Color.effectiveAccent)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text).font(.callout).lineLimit(searchable ? 3 : 2)
                Text(item.date, format: .relative(presentation: .numeric, unitsStyle: .abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: 6) {
                Button { manager.toggleFavorite(item) } label: {
                    Image(systemName: item.favorite ? "star.fill" : "star")
                        .foregroundStyle(item.favorite ? .yellow : .secondary)
                }
                Button { manager.remove(item) } label: { Image(systemName: "xmark").foregroundStyle(.secondary) }
            }
            .buttonStyle(.plain)
            .font(.caption)
        }
        .notchCard(padding: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            manager.copy(item)
            copiedID = item.id
            Task {
                try? await Task.sleep(for: .seconds(1))
                if copiedID == item.id { copiedID = nil }
            }
        }
    }
}

/// The clipboard search window.
@MainActor
enum ClipboardPanel {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static var panel: NSPanel?

    static func toggle() {
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        let panel = self.panel ?? make()
        if let screen = NSScreen.main {
            panel.setFrameTopLeftPoint(NSPoint(x: screen.frame.midX - panel.frame.width / 2, y: screen.frame.maxY - 140))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private static func make() -> NSPanel {
        let panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.9)
        panel.contentView = NSHostingView(
            rootView: ClipboardView(searchable: true).padding(14).padding(.top, 8).preferredColorScheme(.dark))
        return panel
    }
}
