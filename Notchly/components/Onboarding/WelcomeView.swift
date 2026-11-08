//
//  WelcomeView.swift
//  Notchly
//
//  A notch drops from the top of the window, opens, and the Notchly N builds itself inside it.
//

import SwiftUI

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil

    private let features: [(icon: String, name: String)] = [
        ("music.note", "Music"), ("calendar", "Calendar"),
        ("terminal.fill", "AI agents"), ("text.alignleft", "Teleprompter"),
    ]

    @State private var opened = false
    @State private var showMark = false
    @State private var showText = false
    @State private var shownChips = 0

    var body: some View {
        VStack(spacing: 0) {
            // The notch: starts as a closed notch, then opens
            ZStack {
                NotchShape(topCornerRadius: 10, bottomCornerRadius: opened ? 34 : 14)
                    .fill(.black)
                    .shadow(color: Color.effectiveAccent.opacity(opened ? 0.45 : 0), radius: 24, y: 8)
                if showMark {
                    NotchlyMark(color: Color.effectiveAccent, animated: true)
                        .frame(width: 70)
                        .padding(.top, 14)
                }
            }
            .frame(width: opened ? 230 : 130, height: opened ? 128 : 30)

            VStack(spacing: 6) {
                (Text("Hi, I'm ") + Text("Notchly").foregroundStyle(Color.effectiveAccent))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Your notch, doing more.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 30)
            .opacity(showText ? 1 : 0)
            .offset(y: showText ? 0 : 12)

            HStack(spacing: 8) {
                ForEach(Array(features.enumerated()), id: \.offset) { index, feature in
                    Label(feature.name, systemImage: feature.icon)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.1), in: Capsule())
                        .opacity(index < shownChips ? 1 : 0)
                        .scaleEffect(index < shownChips ? 1 : 0.7)
                }
            }
            .padding(.top, 22)

            Button {
                onGetStarted?()
            } label: {
                Text("Get started")
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
            }
            .buttonStyle(BorderedProminentButtonStyle())
            .padding(.top, 28)
            .padding(.bottom, 8)
            .opacity(shownChips >= features.count ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .task {
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) { opened = true }
            try? await Task.sleep(for: .milliseconds(350))
            showMark = true
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.smooth(duration: 0.5)) { showText = true }
            for i in 1...features.count {
                try? await Task.sleep(for: .milliseconds(160))
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { shownChips = i }
            }
        }
    }
}

#Preview {
    WelcomeView()
}
