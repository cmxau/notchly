//
//  OnboardingAppearance.swift
//  Notchly
//
//  Onboarding step that asks how the open notch should look: solid black, or liquid glass.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import Defaults
import SwiftUI

struct AppearanceChoiceView: View {
    let onContinue: () -> Void
    @Default(.notchBackgroundStyle) private var style

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("How should it look?")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text("This is the open notch. The closed notch always stays black, to blend with the camera.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
            .padding(.top, 34)

            HStack(spacing: 14) {
                ForEach(NotchBackgroundStyle.allCases) { option in preview(option) }
            }
            .padding(.horizontal, 24)

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

    /// A small open notch drawn over a colourful wallpaper, so the difference between the two is visible.
    private func preview(_ option: NotchBackgroundStyle) -> some View {
        let selected = style == option
        return Button { withAnimation(.smooth) { style = option } } label: {
            VStack(spacing: 10) {
                ZStack(alignment: .top) {
                    LinearGradient(colors: [.pink, .orange, .purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    ZStack {
                        if option == .black {
                            Color.black
                        } else {
                            Rectangle().fill(.ultraThinMaterial)
                            Rectangle().fill(.black.opacity(0.25))
                        }
                        VStack(spacing: 6) {
                            HStack(spacing: 6) {
                                ForEach(0..<3, id: \.self) { _ in Circle().fill(.white.opacity(0.7)).frame(width: 7, height: 7) }
                                Spacer()
                            }
                            RoundedRectangle(cornerRadius: 5).fill(.white.opacity(0.18)).frame(height: 30)
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.18))
                                RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.18))
                            }
                            .frame(height: 12)
                        }
                        .padding(10)
                    }
                    .frame(width: 120, height: 92)
                    .clipShape(NotchShape(topCornerRadius: 8, bottomCornerRadius: 18))
                }
                .frame(width: 150, height: 110)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Color.effectiveAccent : .white.opacity(0.1), lineWidth: selected ? 2.5 : 1))

                HStack(spacing: 5) {
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? Color.effectiveAccent : .secondary)
                    Text(option.rawValue).font(.callout.weight(.semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
