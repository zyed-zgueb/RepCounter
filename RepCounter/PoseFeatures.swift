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
    /// Haut du corps seul : la tête, les épaules, les bras.
    static let upperJoints: [Joint] = [
        .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist,
    ]

    /// Haut du corps : les coudes, et l'élévation du bras (coude, épaule, autre épaule) au lieu
    /// de l'angle qui passe par la hanche.
    static let upperAngles: [(Joint, Joint, Joint)] = [
        (.leftShoulder, .leftElbow, .leftWrist), (.rightShoulder, .rightElbow, .rightWrist),
        (.leftElbow, .leftShoulder, .rightShoulder), (.rightElbow, .rightShoulder, .leftShoulder),
    ]

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
    /// Haut du corps seul (développé) : le cou sert d'origine et la largeur des épaules d'unité,
    /// les hanches et les jambes ne sont pas nécessaires.
    let upperBody: Bool

    init(upperBody: Bool = false) {
        self.upperBody = upperBody
    }
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
        if upperBody { return upperFeatures(points) }

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

    /// Haut du corps : positions par rapport au cou, en largeurs d'épaules (lissées), et angles
    /// des bras. Il faut le cou (ou les deux épaules) et les deux épaules.
    private func upperFeatures(_ input: [Joint: CGPoint]) -> [Float]? {
        var points = input
        guard let left = points[.leftShoulder], let right = points[.rightShoulder] else { return nil }
        if points[.neck] == nil { points[.neck] = CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2) }
        guard let neck = points[.neck] else { return nil }
        let width = hypot(left.x - right.x, left.y - right.y)
        guard width > 0.02 else { return nil }
        torsoScale = torsoScale == 0 ? width : torsoScale + 0.05 * (width - torsoScale)

        for (joint, p) in points { lastKnown[joint] = p }
        func resolve(_ joint: Joint) -> CGPoint { lastKnown[joint] ?? neck }

        var f = [Float]()
        f.reserveCapacity(Skeleton.upperJoints.count * 2 + Skeleton.upperAngles.count)
        for joint in Skeleton.upperJoints {
            let p = resolve(joint)
            f.append(Float((p.x - neck.x) / torsoScale))
            f.append(Float((p.y - neck.y) / torsoScale))
        }
        for (a, b, c) in Skeleton.upperAngles {
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
