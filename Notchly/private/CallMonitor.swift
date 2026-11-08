//
//  CallMonitor.swift
//  Notchly
//
//  FaceTime audio and Phone (iPhone) calls on the Mac both run through the FaceTime app, and macOS has no public
//  call API. So "on a call" means: FaceTime is running and the default microphone is in use.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit
import CoreAudio
import SwiftUI

@MainActor
final class CallMonitor: ObservableObject {
    static let shared = CallMonitor()

    /// When the current call was noticed, nil when there is none.
    @Published private(set) var callStart: Date?

    var isOnCall: Bool { callStart != nil }

    // ponytail: polls every 2s instead of listening to CoreAudio property changes
    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    private func poll() {
        let faceTimeRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.FaceTime" }
        let onCall = faceTimeRunning && Self.microphoneInUse()
        if onCall, callStart == nil {
            callStart = Date()
        } else if !onCall, callStart != nil {
            callStart = nil
        }
    }

    private static func microphoneInUse() -> Bool {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr
        else { return false }
        var running: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        address.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr && running != 0
    }
}
