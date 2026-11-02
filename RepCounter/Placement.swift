import CoreGraphics
import Foundation
import Vision

/// Comment l'iPhone doit être placé, pour les exercices où un mauvais placement se détecte
/// avant la première répétition. Les autres (téléphone tenu, en poche, au bras) n'ont pas de
/// mise en place : on ne saurait pas distinguer la main de la poche.
enum PlacementKind {
    /// Pompes : à plat au sol, écran vers le haut, sous le visage ; le corps au-dessus.
    case floor
    /// Abdos : à plat sur la poitrine (la respiration le fait bouger ; au sol, il est immobile).
    case chest
    /// Biceps, développé à la caméra : debout, face à soi ; mains, épaules et hanches dans l'image.
    case cameraFront
    /// Rowing à la caméra : pareil, mais de profil.
    case cameraSide
    /// Développé à la caméra : face à soi, le haut du corps seul (tête, épaules, bras) ; les
    /// hanches et les jambes peuvent sortir de l'image.
    case cameraUpper

    var usesCamera: Bool { self == .cameraFront || self == .cameraSide || self == .cameraUpper }
}

extension Exercise {
    /// Mise en place vérifiée avant le départ (nil : départ direct, compte à rebours de 5 s).
    var placementKind: PlacementKind? {
        switch self {
        case .pushups: return .floor
        case .crunches: return .chest
        case .curls: return countsWithCamera ? .cameraFront : nil
        case .press: return countsWithCamera ? .cameraUpper : nil
        case .row: return countsWithCamera ? .cameraSide : nil
        default: return nil
        }
    }
}

/// Une vérification de la mise en place, cochée en direct.
struct PlacementCheck: Equatable {
    let title: String
    let done: Bool
}

/// Où en est la mise en place : une seule consigne à la fois (la première qui manque), la
/// liste des vérifications et, pour la caméra, le squelette qu'elle voit.
struct PlacementStatus: Equatable {
    /// Tout est bon depuis assez longtemps : le compte à rebours peut partir.
    var ready = false
    var instruction = ""
    var checks: [PlacementCheck] = []
    /// L'iPhone est manipulé (pris en main, déplacé) : pendant le compte à rebours, la mise en
    /// place est à refaire.
    var handled = false
    /// Squelette vu par la caméra (`Skeleton.joints`), en coordonnées d'image 0…1, origine en
    /// haut à gauche, comme à l'écran (image en miroir). nil : articulation non vue.
    var skeleton: [CGPoint?] = []

    var doneCount: Int { checks.filter(\.done).count }
    /// Toutes les vérifications sont bonnes (le départ attend encore un instant).
    var isComplete: Bool { !checks.isEmpty && checks.allSatisfy(\.done) }
}

/// Vérifie la mise en place à chaque mesure, à partir de l'orientation de l'iPhone (gravité),
/// de son immobilité (gyroscope) et, selon l'exercice, de la caméra : profondeur et visage
/// pour les pompes, squelette et luminosité pour les exercices de bras.
/// Utilisé uniquement sur la file des capteurs.
///
/// Les seuils sont des premières valeurs, à régler sur des enregistrements (les mesures de la
/// mise en place y sont écrites : gravité, rotation, profondeur, articulations).
final class PlacementMonitor {
    enum Tuning {
        /// Temps pendant lequel tout doit rester bon avant le départ (s).
        static let holdDuration = 0.8
        /// Lissage de la vitesse de rotation (constante de temps, s).
        static let rotationSmoothing = 0.6
        /// Posé au sol, le gyroscope ne mesure que son bruit ; sur la poitrine, la respiration.
        /// Enregistrements : 0,001 à 0,004 rad/s au sol, 0,027 à 0,033 sur la poitrine au repos.
        static let chestMinRotation: Float = 0.01
        /// Abdos : au-delà, on est encore en train de s'installer (enregistrements : 0,07 à 0,2
        /// rad/s juste après s'être allongé, 1 à 3 en s'allongeant).
        static let chestMaxRotation: Float = 0.25
        /// iPhone manipulé : au-dessus des mouvements de l'exercice lui-même (enregistrements :
        /// abdos ≈ 0,7 rad/s en moyenne lissée, prise en main 2 à 3).
        static let handlingRotation: Float = 1.2
        /// Posé sur un meuble, il ne bouge pas (≤ 0,004 rad/s mesuré) ; tenu, même immobile, il bouge.
        static let restingMaxRotation: Float = 0.02
        /// Pompes : un corps au-dessus de l'iPhone (profondeur mesurée au centre, en mètres).
        static let bodyMaxDistance: Float = 0.95
        static let bodyMinCoverage: Float = 0.2
        /// Pompes : un visage assez grand (part de la largeur de l'image) est au-dessus de l'iPhone.
        /// Enregistrements : 0,21 à 0,27 en haut de la pompe ou à genoux au-dessus, 0,4 à 1 en bas.
        /// La profondeur au centre ne suffit pas : en haut de la pompe, elle voit souvent le plafond.
        static let faceMinWidth: Float = 0.18
        /// Caméra : torse (cou → hanches) en part de la hauteur de l'image.
        static let torsoMin: CGFloat = 0.13
        static let torsoMax: CGFloat = 0.42
        /// Caméra : centre des épaules, en part de la largeur de l'image.
        static let centerMargin: CGFloat = 0.25
        /// Luminosité moyenne de l'image (0…1) en dessous de laquelle la caméra voit mal.
        static let minLuminance: Float = 0.1
        /// Rapport largeur des épaules / torse : de face au-dessus, de profil en dessous.
        static let frontShoulderRatio: CGFloat = 0.4
        static let sideShoulderRatio: CGFloat = 0.35
        /// Haut du corps : largeur des épaules en part de la hauteur de l'image (trop loin en
        /// dessous, trop près au-dessus). Premières valeurs, à régler sur les enregistrements.
        static let shouldersMin: CGFloat = 0.12
        static let shouldersMax: CGFloat = 0.4
    }

    let kind: PlacementKind
    private var rotation: Float = 0
    private var lastTime: Double?
    private var goodSince: Double?

    init(kind: PlacementKind) {
        self.kind = kind
    }

    /// Nouvelle mise en place : le temps « tout est bon » repart de zéro.
    func reset() {
        goodSince = nil
    }

    func process(_ frame: SensorFrame) -> PlacementStatus {
        let t = frame.time
        if let rate = frame.values[.rotation], rate.count == 3 {
            let magnitude = (rate[0] * rate[0] + rate[1] * rate[1] + rate[2] * rate[2]).squareRoot()
            let dt = lastTime.map { min(max(t - $0, 0), 0.2) } ?? 0
            let k = Float(dt / Tuning.rotationSmoothing)
            rotation = lastTime == nil ? magnitude : rotation + min(k, 1) * (magnitude - rotation)
        }
        lastTime = t
        let gravity = frame.values[.motion] ?? [0, 0, 0]

        var status: PlacementStatus
        switch kind {
        case .floor: status = floor(frame, gravity: gravity)
        case .chest: status = chest(gravity: gravity)
        case .cameraFront, .cameraSide, .cameraUpper: status = camera(frame, gravity: gravity)
        }

        status.handled = rotation > Tuning.handlingRotation
        // Le départ attend que tout reste bon un moment (pas sur une image chanceuse)
        if status.checks.allSatisfy(\.done) {
            if goodSince == nil { goodSince = t }
            status.ready = t - (goodSince ?? t) >= Tuning.holdDuration
            status.instruction = "Parfait, ne bouge plus"
        } else {
            goodSince = nil
        }
        return status
    }

    // MARK: Pompes

    private func floor(_ frame: SensorFrame, gravity: [Float]) -> PlacementStatus {
        // À plat, écran vers le haut : la gravité sort par le dos de l'iPhone (z ≈ −1)
        let flat = gravity[2] < -0.85
        var above = false
        if let depth = frame.extras["depthStats"], depth.count >= 4 {
            above = depth[3] >= Tuning.bodyMinCoverage && depth[1] > 0 && depth[1] <= Tuning.bodyMaxDistance
        }
        if let face = frame.values[.face], face.count == 3, face[2] >= Tuning.faceMinWidth { above = true }

        var status = PlacementStatus(checks: [PlacementCheck(title: "iPhone à plat", done: flat),
                                              PlacementCheck(title: "Toi au-dessus", done: above)])
        if !flat {
            status.instruction = gravity[2] > 0.5 ? "Retourne l'iPhone" : "Pose l'iPhone à plat"
        } else if !above {
            status.instruction = "Mets-toi en planche"
        }
        return status
    }

    // MARK: Abdos

    private func chest(gravity: [Float]) -> PlacementStatus {
        let flat = abs(gravity[2]) > 0.75
        // Sur la poitrine, la respiration le fait bouger un peu ; au sol, rien ne bouge
        let onBody = rotation >= Tuning.chestMinRotation
        // Installé : allongé et immobile (sinon, les mouvements de l'installation faussent le
        // début du comptage)
        let settled = rotation <= Tuning.chestMaxRotation
        var status = PlacementStatus(checks: [PlacementCheck(title: "iPhone à plat", done: flat),
                                              PlacementCheck(title: "Sur ta poitrine", done: onBody),
                                              PlacementCheck(title: "Allongé, immobile", done: settled)])
        if !flat {
            status.instruction = "Allonge-toi, iPhone à plat"
        } else if !onBody {
            status.instruction = "Sur ta poitrine, pas au sol"
        } else if !settled {
            status.instruction = "Allonge-toi, ne bouge plus"
        }
        return status
    }

    // MARK: Caméra

    private func camera(_ frame: SensorFrame, gravity: [Float]) -> PlacementStatus {
        // Debout, en portrait : la gravité descend le long de l'iPhone (y ≈ −1). L'image est
        // tournée pour le portrait ; à plat ou en paysage, le squelette n'est pas reconnu.
        let upright = gravity[1] < -0.6
        let still = rotation < Tuning.restingMaxRotation
        let luminance = frame.values[.pixels].map { $0.reduce(0, +) / Float(max($0.count, 1)) }
        let light = luminance.map { $0 >= Tuning.minLuminance } ?? true
        let skeleton = Self.skeleton(frame.extras["joints"])
        let body = Body(skeleton)
        let framing = kind == .cameraUpper ? upperFramingInstruction(body) : framingInstruction(body)

        var status = PlacementStatus(checks: [PlacementCheck(title: "iPhone stable", done: upright && still),
                                              PlacementCheck(title: kind == .cameraSide ? "Toi de profil, en entier"
                                                                : (kind == .cameraUpper ? "Tête, épaules et bras visibles" : "Toi en entier"),
                                                             done: framing == nil),
                                              PlacementCheck(title: "Assez de lumière", done: light)],
                                     skeleton: skeleton)
        if !upright {
            if abs(gravity[2]) > 0.75 {
                status.instruction = "Mets l'iPhone debout"
            } else if abs(gravity[0]) > 0.6 {
                status.instruction = "Tourne l'iPhone en hauteur"
            } else {
                status.instruction = "Retourne l'iPhone"
            }
        } else if !still {
            status.instruction = "Pose l'iPhone"
        } else if !light {
            status.instruction = "Plus de lumière"
        } else if let framing {
            status.instruction = framing
        }
        return status
    }

    /// Les articulations utiles à la mise en place, tirées du squelette.
    private struct Body {
        let points: [CGPoint?]
        func point(_ joint: Joint) -> CGPoint? {
            Skeleton.joints.firstIndex(of: joint).flatMap { points.indices.contains($0) ? points[$0] : nil }
        }
        init(_ points: [CGPoint?]) { self.points = points }

        var visibleCount: Int { points.compactMap { $0 }.count }
        var neck: CGPoint? {
            point(.neck) ?? zip2(point(.leftShoulder), point(.rightShoulder)).map(mid)
        }
        var hip: CGPoint? {
            point(.root) ?? zip2(point(.leftHip), point(.rightHip)).map(mid) ?? point(.leftHip) ?? point(.rightHip)
        }
        /// Un côté complet (épaule, coude, poignet).
        func arm(left: Bool) -> Bool {
            left ? point(.leftShoulder) != nil && point(.leftElbow) != nil && point(.leftWrist) != nil
                 : point(.rightShoulder) != nil && point(.rightElbow) != nil && point(.rightWrist) != nil
        }
        private func zip2(_ a: CGPoint?, _ b: CGPoint?) -> (CGPoint, CGPoint)? {
            guard let a, let b else { return nil }
            return (a, b)
        }
        private func mid(_ pair: (CGPoint, CGPoint)) -> CGPoint {
            CGPoint(x: (pair.0.x + pair.1.x) / 2, y: (pair.0.y + pair.1.y) / 2)
        }
    }

    /// Image de la caméra en portrait : 480 × 640. Les distances se mesurent en hauteurs d'image.
    private static let imageAspect: CGFloat = 0.75

    /// Ce qui ne va pas dans le cadrage, dans l'ordre où il faut le corriger (nil : rien).
    private func framingInstruction(_ body: Body) -> String? {
        let side = kind == .cameraSide
        guard body.visibleCount >= 4, let neck = body.neck else {
            return side ? "Mets-toi de profil" : "Mets-toi face à l'iPhone"
        }
        let distance = { (a: CGPoint, b: CGPoint) in hypot((a.x - b.x) * Self.imageAspect, a.y - b.y) }
        let all = body.points.compactMap { $0 }
        let touchesEdge = all.contains { $0.y < 0.02 || $0.y > 0.98 }
        guard let hip = body.hip else {
            // Les épaules sans les hanches : trop près (ou l'iPhone trop haut)
            return "Recule d'un pas"
        }
        let torso = distance(neck, hip)
        if torso > Tuning.torsoMax || touchesEdge {
            return "Recule d'un pas"
        }
        if torso < Tuning.torsoMin {
            return "Approche d'un pas"
        }
        // Image en miroir, comme un selfie : trop à gauche de l'image, il faut aller vers sa droite
        if neck.x < Tuning.centerMargin { return "Décale-toi vers ta droite" }
        if neck.x > 1 - Tuning.centerMargin { return "Décale-toi vers ta gauche" }
        if let left = body.point(.leftShoulder), let right = body.point(.rightShoulder) {
            let ratio = abs(left.x - right.x) * Self.imageAspect / torso
            if side, ratio > Tuning.sideShoulderRatio {
                return "Tourne-toi de profil"
            }
            if !side, ratio < Tuning.frontShoulderRatio {
                return "Tourne-toi face à l'iPhone"
            }
        }
        let armsVisible = side ? (body.arm(left: true) || body.arm(left: false)) : (body.arm(left: true) && body.arm(left: false))
        if !armsVisible {
            return "Recule d'un pas"
        }
        return nil
    }

    /// Haut du corps (développé) : la tête, les deux épaules, les deux bras ; les hanches et les
    /// jambes peuvent manquer ou toucher le bord (nil : cadrage bon).
    private func upperFramingInstruction(_ body: Body) -> String? {
        guard let left = body.point(.leftShoulder), let right = body.point(.rightShoulder) else {
            // Rien ou presque de vu : le plus souvent, trop loin (essai de Vincent à 2,5 m)
            return body.visibleCount < 3 ? "Approche-toi : 1 m environ" : "Mets-toi face à l'iPhone"
        }
        let upper: [Joint] = [.nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist]
        // Seul le haut du corps doit rester dans l'image (les poignets montent au-dessus de la tête)
        let touchesEdge = upper.compactMap { body.point($0) }.contains { $0.y < 0.02 || $0.x < 0.02 || $0.x > 0.98 }
        let width = abs(left.x - right.x) * Self.imageAspect
        if width > Tuning.shouldersMax || touchesEdge { return "Recule d'un pas" }
        if width < Tuning.shouldersMin { return "Approche-toi : 1 m environ" }
        let center = (left.x + right.x) / 2
        if center < Tuning.centerMargin { return "Décale-toi vers ta droite" }
        if center > 1 - Tuning.centerMargin { return "Décale-toi vers ta gauche" }
        if !(body.arm(left: true) && body.arm(left: false)) { return "Montre tes deux bras" }
        return nil
    }

    /// Les articulations transmises par les capteurs (x, y ; −1 si non vue).
    private static func skeleton(_ flat: [Float]?) -> [CGPoint?] {
        guard let flat, flat.count == Skeleton.joints.count * 2 else { return [] }
        return (0..<Skeleton.joints.count).map { i in
            let x = flat[2 * i], y = flat[2 * i + 1]
            return x < 0 || y < 0 ? nil : CGPoint(x: CGFloat(x), y: CGFloat(y))
        }
    }
}
