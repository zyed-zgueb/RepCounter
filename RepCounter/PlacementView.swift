import SwiftUI
import Vision

/// La mise en place, entre « Démarrer » et le compte à rebours : le cadran se remplit à mesure
/// que les vérifications sont bonnes ; dedans, le pictogramme de l'exercice ou, pour la caméra,
/// ce qu'elle voit (le squelette, jamais l'image) dans le cadre de l'image. Dessous, une seule
/// consigne à la fois, sa raison, et les vérifications cochées en direct.
struct PlacementView: View {
    @Environment(\.theme) private var theme
    let placement: PlacementStatus
    let exercise: Exercise
    let showsCamera: Bool

    var body: some View {
        let complete = placement.isComplete
        let color = complete ? theme.ok : theme.warn
        let share = placement.checks.isEmpty ? 0 : Double(placement.doneCount) / Double(placement.checks.count)
        VStack(spacing: 14) {
            Dial(face: DialFace(lit: complete ? DialFace.tickCount : Int(share * Double(DialFace.tickCount) * 0.9),
                                palette: complete ? .solid(theme.ok) : .pale)) { side in
                if showsCamera {
                    CameraFraming(skeleton: placement.skeleton, color: complete ? theme.ok : theme.primary,
                                  frameColor: color.opacity(0.9))
                        .frame(width: side * 0.62, height: side * 0.62)
                } else {
                    VStack(spacing: side * 0.04) {
                        ExerciseIcon(exercise: exercise, size: side * 0.26)
                            .foregroundStyle(complete ? theme.ok : theme.primary)
                        MonitorLabel(complete ? "En place" : "Mise en place", color: complete ? theme.ok : theme.text)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: complete)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    if complete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(placement.instruction.isEmpty ? "Mise en place" : placement.instruction)
                        .font(theme.font(19, .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .foregroundStyle(color)
                .contentTransition(.opacity)
                Text(placement.hint)
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 300, minHeight: 34, alignment: .top)
            }
            .animation(.easeInOut(duration: 0.2), value: placement.instruction)
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(placement.checks, id: \.title) { check in
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(check.done ? theme.ok : theme.line, lineWidth: 1.5)
                            if check.done {
                                Circle().fill(theme.ok)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .heavy))
                                    .foregroundStyle(theme.background)
                            }
                        }
                        .frame(width: 16, height: 16)
                        Text(check.title)
                            .font(theme.font(12))
                            .foregroundStyle(check.done ? theme.text : theme.dim)
                    }
                    .animation(.easeInOut(duration: 0.2), value: check.done)
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(check.done ? "fait" : "à faire")
                }
            }
        }
    }
}

/// Ce que voit la caméra : le cadre de l'image (en coins) et le squelette dedans. Trop près, le
/// squelette déborde ; trop loin, il est petit ; décentré, il est sur un bord.
struct CameraFraming: View {
    let skeleton: [CGPoint?]
    let color: Color
    let frameColor: Color

    /// Os du squelette (indices dans `Skeleton.joints`).
    private static let bones: [(Joint, Joint)] = [
        (.neck, .leftShoulder), (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.neck, .root), (.root, .leftHip), (.root, .rightHip),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
    ]

    var body: some View {
        Canvas { context, size in
            // L'image de la caméra est en portrait (3 × 4), centrée
            let height = size.height, width = height * 0.75
            let frame = CGRect(x: (size.width - width) / 2, y: 0, width: width, height: height)
            let corner = width * 0.16
            var brackets = Path()
            for (x, y, dx, dy) in [(frame.minX, frame.minY, 1.0, 1.0), (frame.maxX, frame.minY, -1.0, 1.0),
                                   (frame.maxX, frame.maxY, -1.0, -1.0), (frame.minX, frame.maxY, 1.0, -1.0)] {
                brackets.move(to: CGPoint(x: x, y: y + dy * corner))
                brackets.addLine(to: CGPoint(x: x, y: y))
                brackets.addLine(to: CGPoint(x: x + dx * corner, y: y))
            }
            context.stroke(brackets, with: .color(frameColor), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            let point = { (joint: Joint) -> CGPoint? in
                guard let i = Skeleton.joints.firstIndex(of: joint), skeleton.indices.contains(i), let p = skeleton[i] else { return nil }
                return CGPoint(x: frame.minX + p.x * frame.width, y: frame.minY + p.y * frame.height)
            }
            let scale = frame.height / 100
            var bones = Path()
            for (a, b) in Self.bones {
                guard let pa = point(a) ?? (a == .root ? hipMidpoint(point) : nil),
                      let pb = point(b) ?? (b == .root ? hipMidpoint(point) : nil) else { continue }
                bones.move(to: pa)
                bones.addLine(to: pb)
            }
            context.stroke(bones, with: .color(color), style: StrokeStyle(lineWidth: 5 * scale, lineCap: .round, lineJoin: .round))
            if let nose = point(.nose) ?? point(.neck).map({ CGPoint(x: $0.x, y: $0.y - 9 * scale) }) {
                let r = 7 * scale
                context.fill(Path(ellipseIn: CGRect(x: nose.x - r, y: nose.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
            }
        }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func hipMidpoint(_ point: (Joint) -> CGPoint?) -> CGPoint? {
        guard let left = point(.leftHip), let right = point(.rightHip) else { return point(.leftHip) ?? point(.rightHip) }
        return CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
    }
}
