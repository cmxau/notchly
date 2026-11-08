//
//  NotchlyMark.swift
//  Notchly
//
//  The Notchly logo: a heavy N cut from three pieces (a stem with a chamfered corner, a diagonal bar and a
//  second stem), the same N as the app icon. The pieces can build in one after another.
//  (Lives in `private/` because that folder is auto-included in the Xcode target.)
//

import SwiftUI

private struct PolyShape: Shape {
    /// Points in a unit box that is 1 wide and `NotchlyMark.height` tall.
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.minX + first.x * rect.width, y: rect.minY + first.y * rect.width))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.width))
        }
        path.closeSubpath()
        return path
    }
}

struct NotchlyMark: View {
    var color: Color = .white
    /// When true the three pieces build in; when false they are drawn at once.
    var animated = false

    /// Height of the letter relative to its width.
    static let height: CGFloat = 0.97

    private static let stem: CGFloat = 0.21
    private static let gap: CGFloat = 0.04
    private static let diagonal: CGFloat = 0.27
    private static var chamfer: CGFloat { stem * 0.85 }

    private static let leftStem: [CGPoint] = {
        let h = height
        return [CGPoint(x: 0, y: h), CGPoint(x: stem, y: h), CGPoint(x: stem, y: 0), CGPoint(x: chamfer, y: 0), CGPoint(x: 0, y: chamfer)]
    }()
    private static let bar: [CGPoint] = {
        let a = stem + gap, b = 1 - stem - gap
        return [CGPoint(x: a, y: 0), CGPoint(x: a + diagonal, y: 0), CGPoint(x: b, y: height), CGPoint(x: b - diagonal, y: height)]
    }()
    private static let rightStem: [CGPoint] = {
        let h = height
        return [CGPoint(x: 1 - stem, y: 0), CGPoint(x: 1, y: 0), CGPoint(x: 1, y: h - chamfer),
                CGPoint(x: 1 - chamfer, y: h), CGPoint(x: 1 - stem, y: h)]
    }()

    @State private var shown = [false, false, false]

    var body: some View {
        GeometryReader { geo in
            let rise = geo.size.height * 0.35
            ZStack {
                PolyShape(points: Self.leftStem).fill(color)
                    .offset(y: shown[0] ? 0 : rise).opacity(shown[0] ? 1 : 0)
                PolyShape(points: Self.bar).fill(color)
                    .scaleEffect(y: shown[1] ? 1 : 0.01, anchor: .top).opacity(shown[1] ? 1 : 0)
                PolyShape(points: Self.rightStem).fill(color)
                    .offset(y: shown[2] ? 0 : -rise).opacity(shown[2] ? 1 : 0)
            }
        }
        .aspectRatio(1 / Self.height, contentMode: .fit)
        .task {
            guard animated else {
                shown = [true, true, true]
                return
            }
            for i in 0..<3 {
                try? await Task.sleep(for: .milliseconds(i == 0 ? 0 : 160))
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { shown[i] = true }
            }
        }
    }
}
