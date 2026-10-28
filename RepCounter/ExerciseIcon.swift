import SwiftUI

/// Pictogramme d'un exercice, dessiné (repère 20 × 20, mêmes tracés que Design/icon/pictogrammes.html).
/// La silhouette prend la couleur de premier plan ; le matériel (barres, banc, haltères, sol) la
/// même couleur, atténuée : la silhouette ressort, le matériel explique la posture.
struct ExerciseIcon: View {
    let exercise: Exercise
    var size: CGFloat = 22

    var body: some View {
        Canvas { context, canvas in
            let scale = min(canvas.width, canvas.height) / 20
            context.scaleBy(x: scale, y: scale)
            Pictogram(context: context).draw(exercise)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Un seul squelette pour tous les pictogrammes : tronc, cou, tête, bras, avant-bras, cuisse et
/// tibia ont des longueurs fixes, et chaque exercice n'est qu'une pose (des angles). Les
/// proportions sont donc justes et identiques d'un pictogramme à l'autre.
/// Angles en degrés : 0 vers la droite, 90 vers le bas.
private struct Pictogram {
    let context: GraphicsContext

    static let torso: CGFloat = 5.2, neck: CGFloat = 2.3, headRadius: CGFloat = 1.5
    static let upperArm: CGFloat = 2.9, forearm: CGFloat = 2.7, thigh: CGFloat = 3.7, shin: CGFloat = 3.7
    static let limbWidth: CGFloat = 1.2
    static let gearOpacity = 0.4
    static var legLength: CGFloat { thigh + shin }

    // MARK: Géométrie

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Bout d'un segment de longueur `length` partant de `start`, orienté `degrees`.
    func go(_ start: CGPoint, _ length: CGFloat, _ degrees: CGFloat) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: start.x + length * cos(a), y: start.y + length * sin(a))
    }

    /// Tronc de la hanche à l'épaule, et centre de la tête dans son prolongement.
    func trunk(_ hip: CGPoint, _ degrees: CGFloat) -> (shoulder: CGPoint, head: CGPoint) {
        let shoulder = go(hip, Self.torso, degrees)
        return (shoulder, go(shoulder, Self.neck, degrees))
    }

    func leg(_ hip: CGPoint, thigh: CGFloat, shin: CGFloat) -> [CGPoint] {
        let knee = go(hip, Self.thigh, thigh)
        return [hip, knee, go(knee, Self.shin, shin)]
    }

    func arm(_ shoulder: CGPoint, upper: CGFloat, fore: CGFloat) -> [CGPoint] {
        let elbow = go(shoulder, Self.upperArm, upper)
        return [shoulder, elbow, go(elbow, Self.forearm, fore)]
    }

    // MARK: Tracés

    func limbs(_ lines: [CGPoint]...) {
        var path = Path()
        for line in lines { path.addLines(line) }
        context.stroke(path, with: .foreground,
                       style: StrokeStyle(lineWidth: Self.limbWidth, lineCap: .round, lineJoin: .round))
    }

    func head(_ center: CGPoint) {
        let r = Self.headRadius
        context.fill(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)), with: .foreground)
    }

    /// Matériel : même couleur, atténuée.
    func gear(_ draw: (GraphicsContext) -> Void) {
        var gearContext = context
        gearContext.opacity = Self.gearOpacity
        draw(gearContext)
    }

    func gearLines(_ lines: [[CGPoint]], width: CGFloat) {
        gear { context in
            var path = Path()
            for line in lines { path.addLines(line) }
            context.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    func floor() { gearLines([[p(1.5, 18.3), p(18.5, 18.3)]], width: 0.8) }

    /// Haltère vue de profil : on voit la face du disque.
    func plate(_ center: CGPoint) {
        gear { context in
            context.fill(Path(roundedRect: CGRect(x: center.x - 0.9, y: center.y - 1.3, width: 1.8, height: 2.6), cornerRadius: 0.5),
                         with: .foreground)
        }
    }

    /// Haltère vue de face : la poignée et deux disques.
    func dumbbell(_ center: CGPoint) {
        gear { context in
            var handle = Path()
            handle.move(to: p(center.x - 1.5, center.y))
            handle.addLine(to: p(center.x + 1.5, center.y))
            context.stroke(handle, with: .foreground, style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            for x in [center.x - 2.1, center.x + 1] {
                context.fill(Path(roundedRect: CGRect(x: x, y: center.y - 1, width: 1.1, height: 2), cornerRadius: 0.35),
                             with: .foreground)
            }
        }
    }

    // MARK: Poses

    func draw(_ exercise: Exercise) {
        switch exercise {
        case .pushups: pushup()
        case .crunches: crunch()
        case .squats: squat()
        case .lunges: lunge()
        case .pullups: pullup()
        case .dips: dips()
        case .curls: curl()
        case .row: row()
        case .press: press()
        case .auto: repeatedGesture()
        }
    }

    /// Planche, bras tendus, pieds et mains au sol.
    func pushup() {
        let foot = p(17.6, 18)
        let hip = go(foot, Self.legLength, 206)
        let body = trunk(hip, 206)
        floor()
        limbs([foot, hip, body.shoulder], [body.shoulder, go(body.shoulder, Self.upperArm + Self.forearm, 90)])
        head(body.head)
    }

    /// Allongé, genoux pliés, buste relevé, bras vers les genoux.
    func crunch() {
        let hip = p(8.6, 17.4)
        let body = trunk(hip, 215)
        floor()
        limbs(leg(hip, thigh: -50, shin: 60), [hip, body.shoulder], arm(body.shoulder, upper: -12, fore: -12))
        head(body.head)
    }

    /// En bas du mouvement, bras tendus devant.
    func squat() {
        let foot = p(8.6, 18)
        let knee = go(foot, Self.shin, -65)
        let hip = go(knee, Self.thigh, 188)
        let body = trunk(hip, -58)
        floor()
        limbs([foot, knee, hip, body.shoulder], arm(body.shoulder, upper: 2, fore: 2))
        head(body.head)
    }

    /// Buste droit, cuisse avant horizontale, genou arrière près du sol, bras vers l'avant.
    func lunge() {
        let hip = p(9.4, 14.3)
        let body = trunk(hip, -90)
        floor()
        limbs(leg(hip, thigh: -2, shin: 90), leg(hip, thigh: 116, shin: 180), [hip, body.shoulder],
              arm(body.shoulder, upper: 62, fore: 18))
        head(body.head)
    }

    /// De face, suspendu à la barre, coudes pliés.
    func pullup() {
        let shoulderY: CGFloat = 6.4
        let hip = p(10, shoulderY + Self.torso)
        gearLines([[p(2.5, 2.4), p(17.5, 2.4)]], width: 1.1)
        limbs([p(5.8, 2.6), p(5.1, 5.0), p(7.8, shoulderY), p(12.2, shoulderY), p(14.9, 5.0), p(14.2, 2.6)],
              [p(10, shoulderY), hip],
              [go(hip, Self.legLength, 101), hip, go(hip, Self.legLength, 79)])
        head(p(10, shoulderY - Self.neck))
    }

    /// De face, en appui bras tendus sur deux barres, pieds au-dessus du sol.
    func dips() {
        let y: CGFloat = 5
        let left = p(7.8, y), right = p(12.2, y)
        let hip = p(10, y + Self.torso)
        let handLeft = go(left, Self.upperArm + Self.forearm, 108)
        let handRight = go(right, Self.upperArm + Self.forearm, 72)
        gearLines([[p(handLeft.x - 1.8, handLeft.y), p(handLeft.x - 1.8, 18.3)],
                   [p(handRight.x + 1.8, handRight.y), p(handRight.x + 1.8, 18.3)]], width: 1)
        floor()
        gearLines([[p(handLeft.x - 2.2, handLeft.y), p(handLeft.x + 0.6, handLeft.y)],
                   [p(handRight.x - 0.6, handRight.y), p(handRight.x + 2.2, handRight.y)]], width: 1.1)
        let legs = Self.legLength - 0.6
        limbs([handLeft, left, right, handRight], [p(10, y), hip], [go(hip, legs, 100), hip, go(hip, legs, 80)])
        head(p(10, y - Self.neck))
    }

    /// De profil, debout, coude près du corps, avant-bras levé avec l'haltère.
    func curl() {
        let hip = p(9.2, 10.8)
        let body = trunk(hip, -90)
        let forearm = arm(body.shoulder, upper: 72, fore: -48)
        floor()
        limbs([go(hip, Self.legLength, 96), hip, go(hip, Self.legLength, 84)], [hip, body.shoulder], forearm)
        head(body.head)
        plate(forearm[2])
    }

    /// Un genou et une main sur le banc, dos plat, l'autre bras tire l'haltère (coude au-dessus du dos).
    func row() {
        let benchTop: CGFloat = 14.4
        let hip = p(12.2, benchTop - Self.thigh)
        let body = trunk(hip, 198)
        let pull = arm(go(body.shoulder, 0.6, 18), upper: -72, fore: 96)
        gearLines([[p(3.2, benchTop + 0.7), p(13.6, benchTop + 0.7)],
                   [p(4.2, benchTop + 0.7), p(4.2, 18.3)], [p(12.6, benchTop + 0.7), p(12.6, 18.3)]], width: 1)
        floor()
        limbs([hip, p(15.4, 14.4), p(16.6, 18)],                       // jambe d'appui au sol
              [hip, p(hip.x, benchTop), p(hip.x + 1.6, benchTop)],     // genou sur le banc
              [hip, body.shoulder],
              [body.shoulder, p(body.shoulder.x, benchTop)],           // main d'appui sur le banc
              pull)
        plate(pull[2])
        head(body.head)
    }

    /// De face, une haltère dans chaque main, coudes à hauteur d'épaules.
    func press() {
        let y: CGFloat = 5.6
        let left = p(7.8, y), right = p(12.2, y)
        let hip = p(10, y + Self.torso)
        let elbowLeft = go(left, Self.upperArm, 175), elbowRight = go(right, Self.upperArm, 5)
        let handLeft = go(elbowLeft, Self.forearm, -90), handRight = go(elbowRight, Self.forearm, -90)
        floor()
        limbs([handLeft, elbowLeft, left, right, elbowRight, handRight], [p(10, y), hip],
              [go(hip, Self.legLength, 101), hip, go(hip, Self.legLength, 79)])
        head(p(10, y - Self.neck))
        dumbbell(handLeft)
        dumbbell(handRight)
    }

    /// « Autre exercice » : un geste qui se répète (flèche circulaire autour d'un point).
    func repeatedGesture() {
        let center = p(10, 10.2), radius: CGFloat = 6.6
        let arc = stride(from: CGFloat(-40), through: -348, by: -8).map { go(center, radius, $0) }
        limbs(arc, [p(15.6, 2.6), p(15.4, 6.1), p(11.9, 5.8)])
        head(center)
    }
}

// MARK: - Placement de l'iPhone

/// Où mettre l'iPhone, en image : la pose de l'exercice (le même squelette que les
/// pictogrammes) et l'iPhone, en couleur d'accent, là où il doit être. Pour la caméra, une scène
/// plus large : l'iPhone debout sur une chaise, à deux grands pas.
struct PlacementIllustration: View {
    let exercise: Exercise
    let armband: Bool
    let accent: Color

    private var camera: Bool { exercise.isArmExercise && !armband }

    var body: some View {
        let width: CGFloat = camera ? 38 : 20, height: CGFloat = camera ? 22 : 20
        Canvas { context, size in
            let scale = min(size.width / width, size.height / height)
            context.translateBy(x: (size.width - width * scale) / 2, y: (size.height - height * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            if camera {
                // Le sportif à gauche (sol à 19,3), l'iPhone à droite
                var figure = context
                figure.translateBy(x: 0, y: 1)
                Pictogram(context: figure).draw(exercise)
                Pictogram(context: context).cameraScene(accent: accent)
            } else {
                let pictogram = Pictogram(context: context)
                pictogram.draw(exercise)
                pictogram.phone(for: exercise, accent: accent)
            }
        }
        .aspectRatio(width / height, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private extension Pictogram {
    func lerp(_ a: CGPoint, _ b: CGPoint, _ k: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * k, y: a.y + (b.y - a.y) * k)
    }

    /// L'iPhone : un rectangle arrondi plein, de longueur `length` le long de `degrees`.
    func phoneMark(_ center: CGPoint, length: CGFloat, thickness: CGFloat, degrees: CGFloat, accent: Color) {
        var phone = context
        phone.translateBy(x: center.x, y: center.y)
        phone.rotate(by: .degrees(Double(degrees)))
        let rect = CGRect(x: -length / 2, y: -thickness / 2, width: length, height: thickness)
        phone.fill(Path(roundedRect: rect, cornerRadius: min(length, thickness) * 0.3), with: .color(accent))
    }

    /// L'iPhone sur la pose de l'exercice (mêmes calculs que les poses).
    func phone(for exercise: Exercise, accent: Color) {
        switch exercise {
        case .pushups:
            // À plat au sol, sous le visage ; un pointillé du visage à l'iPhone
            let hip = go(p(17.6, 18), Self.legLength, 206)
            let head = trunk(hip, 206).head
            var guide = Path()
            guide.move(to: p(head.x, head.y + Self.headRadius + 0.5))
            guide.addLine(to: p(head.x, 17.3))
            context.stroke(guide, with: .color(accent), style: StrokeStyle(lineWidth: 0.25, lineCap: .round, dash: [0.5, 0.45]))
            phoneMark(p(head.x + 0.2, 17.9), length: 2.7, thickness: 0.5, degrees: 0, accent: accent)
        case .crunches:
            // À plat sur le haut de la poitrine
            let hip = p(8.6, 17.4)
            let chest = lerp(hip, trunk(hip, 215).shoulder, 0.62)
            phoneMark(go(chest, 1.05, 305), length: 2.6, thickness: 0.55, degrees: 35, accent: accent)
        case .squats:
            // Tenu à deux mains, bras tendus devant
            let knee = go(p(8.6, 18), Self.shin, -65)
            let hip = go(knee, Self.thigh, 188)
            let hand = arm(trunk(hip, -58).shoulder, upper: 2, fore: 2)[2]
            phoneMark(p(hand.x + 0.2, hand.y), length: 2.2, thickness: 0.65, degrees: 90, accent: accent)
        case .lunges:
            // Tenu en main
            let hand = arm(trunk(p(9.4, 14.3), -90).shoulder, upper: 62, fore: 18)[2]
            phoneMark(p(hand.x + 0.2, hand.y), length: 2.2, thickness: 0.65, degrees: 90, accent: accent)
        case .pullups:
            // Dans la poche, sur la cuisse
            let hip = p(10, 6.4 + Self.torso)
            phoneMark(go(hip, Self.legLength * 0.38, 79) + p(0.5, 0), length: 2, thickness: 0.8, degrees: 79, accent: accent)
        case .dips:
            let hip = p(10, 5 + Self.torso)
            phoneMark(go(hip, (Self.legLength - 0.6) * 0.38, 80) + p(0.5, 0), length: 2, thickness: 0.8, degrees: 80, accent: accent)
        case .curls:
            // Brassard sur l'avant-bras
            let forearm = arm(trunk(p(9.2, 10.8), -90).shoulder, upper: 72, fore: -48)
            phoneMark(lerp(forearm[1], forearm[2], 0.45), length: 1.6, thickness: 0.9, degrees: -48, accent: accent)
        case .press:
            let elbow = go(p(7.8, 5.6), Self.upperArm, 175)
            let hand = go(elbow, Self.forearm, -90)
            phoneMark(lerp(elbow, hand, 0.45), length: 1.6, thickness: 0.9, degrees: -90, accent: accent)
        case .row:
            let shoulder = trunk(p(12.2, 14.4 - Self.thigh), 198).shoulder
            let pull = arm(go(shoulder, 0.6, 18), upper: -72, fore: 96)
            phoneMark(lerp(pull[1], pull[2], 0.45), length: 1.6, thickness: 0.9, degrees: 96, accent: accent)
        case .auto:
            break
        }
    }

    /// Exercices de bras à la caméra (repère 38 × 22) : le sol prolongé, une chaise, l'iPhone
    /// debout dessus, et deux grands pas entre lui et le sportif.
    func cameraScene(accent: Color) {
        gearLines([[p(1.5, 19.3), p(36.5, 19.3)]], width: 0.8)
        gearLines([[p(30, 13.2), p(36, 13.2)], [p(30.8, 13.2), p(30.8, 19.3)], [p(35.2, 13.2), p(35.2, 19.3)]], width: 0.9)
        phoneMark(p(33.05, 11.7), length: 2.8, thickness: 1.3, degrees: 90, accent: accent)
        var arrow = Path()
        arrow.move(to: p(14, 20.9))
        arrow.addLine(to: p(28.5, 20.9))
        for (tip, back) in [(p(28.5, 20.9), CGFloat(-1)), (p(14, 20.9), CGFloat(1))] {
            arrow.move(to: p(tip.x + back * 1.1, tip.y - 0.7))
            arrow.addLine(to: tip)
            arrow.addLine(to: p(tip.x + back * 1.1, tip.y + 0.7))
        }
        context.stroke(arrow, with: .color(accent), style: StrokeStyle(lineWidth: 0.35, lineCap: .round, lineJoin: .round))
    }
}

private func + (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x + b.x, y: a.y + b.y)
}
