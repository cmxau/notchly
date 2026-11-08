//
//  StatusToast.swift
//  Notchly
//
//  Short messages in the closed notch for Caps Lock and for going offline or back online.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit
import Defaults
import Network
import SwiftUI

extension Defaults.Keys {
    static let showSystemToasts = Key<Bool>("showSystemToasts", default: true)
}

struct Toast: Equatable {
    let icon: String
    let text: String
    let color: Color
}

@MainActor
final class StatusToast: ObservableObject {
    static let shared = StatusToast()

    @Published private(set) var toast: Toast?

    private let monitor = NWPathMonitor()
    private var capsLockOn = NSEvent.modifierFlags.contains(.capsLock)
    private var online: Bool?
    private var hideTask: Task<Void, Never>?

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.flagsChanged(event.modifierFlags) }
        }
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.flagsChanged(event.modifierFlags) }
            return event
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.pathChanged(online: path.status == .satisfied) }
        }
        monitor.start(queue: .global(qos: .utility))
    }

    private func flagsChanged(_ flags: NSEvent.ModifierFlags) {
        let on = flags.contains(.capsLock)
        guard on != capsLockOn else { return }
        capsLockOn = on
        guard Defaults[.showSystemToasts] else { return }
        // The same HUD as volume, brightness and the microphone
        NotchlyViewCoordinator.shared.toggleSneakPeek(status: true, type: .capsLock, value: on ? 1 : 0)
    }

    private func pathChanged(online now: Bool) {
        defer { online = now }
        // The first report is the starting state, not a change
        guard let before = online, before != now else { return }
        show(Toast(icon: now ? "wifi" : "wifi.slash", text: now ? "Back online" : "Offline", color: now ? .green : .red))
    }

    private func show(_ new: Toast) {
        guard Defaults[.showSystemToasts] else { return }
        toast = new
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { toast = nil }
        }
    }
}
