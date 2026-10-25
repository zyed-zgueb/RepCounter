import Vision
import CoreGraphics

typealias Joint = VNHumanBodyPoseObservation.JointName

enum Skeleton {
    /// Articulations utilisées pour le vecteur de pose.
    static let joints: [Joint] = [
        .nose, .neck,
        .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist,
        .root, .leftHip, .rightHip, .leftKnee, .rightKnee, .leftAnkle, .rightAnkle,
    ]

    /// Angles articulaires (sommet au milieu) : coudes, épaules, hanches, genoux.
    static let angles: [(Joint, Joint, Joint)] = [
        (.leftShoulder, .leftElbow, .leftWrist), (.rightShoulder, .rightElbow, .rightWrist),
        (.leftElbow, .leftShoulder, .leftHip), (.rightElbow, .rightShoulder, .rightHip),
        (.leftShoulder, .leftHip, .leftKnee), (.rightShoulder, .rightHip, .rightKnee),
        (.leftHip, .leftKnee, .leftAnkle), (.rightHip, .rightKnee, .rightAnkle),
    ]
}

/// Transforme un squelette 2D en vecteur de pose invariant à la distance caméra.
/// Utilisé uniquement depuis la file vidéo.
final class PoseFeatureExtractor {
    /// Poids des angles (radians) par rapport aux positions (longueurs de torse).
    private let angleWeight: Float = 0.3
    private var lastKnown: [Joint: CGPoint] = [:]
    private var torsoScale: CGFloat = 0

    func reset() {
        lastKnown = [:]
        torsoScale = 0
    }

    /// - Parameters:
    ///   - raw: points Vision normalisés (0…1), déjà filtrés par confiance.
    ///   - aspect: largeur / hauteur de l'image, pour des coordonnées isotropes.
    func features(from raw: [Joint: CGPoint], aspect: CGFloat) -> [Float]? {
        var points = [Joint: CGPoint]()
        for (joint, p) in raw { points[joint] = CGPoint(x: p.x * aspect, y: p.y) }

        if points[.root] == nil, let l = points[.leftHip], let r = points[.rightHip] {
            points[.root] = CGPoint(x: (l.x + r.x) / 2, y: (l.y + r.y) / 2)
        }
        guard let neck = points[.neck], let root = points[.root] else { return nil }

        let torso = hypot(neck.x - root.x, neck.y - root.y)
        guard torso > 0.02 else { return nil }
        // Échelle lissée : la longueur du torse sert d'unité de mesure
        torsoScale = torsoScale == 0 ? torso : torsoScale + 0.05 * (torso - torsoScale)

        // Une articulation manquante garde sa dernière position connue, pour éviter les sauts
        for (joint, p) in points { lastKnown[joint] = p }
        func resolve(_ joint: Joint) -> CGPoint { lastKnown[joint] ?? root }

        var f = [Float]()
        f.reserveCapacity(Skeleton.joints.count * 2 + Skeleton.angles.count)
        for joint in Skeleton.joints {
            let p = resolve(joint)
            f.append(Float(p.x / torsoScale))
            f.append(Float(p.y / torsoScale))
        }
        for (a, b, c) in Skeleton.angles {
            f.append(angleWeight * angle(resolve(a), resolve(b), resolve(c)))
        }
        return f
    }

    private func angle(_ a: CGPoint, _ vertex: CGPoint, _ c: CGPoint) -> Float {
        let v1 = CGVector(dx: a.x - vertex.x, dy: a.y - vertex.y)
        let v2 = CGVector(dx: c.x - vertex.x, dy: c.y - vertex.y)
        let cross = v1.dx * v2.dy - v1.dy * v2.dx
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        return Float(atan2(abs(cross), dot))
    }
}
