//
//  generic.swift
//  Notchly
//
//  Created by Harsh Vardhan  Goswami  on 04/08/24.
//

import AppKit
import Foundation
import Defaults

public enum Style {
    case notch
    case floating
}

public enum ContentType: Int, Codable, Hashable, Equatable {
    case normal
    case menu
    case settings
}

public enum NotchState {
    case closed
    case open
}

public enum NotchViews: String, CaseIterable, Defaults.Serializable {
    case home
    case music
    case calendar
    case agents
    case shelf
    case teleprompter
    case clipboard
    case timer
    case weather

    var title: String {
        switch self {
        case .home: return "Home"
        case .music: return "Music"
        case .calendar: return "Calendar"
        case .agents: return "AI Agents"
        case .shelf: return "Shelf"
        case .teleprompter: return "Teleprompter"
        case .clipboard: return "Clipboard"
        case .timer: return "Timer"
        case .weather: return "Weather"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .music: return "music.note"
        case .calendar: return "calendar"
        case .agents: return "sparkles"
        case .shelf: return "tray.fill"
        case .teleprompter: return "text.alignleft"
        case .clipboard: return "doc.on.clipboard"
        case .timer: return "timer"
        case .weather: return "cloud.sun.fill"
        }
    }
}

/// One half of the home tab.
enum HomePane: String, CaseIterable, Identifiable, Defaults.Serializable {
    case none = "None"
    case music = "Music"
    case calendar = "Calendar"
    case agents = "AI Agents"

    var id: String { rawValue }

    var view: NotchViews? {
        switch self {
        case .none: return nil
        case .music: return .music
        case .calendar: return .calendar
        case .agents: return .agents
        }
    }

    /// The home tab's panes, left to right. One chosen pane fills the whole width; none at all shows music.
    static var homePanes: [NotchViews] {
        let panes = [Defaults[.homeLeftPane], Defaults[.homeRightPane]].compactMap(\.view)
        return panes.isEmpty ? [.music] : panes
    }
}

enum SettingsEnum {
    case general
    case about
    case charge
    case download
    case mediaPlayback
    case hud
    case shelf
    case extensions
}

/// The app icons the user can pick from (Settings → Advanced). The Dock shows the choice while the app runs.
struct AppIconOption: Identifiable {
    let id: Int
    let name: String
    var asset: String { "AppIconOption\(id)" }
    func apply() { NSApp.applicationIconImage = NSImage(named: asset) }
    static let all = [
        AppIconOption(id: 1, name: "Signal"), AppIconOption(id: 2, name: "Paper"),
        AppIconOption(id: 3, name: "Acid"), AppIconOption(id: 4, name: "Ink"),
    ]
}

/// The closed shape: the classic notch (flared top corners) or the island of the newer MacBook Pro displays.
enum NotchShapeStyle: String, CaseIterable, Identifiable, Defaults.Serializable {
    case notch = "Notch"
    case island = "Island"
    var id: String { rawValue }
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}

