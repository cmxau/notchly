//
//  FloatingShelf.swift
//  Notchly
//
//  The shelf in its own always-on-top window, opened with a global shortcut, to drop files onto from anywhere.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit
import KeyboardShortcuts
import SwiftUI

extension KeyboardShortcuts.Name {
    static let toggleFloatingShelf = Self("toggleFloatingShelf", default: .init(.s, modifiers: [.option, .command]))
}

@MainActor
enum FloatingShelf {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private static var panel: NSPanel?
    private static let viewModel = NotchlyViewModel()

    static func toggle() {
        if let panel, panel.isVisible {
            panel.close()
            return
        }
        let panel = self.panel ?? makePanel()
        // Near the pointer, like Dropover
        let mouse = NSEvent.mouseLocation
        panel.setFrameTopLeftPoint(NSPoint(x: mouse.x - panel.frame.width / 2, y: mouse.y + 40))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    private static func makePanel() -> NSPanel {
        let panel = Panel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 200),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .utilityWindow],
            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.black.withAlphaComponent(0.88)
        panel.contentView = NSHostingView(
            rootView: ShelfView()
                .environmentObject(viewModel)
                .padding(12)
                .padding(.top, 8)
                .preferredColorScheme(.dark))
        return panel
    }
}
