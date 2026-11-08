//
//  OnboardingFinishView.swift
//  Notchly
//
//  Created by Alexander on 2025-06-23.
//

import SwiftUI

struct OnboardingFinishView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            NotchlyMark(color: Color.effectiveAccent, animated: true)
                .frame(width: 64)
                .padding(.top, 44)
                .padding(.bottom, 6)

            Text("You're all set")
                .font(.system(size: 26, weight: .bold, design: .rounded))

            Text("Move the pointer to the top of the screen to open the notch. Everything you picked is in Settings if you want to change it.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 10) {
                Button("Finish", action: onFinish)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                Button(action: onOpenSettings) {
                    Label("Customize in Settings", systemImage: "gear")
                }
                .controlSize(.large)
            }
            .padding(.top, 14)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    OnboardingFinishView(onFinish: { }, onOpenSettings: { })
}
