import SwiftUI

/// Pictogramme d'un exercice. SF Symbols n'a ni pompes, ni développé au-dessus de la tête, ni
/// fentes, tractions, dips ou rowing : ceux-là sont dessinés (repère 20 × 20, mêmes tracés que
/// Design/mockups/screens.html).
struct ExerciseIcon: View {
    let exercise: Exercise
    var size: CGFloat = 22

    var body: some View {
        switch exercise {
        case .pushups, .press, .lunges, .pullups, .dips, .row:
            Canvas { context, canvas in
                let scale = min(canvas.width, canvas.height) / 20
                context.scaleBy(x: scale, y: scale)
                Self.draw(exercise, in: context)
            }
            .frame(width: size, height: size)
        default:
            Image(systemName: exercise.symbol)
                .font(.system(size: size * 0.9, weight: .semibold))
                .frame(width: size, height: size)
        }
    }

    private static let limb = StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)

    private static func draw(_ exercise: Exercise, in context: GraphicsContext) {
        switch exercise {
        case .pushups: drawPushup(context)
        case .press: drawPress(context)
        case .lunges: drawLunge(context)
        case .pullups: drawPullup(context)
        case .dips: drawDips(context)
        case .row: drawRow(context)
        default: break
        }
    }

    // Éléments communs

    private static func head(_ context: GraphicsContext, x: CGFloat, y: CGFloat) {
        context.fill(Path(ellipseIn: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6)), with: .foreground)
    }

    /// Membres : une ligne brisée par tableau de points.
    private static func limbs(_ context: GraphicsContext, _ lines: [[CGPoint]]) {
        var path = Path()
        for line in lines { path.addLines(line) }
        context.stroke(path, with: .foreground, style: limb)
    }

    /// Barre ou poignées (trait plus fin).
    private static func bars(_ context: GraphicsContext, _ lines: [[CGPoint]]) {
        var path = Path()
        for line in lines { path.addLines(line) }
        context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    /// Sol ou montants, en retrait.
    private static func faint(_ context: GraphicsContext, _ lines: [[CGPoint]], width: CGFloat) {
        var context = context
        context.opacity = 0.55
        var path = Path()
        for line in lines { path.addLines(line) }
        context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// De profil, en fente : jambe avant pliée à angle droit, genou arrière près du sol.
    private static func drawLunge(_ context: GraphicsContext) {
        head(context, x: 9.6, y: 2.9)
        limbs(context, [[p(9.6, 5.2), p(9.6, 10.6), p(13.8, 12.8), p(13.8, 17.2)],
                        [p(9.6, 10.6), p(6.6, 15.6), p(2.8, 15.8)]])
        faint(context, [[p(1.5, 18.4), p(18.5, 18.4)]], width: 1)
    }

    /// De face, suspendu à la barre, bras pliés.
    private static func drawPullup(_ context: GraphicsContext) {
        bars(context, [[p(2.5, 2.4), p(17.5, 2.4)]])
        head(context, x: 10, y: 5.7)
        limbs(context, [[p(6.4, 2.6), p(8.2, 8.6), p(11.8, 8.6), p(13.6, 2.6)],
                        [p(10, 8.6), p(10, 13.6)],
                        [p(8.7, 18.4), p(10, 13.6), p(11.3, 18.4)]])
    }

    /// De face, en appui sur deux barres parallèles.
    private static func drawDips(_ context: GraphicsContext) {
        faint(context, [[p(3.4, 10), p(3.4, 18.6)], [p(16.6, 10), p(16.6, 18.6)]], width: 1.2)
        bars(context, [[p(2.5, 10), p(6.2, 10)], [p(13.8, 10), p(17.5, 10)]])
        head(context, x: 10, y: 3.4)
        limbs(context, [[p(5.2, 10), p(8, 6.2), p(12, 6.2), p(14.8, 10)],
                        [p(10, 6.2), p(10, 12.6)],
                        [p(8.8, 18), p(10, 12.6), p(11.2, 18)]])
    }

    /// De profil, buste penché, coude qui tire l'haltère vers la hanche.
    private static func drawRow(_ context: GraphicsContext) {
        head(context, x: 3.8, y: 6.2)
        limbs(context, [[p(6, 7.4), p(14.6, 9.4), p(13.6, 18.2)],
                        [p(14.6, 9.4), p(17, 18.2)],
                        [p(8.2, 8), p(11.6, 5.6), p(11.2, 11.2)]])
        context.fill(Path(roundedRect: CGRect(x: 9.1, y: 11.2, width: 4.2, height: 1.9), cornerRadius: 0.6), with: .foreground)
    }

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
