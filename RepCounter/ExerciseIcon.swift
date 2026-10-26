import SwiftUI

/// Pictogramme d'un exercice. SF Symbols n'a ni pompes ni développé au-dessus de la tête :
/// ces deux-là sont dessinés (repère 20 × 20, mêmes tracés que Design/mockups/screens.html).
struct ExerciseIcon: View {
    let exercise: Exercise
    var size: CGFloat = 22

    var body: some View {
        switch exercise {
        case .pushups, .press:
            Canvas { context, canvas in
                let scale = min(canvas.width, canvas.height) / 20
                context.scaleBy(x: scale, y: scale)
                if exercise == .pushups { Self.drawPushup(context) } else { Self.drawPress(context) }
            }
            .frame(width: size, height: size)
        default:
            Image(systemName: exercise.symbol)
                .font(.system(size: size * 0.9, weight: .semibold))
                .frame(width: size, height: size)
        }
    }

    private static let limb = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

    /// De profil, en planche : tête, corps tendu des épaules aux pieds, bras tendu, sol.
    private static func drawPushup(_ context: GraphicsContext) {
        var context = context
        context.fill(Path(ellipseIn: CGRect(x: 1.5, y: 5.7, width: 3.8, height: 3.8)), with: .foreground)
        var body = Path()
        body.move(to: CGPoint(x: 5.8, y: 9.4)); body.addLine(to: CGPoint(x: 18.4, y: 16.2))
        body.move(to: CGPoint(x: 6.2, y: 9.6)); body.addLine(to: CGPoint(x: 6.6, y: 16.2))
        context.stroke(body, with: .foreground, style: limb)
        var floor = Path()
        floor.move(to: CGPoint(x: 1.5, y: 17.6)); floor.addLine(to: CGPoint(x: 18.5, y: 17.6))
        context.opacity = 0.55
        context.stroke(floor, with: .foreground, style: StrokeStyle(lineWidth: 1, lineCap: .round))
    }

    /// De face, barre tenue bras tendus au-dessus de la tête.
    private static func drawPress(_ context: GraphicsContext) {
        context.fill(Path(ellipseIn: CGRect(x: 8.1, y: 5.3, width: 3.8, height: 3.8)), with: .foreground)
        var bar = Path()
        bar.move(to: CGPoint(x: 2.5, y: 2.6)); bar.addLine(to: CGPoint(x: 17.5, y: 2.6))
        context.stroke(bar, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        for x in [2.6, 15.4] {
            context.fill(Path(roundedRect: CGRect(x: x, y: 0.8, width: 2, height: 3.6), cornerRadius: 0.6), with: .foreground)
        }
        var figure = Path()
        figure.addLines([CGPoint(x: 6.2, y: 2.8), CGPoint(x: 7.6, y: 10), CGPoint(x: 12.4, y: 10), CGPoint(x: 13.8, y: 2.8)])
        figure.move(to: CGPoint(x: 10, y: 10)); figure.addLine(to: CGPoint(x: 10, y: 13.4))
        figure.addLines([CGPoint(x: 7.6, y: 18.6), CGPoint(x: 10, y: 13.4), CGPoint(x: 12.4, y: 18.6)])
        context.stroke(figure, with: .foreground, style: limb)
    }
}
