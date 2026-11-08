//
//  OnboardingView.swift
//  Notchly
//
//  Created by Alexander on 2025-06-23.
//

import AVFoundation
import Defaults
import EventKit
import SwiftUI

enum OnboardingStep: CaseIterable {
    case welcome
    case features
    case appearance
    case permissions
    case finished
}

private let calendarService = CalendarService()

/// The height the current step wants, so the window fits it.
private struct OnboardingHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    let onFinish: () -> Void
    let onOpenSettings: () -> Void
    /// Called with the height the window should have for the current step.
    var onHeightChange: (CGFloat) -> Void = { _ in }

    static let width: CGFloat = 440

    /// The permissions the chosen features need, in the order they are asked.
    private var neededPermissions: [OnboardingPermission] {
        var needed: [OnboardingPermission] = []
        if Defaults[.showMirror] { needed.append(.camera) }
        if Defaults[.showCalendar] { needed += [.calendar, .reminders] }
        return needed
    }

    private func go(to next: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.5)) { step = next }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome:
                    WelcomeView { go(to: .features) }
                case .features:
                    FeaturePickerView { go(to: .appearance) }
                case .appearance:
                    AppearanceChoiceView { go(to: neededPermissions.isEmpty ? .finished : .permissions) }
                case .permissions:
                    PermissionsStepView(permissions: neededPermissions) { go(to: .finished) }
                case .finished:
                    OnboardingFinishView(onFinish: onFinish, onOpenSettings: onOpenSettings)
                        // Onboarding is done: until this is cleared the notch won't open (see ContentView.doOpen)
                        .onAppear { NotchlyViewCoordinator.shared.firstLaunch = false }
                }
            }
            .transition(.opacity)

            StepDots(current: step)
                .padding(.top, 6)
                .padding(.bottom, 16)
        }
        .frame(width: Self.width)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { Color.clear.preference(key: OnboardingHeightKey.self, value: $0.size.height) })
        .background { VisualEffectView(material: .hudWindow, blendingMode: .behindWindow).ignoresSafeArea() }
        .ignoresSafeArea()
        .onPreferenceChange(OnboardingHeightKey.self) { height in
            if height > 0 { onHeightChange(height) }
        }
    }
}

private struct StepDots: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(OnboardingStep.allCases.enumerated()), id: \.offset) { _, step in
                Capsule()
                    .fill(step == current ? Color.effectiveAccent : .white.opacity(0.2))
                    .frame(width: step == current ? 18 : 6, height: 6)
            }
        }
        .animation(.smooth, value: current)
    }
}

enum OnboardingPermission: String, Identifiable {
    case camera, calendar, reminders
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .camera: return "camera.fill"
        case .calendar: return "calendar"
        case .reminders: return "checklist"
        }
    }

    var title: String {
        switch self {
        case .camera: return "Camera"
        case .calendar: return "Calendar"
        case .reminders: return "Reminders"
        }
    }

    var reason: String {
        switch self {
        case .camera: return "Shows the mirror live in the notch. Nothing is recorded."
        case .calendar: return "Shows your upcoming events."
        case .reminders: return "Shows your reminders next to your events."
        }
    }

    var isGranted: Bool {
        switch self {
        case .camera: return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        case .calendar: return EKEventStore.authorizationStatus(for: .event) == .fullAccess
        case .reminders: return EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
        }
    }

    var isDenied: Bool {
        switch self {
        case .camera: return AVCaptureDevice.authorizationStatus(for: .video) == .denied
        case .calendar: return EKEventStore.authorizationStatus(for: .event) == .denied
        case .reminders: return EKEventStore.authorizationStatus(for: .reminder) == .denied
        }
    }

    func request() async {
        switch self {
        case .camera: _ = await AVCaptureDevice.requestAccess(for: .video)
        case .calendar: _ = try? await calendarService.requestAccess(to: .event)
        case .reminders: _ = try? await calendarService.requestAccess(to: .reminder)
        }
    }
}

/// One page for every permission the chosen features need, instead of one page each.
struct PermissionsStepView: View {
    let permissions: [OnboardingPermission]
    let onContinue: () -> Void
    @State private var refresh = 0

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("A few permissions")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("Only what the features you picked need. Everything stays on your Mac.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 34)

            VStack(spacing: 10) {
                ForEach(permissions) { permission in row(permission) }
            }
            .padding(.horizontal, 24)
            .id(refresh)

            Button(action: onContinue) {
                Text("Continue")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 6)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
    }

    private func row(_ permission: OnboardingPermission) -> some View {
        HStack(spacing: 12) {
            Image(systemName: permission.icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Color.effectiveAccent.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title).font(.callout.weight(.semibold))
                Text(permission.isDenied ? "Turned off. Change it in System Settings > Privacy & Security." : permission.reason)
                    .font(.caption)
                    .foregroundStyle(permission.isDenied ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if permission.isGranted {
                Label("Allowed", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else if !permission.isDenied {
                Button("Allow") {
                    Task {
                        await permission.request()
                        refresh += 1
                    }
                }
            }
        }
        .padding(10)
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
