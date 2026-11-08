//
//  OnboardingFeatures.swift
//  Notchly
//
//  Onboarding step that asks what to keep in the notch (in alphabetical order), asks for a city when Weather is
//  kept, and turns the rest off.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AVFoundation
import Defaults
import SwiftUI

private struct FeatureChoice: Identifiable {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let color: Color
    let selectedByDefault: Bool
    let apply: (Bool) -> Void

    init(_ id: String, _ icon: String, _ title: String, _ detail: String, _ color: Color,
         selectedByDefault: Bool = true, apply: @escaping (Bool) -> Void) {
        self.id = id; self.icon = icon; self.title = title; self.detail = detail; self.color = color
        self.selectedByDefault = selectedByDefault; self.apply = apply
    }
}

/// Tabs are shown unless they're in `hiddenTabs`.
private func setTab(_ tab: NotchViews, _ on: Bool) {
    var hidden = Defaults[.hiddenTabs].filter { $0 != tab }
    if !on { hidden.append(tab) }
    Defaults[.hiddenTabs] = hidden
}

private let hasCamera = AVCaptureDevice.default(for: .video) != nil

/// Alphabetical by title.
private let choices: [FeatureChoice] = [
    FeatureChoice("agents", "terminal.fill", "AI agents", "Claude Code, Codex and more", .purple) { Defaults[.agentIntegrationEnabled] = $0 },
    FeatureChoice("calendar", "calendar", "Calendar", "Events and reminders", .red) { Defaults[.showCalendar] = $0 },
    FeatureChoice("clipboard", "doc.on.clipboard", "Clipboard", "History, search, favourites", .blue) {
        Defaults[.clipboardHistoryEnabled] = $0
        setTab(.clipboard, $0)
    },
    FeatureChoice("alerts", "bell.badge.fill", "Live alerts", "Calls, Caps Lock, network", .yellow) {
        Defaults[.showCallIndicator] = $0
        Defaults[.showSystemToasts] = $0
    },
    FeatureChoice("mirror", "web.camera", "Mirror", "Check yourself in the notch", .teal, selectedByDefault: hasCamera) {
        Defaults[.showMirror] = $0 && hasCamera
    },
    FeatureChoice("music", "music.note", "Music", "Now playing and controls", .pink) { setTab(.music, $0) },
    FeatureChoice("pet", "pawprint.fill", "Pet", "A cat keeps the notch company", .gray, selectedByDefault: false) { Defaults[.showNotchPet] = $0 },
    FeatureChoice("shelf", "tray.and.arrow.down.fill", "Shelf", "Drop and share files", .orange) { Defaults[.notchlyShelf] = $0 },
    FeatureChoice("teleprompter", "text.alignleft", "Teleprompter", "Reads along as you speak", .mint) { setTab(.teleprompter, $0) },
    FeatureChoice("timer", "timer", "Timer", "Focus and break rounds", .green) { setTab(.timer, $0) },
    FeatureChoice("weather", "cloud.sun.fill", "Weather", "Now and the next hours", .cyan) { setTab(.weather, $0) },
].sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

struct FeaturePickerView: View {
    let onContinue: () -> Void
    @State private var selected = Set(choices.filter(\.selectedByDefault).map(\.id))
    @State private var city = ""
    @State private var lookup = CityLookup.idle

    private enum CityLookup: Equatable {
        case idle, searching, found(WeatherPlace), notFound, offline
    }

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("What would you like in your notch?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Pick what to keep. You can change this any time in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 34)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(choices) { choice in card(choice) }
            }
            .padding(.horizontal, 20)

            if selected.contains("weather") { cityField.transition(.opacity.combined(with: .move(edge: .top))) }

            Button {
                for choice in choices { choice.apply(selected.contains(choice.id)) }
                if selected.contains("weather") {
                    Defaults[.weatherCity] = city
                    if case .found(let place) = lookup { WeatherManager.remember(place, for: city) }
                }
                onContinue()
            } label: {
                Text("Continue")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .animation(.smooth, value: selected)
    }

    private func card(_ choice: FeatureChoice) -> some View {
        let on = selected.contains(choice.id)
        let unavailable = choice.id == "mirror" && !hasCamera
        return Button {
            if on { selected.remove(choice.id) } else { selected.insert(choice.id) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: choice.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(choice.color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.title).font(.callout.weight(.semibold))
                    Text(unavailable ? "No camera found" : choice.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.effectiveAccent : .secondary)
            }
            .padding(9)
            .background(.white.opacity(on ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? Color.effectiveAccent.opacity(0.7) : .clear, lineWidth: 1.5))
            .opacity(on ? 1 : 0.65)
        }
        .buttonStyle(.plain)
        .disabled(unavailable)
    }

    /// Asked for here, and checked as you type, so a city that can't be found is caught now and not on the Weather tab.
    private var cityField: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill").foregroundStyle(Color.effectiveAccent)
                TextField("Your city, for example Panvel, India", text: $city)
                    .textFieldStyle(.plain)
                switch lookup {
                case .searching: ProgressView().controlSize(.small)
                case .found: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .notFound, .offline: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                case .idle: EmptyView()
                }
            }
            .padding(10)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Group {
                switch lookup {
                case .found(let place): Text("Found \(place.title)").foregroundStyle(.green)
                case .notFound: Text("Couldn't find that. Try the city name, or \"City, Country\".").foregroundStyle(.orange)
                case .offline: Text("Couldn't reach the weather service. You can set the city later in Settings.").foregroundStyle(.orange)
                default: Text("You can also set it later in Settings.").foregroundStyle(.secondary)
                }
            }
            .font(.caption)
        }
        .padding(.horizontal, 20)
        .task(id: city) {
            let typed = city.trimmingCharacters(in: .whitespaces)
            guard typed.count >= 2 else { lookup = .idle; return }
            lookup = .searching
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            do {
                if let place = try await WeatherManager.resolve(typed) { lookup = .found(place) } else { lookup = .notFound }
            } catch {
                if !Task.isCancelled { lookup = .offline }
            }
        }
    }
}
