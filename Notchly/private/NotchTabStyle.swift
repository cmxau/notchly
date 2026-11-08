//
//  NotchTabStyle.swift
//  Notchly
//
//  Shared look for the Notchly tabs (Teleprompter, Clipboard, Timer, Weather): soft cards and round buttons.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import SwiftUI

extension View {
    /// A soft rounded card.
    func notchCard(padding: CGFloat = 10) -> some View {
        self.padding(padding)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.06)))
    }
}

/// A round icon button; `prominent` fills it with the accent colour.
struct RoundButtonStyle: ButtonStyle {
    var prominent = false
    var size: CGFloat = 32

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : Color.white.opacity(0.9))
            .frame(width: size, height: size)
            .background(Circle().fill(prominent ? Color.effectiveAccent : Color.white.opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
