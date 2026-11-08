//
//  ToolsSettings.swift
//  Notchly
//
//  Settings for the clipboard, timer, weather and indicator features.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import Defaults
import SwiftUI

struct ToolsSettings: View {
    @Default(.focusMinutes) private var focusMinutes
    @Default(.breakMinutes) private var breakMinutes
    @Default(.weatherCity) private var city

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .clipboardHistoryEnabled) { Text("Keep clipboard history") }
                Button("Clear history (keeps favourites)") { ClipboardManager.shared.clearUnfavorited() }
            } header: {
                Text("Clipboard")
            } footer: {
                Text("Text only, stored on this Mac. Items from password managers are skipped. ⇧⌘C opens the search window.")
            }
            Section {
                Stepper("Focus: \(focusMinutes) min", value: $focusMinutes, in: 1...120)
                Stepper("Break: \(breakMinutes) min", value: $breakMinutes, in: 1...60)
            } header: {
                Text("Timer")
            } footer: {
                Text("New lengths apply from the next reset.")
            }
            Section {
                TextField("City", text: $city)
                    .onSubmit { Task { await WeatherManager.shared.refresh(force: true) } }
                Defaults.Toggle(key: .weatherFahrenheit) { Text("Use Fahrenheit") }
                    .onChange(of: Defaults[.weatherFahrenheit]) { Task { await WeatherManager.shared.refresh(force: true) } }
            } header: {
                Text("Weather")
            } footer: {
                Text("Press Return after typing a city.")
            }
        }
        .navigationTitle("Tools")
    }
}
