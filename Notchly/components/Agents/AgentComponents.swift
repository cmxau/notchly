//
//  AgentComponents.swift
//  Notchly
//
//  Pieces shared by the agent views: buttons, status icons and card headers.
//

import SwiftUI

struct AgentButton: View {
    enum Role {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let systemImage: String
    let role: Role
    let action: () -> Void
    @State private var isHovering = false

    init(_ title: String, systemImage: String, role: Role, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(foreground)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(background.opacity(isHovering ? 1 : 0.85)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var foreground: Color {
        role == .primary ? .black : .white
    }

    private var background: Color {
        switch role {
        case .primary: return .white
        case .secondary: return Color.white.opacity(0.14)
        case .destructive: return Color.red.opacity(0.35)
        }
    }
}

/// The agent's icon with its state. While it works: a pulsing glow, a spinning gradient ring and a breathing icon.
/// A dot when it needs you, a tick (that pops in) when it's done.
struct AgentStatusIcon: View {
    let kind: AgentKind
    let status: AgentStatus
    let size: CGFloat

    @State private var popped = false

    var body: some View {
        ZStack {
            switch status {
            case .working:
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [.orange.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: size * 0.7))
                            .scaleEffect(1 + 0.18 * sin(t * 3))
                        Circle()
                            .trim(from: 0, to: 0.72)
                            .stroke(
                                AngularGradient(colors: [.orange.opacity(0), .orange, .yellow], center: .center),
                                style: StrokeStyle(lineWidth: max(1.5, size * 0.1), lineCap: .round))
                            .rotationEffect(.degrees(t * 330))
                        symbol.scaleEffect(1 + 0.07 * sin(t * 3))
                    }
                }
            case .waitingForApproval, .waitingForInput:
                TimelineView(.animation) { context in
                    let pulse = (sin(context.date.timeIntervalSinceReferenceDate * 4) + 1) / 2
                    ZStack {
                        Circle().stroke(Color.orange.opacity(0.4 + 0.6 * pulse), lineWidth: max(1.5, size * 0.09))
                        symbol
                        Circle()
                            .fill(Color.orange)
                            .frame(width: size * 0.3, height: size * 0.3)
                            .scaleEffect(1 + 0.25 * pulse)
                            .offset(x: size * 0.36, y: -size * 0.36)
                    }
                }
            case .finished:
                ZStack {
                    Circle().stroke(Color.green.opacity(0.8), lineWidth: max(1.5, size * 0.09))
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.green)
                        .scaleEffect(popped ? 1 : 0.2)
                        .opacity(popped ? 1 : 0)
                }
                .onAppear { withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { popped = true } }
                .onDisappear { popped = false }
            case .idle:
                ZStack {
                    Circle().stroke(Color.white.opacity(0.2), lineWidth: max(1.5, size * 0.09))
                    symbol.opacity(0.6)
                }
            }
        }
        .frame(width: size, height: size)
    }

    private var symbol: some View {
        Image(systemName: kind.symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.5, height: size * 0.5)
            .foregroundStyle(.white)
    }
}

/// Three dots that bounce in turn: the agent is thinking.
struct ThinkingDots: View {
    var color: Color = .white.opacity(0.7)

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    let wave = (sin(t * 6 - Double(i) * 0.9) + 1) / 2
                    Circle()
                        .fill(color)
                        .frame(width: 4, height: 4)
                        .offset(y: -2.5 * wave)
                        .opacity(0.4 + 0.6 * wave)
                }
            }
        }
    }
}

/// A thin light that sweeps along the bottom edge while an agent works.
struct WorkingSweep: View {
    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let progress = (t * 0.55).truncatingRemainder(dividingBy: 1.4) - 0.2
                Capsule()
                    .fill(LinearGradient(colors: [.clear, .orange, .yellow, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * 0.35, height: 2)
                    .offset(x: geo.size.width * progress, y: geo.size.height - 2)
            }
            .clipped()
        }
        .allowsHitTesting(false)
    }
}

extension AgentStatus {
    var label: String {
        switch self {
        case .idle: return "Idle"
        case .working: return "Working"
        case .waitingForApproval: return "Needs approval"
        case .waitingForInput: return "Needs your input"
        case .finished: return "Done"
        }
    }

    var tint: Color {
        switch self {
        case .idle: return .gray
        case .working: return .white.opacity(0.7)
        case .waitingForApproval, .waitingForInput: return .orange
        case .finished: return .green
        }
    }
}

struct AgentCardHeader: View {
    let session: AgentSession?
    let agent: AgentKind
    let pendingCount: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: agent.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
            Text(agent.displayName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
            if let session {
                Text("·  \(session.projectName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if pendingCount > 1 {
                Text("+\(pendingCount - 1) waiting")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.orange.opacity(0.15)))
            }
        }
    }
}
