//
//  FocusTimer.swift
//  Notchly
//
//  Pomodoro timer: focus and break rounds that run back to back. While it runs, the closed notch shows the time left.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import AppKit
import Defaults
import SwiftUI

extension Defaults.Keys {
    static let focusMinutes = Key<Int>("focusMinutes", default: 25)
    static let breakMinutes = Key<Int>("breakMinutes", default: 5)
}

@MainActor
final class FocusTimer: ObservableObject {
    static let shared = FocusTimer()

    enum Phase: String { case focus = "Focus", rest = "Break" }

    @Published private(set) var phase: Phase = .focus
    /// Set while running.
    @Published private(set) var endDate: Date?
    @Published private(set) var pausedRemaining = TimeInterval(Defaults[.focusMinutes] * 60)

    var isRunning: Bool { endDate != nil }
    /// Running, or paused part-way through a round.
    var isActive: Bool { isRunning || pausedRemaining < length }

    private var timer: Timer?

    var length: TimeInterval {
        TimeInterval((phase == .focus ? Defaults[.focusMinutes] : Defaults[.breakMinutes]) * 60)
    }

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func remaining(at date: Date) -> TimeInterval {
        endDate.map { max(0, $0.timeIntervalSince(date)) } ?? pausedRemaining
    }

    func progress(at date: Date) -> Double {
        1 - remaining(at: date) / max(1, length)
    }

    /// Named focus/break pairs.
    static let presets: [(name: String, icon: String, focus: Int, rest: Int)] = [
        ("Quick", "bolt.fill", 15, 3), ("Classic", "timer", 25, 5), ("Long", "flame.fill", 50, 10), ("Deep", "moon.stars.fill", 90, 15),
    ]

    func apply(focus: Int, rest: Int) {
        Defaults[.focusMinutes] = focus
        Defaults[.breakMinutes] = rest
        reset()
    }

    func toggle() {
        if let end = endDate {
            pausedRemaining = max(0, end.timeIntervalSinceNow)
            endDate = nil
        } else {
            endDate = Date().addingTimeInterval(pausedRemaining)
        }
    }

    func reset() {
        endDate = nil
        pausedRemaining = length
    }

    /// Jumps to the other phase without starting it.
    func skip() {
        phase = phase == .focus ? .rest : .focus
        reset()
    }

    private func tick() {
        guard let end = endDate, end <= Date() else { return }
        NSSound(named: "Glass")?.play()
        phase = phase == .focus ? .rest : .focus
        endDate = Date().addingTimeInterval(length)
    }
}

struct TimerTabView: View {
    @ObservedObject private var timer = FocusTimer.shared
    @Default(.focusMinutes) private var focusMinutes
    @Default(.breakMinutes) private var breakMinutes

    private var tint: Color { timer.phase == .focus ? Color.effectiveAccent : .green }

    var body: some View {
        // Everything is sized from the space the notch gives this tab, so it can never grow past it
        GeometryReader { geo in
            let height = geo.size.height
            let ring = max(60, min(104, height - 28))
            HStack(spacing: 12) {
                HStack(spacing: 16) {
                    timerRing(size: ring)
                    VStack(spacing: 10) {
                        Button { timer.toggle() } label: { Image(systemName: timer.isRunning ? "pause.fill" : "play.fill") }
                            .buttonStyle(RoundButtonStyle(prominent: true, size: 46))
                        HStack(spacing: 8) {
                            Button { timer.reset() } label: { Image(systemName: "arrow.counterclockwise") }
                                .buttonStyle(RoundButtonStyle(size: 28))
                                .help("Reset")
                            Button { timer.skip() } label: { Image(systemName: "forward.end.fill") }
                                .buttonStyle(RoundButtonStyle(size: 28))
                                .help("Switch between focus and break")
                        }
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: height)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.06)))

                VStack(spacing: 8) {
                    ForEach([0, 2], id: \.self) { row in
                        HStack(spacing: 8) {
                            presetCard(FocusTimer.presets[row])
                            presetCard(FocusTimer.presets[row + 1])
                        }
                    }
                }
                .frame(height: height)
            }
            .frame(width: geo.size.width, height: height)
        }
    }

    private func timerRing(size: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: timer.progress(at: context.date))
                    .stroke(tint, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress(at: context.date))
                VStack(spacing: 0) {
                    Text(Self.format(timer.remaining(at: context.date)))
                        .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                        .minimumScaleFactor(0.6)
                    Text(timer.phase.rawValue.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(tint)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private func presetCard(_ preset: (name: String, icon: String, focus: Int, rest: Int)) -> some View {
        let selected = focusMinutes == preset.focus && breakMinutes == preset.rest
        return Button { timer.apply(focus: preset.focus, rest: preset.rest) } label: {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: preset.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selected ? .white : tint)
                    Text(preset.name).font(.callout.weight(.semibold))
                    Spacer(minLength: 0)
                    Text("\(preset.focus + preset.rest) min")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                }
                Text("\(preset.focus) focus · \(preset.rest) break")
                    .font(.caption)
                    .foregroundStyle(selected ? .white.opacity(0.85) : .secondary)
                // Focus and break as parts of one round
                GeometryReader { geo in
                    let focusWidth = geo.size.width * CGFloat(preset.focus) / CGFloat(preset.focus + preset.rest)
                    HStack(spacing: 2) {
                        Capsule().fill(selected ? Color.white : tint).frame(width: max(0, focusWidth - 1))
                        Capsule().fill(selected ? Color.white.opacity(0.45) : Color.green.opacity(0.8))
                    }
                }
                .frame(height: 4)
            }
            .minimumScaleFactor(0.8)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(selected ? tint.opacity(0.9) : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(selected ? 0 : 0.06)))
            .clipped()
        }
        .buttonStyle(.plain)
        .help("\(preset.focus) min focus, \(preset.rest) min break")
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
