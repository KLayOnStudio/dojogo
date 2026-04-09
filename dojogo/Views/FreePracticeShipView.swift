import SwiftUI

struct FreePracticeShipView: View {
    let onTap: () -> Void
    var bobOffset: CGFloat = 0
    var swayOffset: CGFloat = 0

    var body: some View {
        Button(action: onTap) {
            Image("boat")
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .offset(x: swayOffset, y: bobOffset)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
