//
//  AccessibilityPermission.swift
//  Notchly
//
//  macOS 27 removed Accessibility from Privacy & Security and renamed it "Device Control and Data Access". The code
//  and APIs behind it are unchanged; only the name people see in System Settings differs, so text shown to the
//  user goes through here.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit

enum AccessibilityPermission {
    /// What System Settings calls the permission on this Mac.
    static var name: String {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "Device Control and Data Access" : "Accessibility"
    }

    /// Opens the pane that holds it. The Accessibility page's link target is only known for macOS 26 and earlier, so
    /// macOS 27 opens Privacy & Security.
    static func openSettings() {
        let pane = ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27 ? "" : "?Privacy_Accessibility"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
