import SwiftUI

/// Où mettre l'iPhone pour un exercice : trois repères faciles à suivre (une illustration les
/// accompagne). Montrés la première fois qu'on démarre l'exercice, et à tout moment par
/// « Plus de détails » au bout de la consigne.
struct PlacementGuide {
    struct Point {
        let title: String
        let detail: String
    }

    let exercise: Exercise
    /// Pour les exercices de bras : avec brassard (sinon, à la caméra).
    let armband: Bool

    var points: [Point] {
        let nothingToTouch = Point(title: "Rien à toucher", detail: "La série démarre dès que tu bouges, la récupération dès que tu t'arrêtes.")
        if exercise.isArmExercise {
            if armband {
                let arm = exercise == .press ? "qui pousse" : (exercise == .row ? "qui tire" : "qui travaille")
                return [Point(title: "Dans le brassard", detail: "Sur l'avant-bras \(arm), près du poignet."),
                        Point(title: "Bien serré", detail: "Il doit suivre ton avant-bras sans tourner."),
                        nothingToTouch]
            }
            let stand = Point(title: "Debout, à hauteur de ta taille", detail: "Sur une chaise ou une table, calé contre un objet.")
            if exercise == .row {
                return [stand,
                        Point(title: "Sur le côté, à deux grands pas", detail: "Toi de profil : je vois ton bras tirer."),
                        Point(title: "Le bras qui tire côté iPhone", detail: "Pour que ton corps ne le cache pas.")]
            }
            return [stand,
                    Point(title: "Deux grands pas devant toi", detail: "Je dois voir tes mains, tes épaules et tes hanches."),
                    Point(title: "Face à toi", detail: "L'écran tourné vers toi : tu vois le compte de loin.")]
        }
        switch exercise {
        case .pushups:
            return [Point(title: "À plat au sol", detail: "Écran vers le haut, la caméra vers toi."),
                    Point(title: "Sous ton visage", detail: "Entre tes mains, à hauteur de tes épaules."),
                    Point(title: "Rien à toucher", detail: "Je compte quand ta poitrine descend vers lui.")]
        case .crunches:
            return [Point(title: "À plat sur ta poitrine", detail: "Écran vers le haut, sur le haut du buste."),
                    Point(title: "Tenu d'une main", detail: "Il suit ton buste sans glisser."),
                    Point(title: "Pas au sol", detail: "Je compte avec le mouvement de ton buste.")]
        case .squats:
            // Avec une barre, les mains sont prises : l'iPhone va dans la poche (ou un brassard)
            return [Point(title: "Dans ta poche", detail: "Poche avant d'un pantalon ajusté : il ne doit pas ballotter."),
                    Point(title: "Ou dans un brassard", detail: "Sur le haut du bras : tes mains restent libres pour la barre."),
                    Point(title: "Le temps de t'installer", detail: "Démarre, range-le, place la barre : le comptage démarre à tes premières répétitions.")]
        case .lunges:
            return [Point(title: "Tenu en main", detail: "Ou contre ta poitrine, buste droit."),
                    Point(title: "Il descend et remonte avec toi", detail: "Garde-le contre toi toute la série."),
                    nothingToTouch]
        case .pullups, .dips:
            return [Point(title: "Dans ta poche", detail: "Poche avant d'un pantalon ajusté : il ne doit pas ballotter."),
                    Point(title: exercise == .pullups ? "Il monte avec toi" : "Il descend avec toi",
                          detail: "Je compte le mouvement de ton corps."),
                    Point(title: "Le temps de t'installer", detail: "Démarre, range-le, mets-toi en place : 5 s avant le départ.")]
        default:
            return [Point(title: "Posé face à toi, ou porté sur toi", detail: "Là où il voit ou sent ton geste."),
                    Point(title: "Un geste qui se répète", detail: "Je trouve son rythme, puis je compte."),
                    nothingToTouch]
        }
    }

    // MARK: Déjà vu

    private static let seenKey = "placementGuide.seen"

    /// Un exercice de bras a deux fiches (caméra, brassard) : la consigne change avec le réglage.
    private var id: String {
        exercise.rawValue + (exercise.isArmExercise ? (armband ? ".armband" : ".camera") : "")
    }

    var seen: Bool {
        (UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? []).contains(id)
    }

    /// Toutes les fiches redeviennent nouvelles (Revoir l'onboarding).
    static func forgetAll() {
        UserDefaults.standard.removeObject(forKey: seenKey)
    }

    func markSeen() {
        var ids = UserDefaults.standard.stringArray(forKey: Self.seenKey) ?? []
        guard !ids.contains(id) else { return }
        ids.append(id)
        UserDefaults.standard.set(ids, forKey: Self.seenKey)
    }
}

/// La fiche « Placer ton iPhone » : l'illustration, les trois repères numérotés, et un bouton.
struct PlacementGuideView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let guide: PlacementGuide
    /// Libellé du bouton : « C'est parti » si la séance démarre ensuite, sinon « J'ai compris ».
    let buttonTitle: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MonitorLabel("\(guide.exercise.shortTitle) · placer ton iPhone", color: theme.primary)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    PlacementIllustration(exercise: guide.exercise, armband: guide.armband, accent: theme.ok)
                        .foregroundStyle(theme.text)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))

                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(guide.points.enumerated()), id: \.offset) { index, point in
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(index + 1)")
                                    .font(theme.font(12, .bold))
                                    .foregroundStyle(theme.primary)
                                    .frame(width: 24, height: 24)
                                    .overlay(Circle().stroke(theme.primary, lineWidth: 1.5))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(point.title)
                                        .font(theme.font(15, .bold))
                                        .foregroundStyle(theme.text)
                                    Text(point.detail)
                                        .font(theme.font(12))
                                        .foregroundStyle(theme.dim)
                                        .lineSpacing(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Button(buttonTitle) {
                guide.markSeen()
                dismiss()
                onDone()
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 58))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }
}
