//
//  Teleprompter.swift
//  Notchly
//
//  Teleprompter in the open notch, modelled on https://github.com/f/textream (MIT).
//  Three guidance modes: word tracking (speech recognition), classic auto-scroll, voice-activated scroll.
//  (File lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AVFoundation
import Defaults
import Speech
import SwiftUI

enum TeleprompterMode: String, CaseIterable, Identifiable, Defaults.Serializable {
    case tracking = "Word tracking"
    case classic = "Classic"
    case voice = "Voice-activated"
    var id: String { rawValue }
    var needsMic: Bool { self != .classic }
}

extension Defaults.Keys {
    static let teleprompterScript = Key<String>("teleprompterScript", default: "")
    static let teleprompterMode = Key<TeleprompterMode>("teleprompterMode", default: .tracking)
    /// Words per second for Classic and Voice-activated.
    static let teleprompterSpeed = Key<Double>("teleprompterSpeed", default: 2)
}

/// Owns the audio engine. Not main-actor isolated: the tap runs on the audio thread.
private final class Mic: @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var _request: SFSpeechAudioBufferRecognitionRequest?
    private var _lastVoice = Date.distantPast

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { _request } }
        set { lock.withLock { _request = newValue } }
    }
    var lastVoice: Date { lock.withLock { _lastVoice } }

    func start() throws {
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [self] buffer, _ in
            request?.append(buffer)
            guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for i in 0..<Int(buffer.frameLength) { sum += samples[i] * samples[i] }
            // ponytail: fixed RMS threshold, add a sensitivity setting if quiet mics miss speech
            if (sum / Float(buffer.frameLength)).squareRoot() > 0.015 { lock.withLock { _lastVoice = Date() } }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
    }
}

@MainActor
final class Teleprompter: ObservableObject {
    static let shared = Teleprompter()

    /// Index of the word being read.
    @Published private(set) var position = 0
    @Published private(set) var isRunning = false
    @Published var error: String?

    private let mic = Mic()
    private var timer: Timer?
    private var task: SFSpeechRecognitionTask?
    private var credit = 0.0
    private var sessionStart = 0
    /// When the user last scrolled by hand; auto-scrolling waits a moment after that.
    private var lastManualScroll = Date.distantPast

    static func words(_ script: String) -> [String] { script.split(whereSeparator: \.isWhitespace).map(String.init) }

    func toggle() {
        if isRunning { stop() } else { Task { await start() } }
    }

    /// Jumps to a point in the script (0...1, by characters), e.g. from scrolling by hand. Carries on from there.
    func seek(toFraction fraction: Double) {
        let words = Self.words(Defaults[.teleprompterScript])
        let total = words.reduce(0) { $0 + $1.count + 1 }
        guard total > 0 else { return }
        let target = Int(max(0, min(1, fraction)) * Double(total))
        var passed = 0
        var index = words.count - 1
        for (i, word) in words.enumerated() {
            passed += word.count + 1
            if passed > target { index = i; break }
        }
        position = index
        credit = 0
        lastManualScroll = Date()
        // Word tracking matches speech against the script from where recognition started
        if isRunning, Defaults[.teleprompterMode] == .tracking { recognize() }
    }

    func reset() {
        stop()
        position = 0
    }

    private func start() async {
        let mode = Defaults[.teleprompterMode]
        let count = Self.words(Defaults[.teleprompterScript]).count
        guard count > 0 else { error = "Add a script first"; return }
        error = nil
        if position >= count { position = 0 }

        if mode.needsMic {
            guard await AVCaptureDevice.requestAccess(for: .audio) else { error = "Microphone access denied"; return }
            if mode == .tracking {
                let ok = await withCheckedContinuation { c in
                    SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
                }
                guard ok else { error = "Speech recognition access denied"; return }
            }
            do {
                if mode == .tracking { guard recognize() else { return } }
                try mic.start()
            } catch {
                self.error = error.localizedDescription
                return
            }
        }

        isRunning = true
        if mode != .tracking {
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick(mode) }
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        task = nil
        mic.stop()
        isRunning = false
    }

    /// Classic and voice-activated: advance at `teleprompterSpeed` words/s, voice only while sound is heard.
    private func tick(_ mode: TeleprompterMode) {
        guard Date().timeIntervalSince(lastManualScroll) > 0.8 else { return }
        if mode == .voice, Date().timeIntervalSince(mic.lastVoice) > 0.5 { return }
        credit += Defaults[.teleprompterSpeed] * 0.05
        guard credit >= 1 else { return }
        credit -= 1
        advance(to: position + 1)
    }

    private func advance(to new: Int) {
        let count = Self.words(Defaults[.teleprompterScript]).count
        position = min(count, new)
        if position >= count { stop() }
    }

    /// Starts (or restarts, recognition sessions are time-limited) a recognition task from the current position.
    @discardableResult
    private func recognize() -> Bool {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            error = "Speech recognition isn't available for this language"
            return false
        }
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        mic.request?.endAudio()
        mic.request = request
        sessionStart = position
        task?.cancel()
        task = recognizer.recognitionTask(with: request) { [weak self] result, err in
            let text = result?.bestTranscription.formattedString
            let done = err != nil || result?.isFinal == true
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                if let text { self.track(text) }
                if done {
                    try? await Task.sleep(for: .seconds(err == nil ? 0 : 1))
                    if self.isRunning { self.recognize() }
                }
            }
        }
        return true
    }

    /// Matches what was said this session against the script, allowing a few skipped words.
    private func track(_ spoken: String) {
        let script = Self.words(Defaults[.teleprompterScript]).map(Self.normalize)
        var pos = sessionStart
        for token in spoken.split(whereSeparator: \.isWhitespace).map(Self.normalize) where !token.isEmpty {
            if let i = (pos..<min(script.count, pos + 4)).first(where: { script[$0] == token }) { pos = i + 1 }
        }
        if pos > position { advance(to: pos) }
    }

    private static func normalize<S: StringProtocol>(_ s: S) -> String {
        s.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

/// Floating (draggable, resizable, always on top) or fullscreen teleprompter. Esc closes it.
@MainActor
enum TeleprompterWindow {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }

        /// Esc closes the teleprompter. Caught here, before the event reaches the SwiftUI view, which doesn't
        /// reliably get it in a borderless window.
        override func sendEvent(_ event: NSEvent) {
            if event.type == .keyDown, event.keyCode == 53 {
                Task { @MainActor in
                    Teleprompter.shared.stop()
                    TeleprompterWindow.close()
                }
                return
            }
            super.sendEvent(event)
        }
    }

    private static var panel: NSPanel?

    static func show(fullscreen: Bool) {
        close()
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = fullscreen
            ? screen.frame
            : NSRect(x: screen.frame.midX - 270, y: screen.frame.maxY - 300, width: 540, height: 200)
        let panel = Panel(
            contentRect: frame,
            styleMask: fullscreen ? [.borderless] : [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = fullscreen ? .statusBar : .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.black.withAlphaComponent(fullscreen ? 1 : 0.88)
        panel.contentView = NSHostingView(
            rootView: TeleprompterView(fontSize: fullscreen ? 52 : 24, lines: fullscreen ? 8 : 5, inWindow: true)
                .padding(fullscreen ? 60 : 16)
                .preferredColorScheme(.dark))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
    }

    static func close() {
        panel?.close()
        panel = nil
    }
}

/// Catches the scroll wheel / trackpad over the script.
private struct ScrollCatcher: NSViewRepresentable {
    var onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: NSView, context: Context) { (view as? CatcherView)?.onScroll = onScroll }

    final class CatcherView: NSView {
        var onScroll: ((CGFloat) -> Void)?
        override func scrollWheel(with event: NSEvent) {
            onScroll?(event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 10))
        }
    }
}

private struct ScriptHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct TeleprompterView: View {
    var fontSize: CGFloat = 20
    var lines = 4
    /// Already in a floating/fullscreen window, so the buttons to open one are hidden.
    var inWindow = false
    @ObservedObject private var tp = Teleprompter.shared
    @Default(.teleprompterScript) private var script
    @Default(.teleprompterMode) private var mode

    /// The whole script, only recoloured as you read, so the text never reflows.
    private var text: AttributedString {
        let words = Teleprompter.words(script)
        var out = AttributedString()
        for (i, word) in words.enumerated() {
            var w = AttributedString(word + " ")
            w.foregroundColor = i < tp.position ? Color.gray : i == tp.position ? Color.effectiveAccent : Color.white
            out += w
        }
        return out
    }

    /// How far through the script the reading position is, by characters.
    private var fraction: CGFloat {
        let words = Teleprompter.words(script)
        let total = words.reduce(0) { $0 + $1.count + 1 }
        guard total > 0 else { return 0 }
        return CGFloat(words.prefix(tp.position).reduce(0) { $0 + $1.count + 1 }) / CGFloat(total)
    }

    @State private var contentHeight: CGFloat = 0
    /// Scrolling that hasn't added up to a whole word yet.
    @State private var carry: CGFloat = 0

    // ponytail: the scroll position is estimated from the character count, so it can drift by a line on
    // scripts with very uneven line lengths
    private func scrollOffset(viewport: CGFloat) -> CGFloat {
        let target = fraction * contentHeight - viewport * 0.3
        return min(max(0, target), max(0, contentHeight - viewport))
    }

    private var scroller: some View {
        GeometryReader { geo in
            Text(text)
                .font(.system(size: fontSize, weight: .semibold))
                .frame(width: geo.size.width, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .background(GeometryReader { inner in Color.clear.preference(key: ScriptHeightKey.self, value: inner.size.height) })
                .onPreferenceChange(ScriptHeightKey.self) { contentHeight = $0 }
                .offset(y: -scrollOffset(viewport: geo.size.height))
                .animation(.linear(duration: 0.45), value: tp.position)
        }
        .clipped()
        .overlay {
            ScrollCatcher { dy in
                carry -= dy / max(1, contentHeight)
                let before = tp.position
                tp.seek(toFraction: Double(fraction + carry))
                if tp.position != before { carry = 0 }
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                if script.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "text.alignleft").font(.title2)
                        Text("No script yet. Write one in Settings → Teleprompter.")
                            .multilineTextAlignment(.center)
                        Button("Paste from clipboard") {
                            script = NSPasteboard.general.string(forType: .string) ?? ""
                        }
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    scroller
                    ProgressView(value: Double(tp.position), total: Double(max(1, Teleprompter.words(script).count)))
                        .tint(Color.effectiveAccent)
                }
            }
            .notchCard(padding: 12)

            VStack(spacing: 10) {
                Button { tp.toggle() } label: { Image(systemName: tp.isRunning ? "pause.fill" : "play.fill") }
                    .buttonStyle(RoundButtonStyle(prominent: true, size: 42))
                HStack(spacing: 8) {
                    Button { tp.reset() } label: { Image(systemName: "backward.end.fill") }
                        .buttonStyle(RoundButtonStyle(size: 28))
                        .help("Back to the start")
                    Menu {
                        Picker("Guidance", selection: $mode) {
                            ForEach(TeleprompterMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: mode == .tracking ? "waveform" : mode == .voice ? "mic.fill" : "arrow.down.to.line")
                    }
                    .menuStyle(.button)
                    .buttonStyle(RoundButtonStyle(size: 28))
                    .menuIndicator(.hidden)
                    .help(mode.rawValue)
                }
                if !inWindow {
                    HStack(spacing: 8) {
                        Button { TeleprompterWindow.show(fullscreen: false) } label: { Image(systemName: "macwindow") }
                            .help("Floating window")
                        Button { TeleprompterWindow.show(fullscreen: true) } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                            .help("Fullscreen (Esc to close)")
                    }
                    .buttonStyle(RoundButtonStyle(size: 28))
                }
                if let error = tp.error {
                    Text(error).font(.caption2).foregroundStyle(.red).frame(width: 90)
                }
            }
        }
        .onExitCommand {
            guard inWindow else { return }
            tp.stop()
            TeleprompterWindow.close()
        }
    }
}

struct TeleprompterSettings: View {
    @Default(.teleprompterScript) private var script
    @Default(.teleprompterMode) private var mode
    @Default(.teleprompterSpeed) private var speed

    var body: some View {
        Form {
            Section {
                Picker("Guidance", selection: $mode) {
                    ForEach(TeleprompterMode.allCases) { Text($0.rawValue).tag($0) }
                }
                if mode != .tracking {
                    Slider(value: $speed, in: 0.5...8, step: 0.5) {
                        Text("Speed - \(speed, specifier: "%.1f") words/s")
                    }
                }
            } header: {
                Text("Reading")
            } footer: {
                Text("Word tracking highlights each word as you say it and needs microphone and speech recognition access. Voice-activated scrolls only while you speak.")
            }
            Section {
                Button("Open floating window") { TeleprompterWindow.show(fullscreen: false) }
                Button("Open fullscreen (Esc to close)") { TeleprompterWindow.show(fullscreen: true) }
            } header: {
                Text("Display")
            }
            Section {
                TextEditor(text: $script)
                    .font(.body)
                    .frame(minHeight: 220)
            } header: {
                Text("Script")
            }
        }
        .navigationTitle("Teleprompter")
    }
}
