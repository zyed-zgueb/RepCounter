import SwiftUI

/// Où mettre l'iPhone pour un exercice : trois repères de quelques mots (l'illustration dit
/// le reste). Montrés la première fois qu'on démarre l'exercice, et à tout moment par
/// « Plus de détails » au bout de la consigne.
struct PlacementGuide {
    struct Point {
        let title: String
        init(_ title: String) { self.title = title }
    }

    let exercise: Exercise
    /// Pour les exercices de bras : avec brassard (sinon, à la caméra).
    let armband: Bool

    var points: [Point] {
        let nothingToTouch = Point("Rien à toucher")
        if exercise.isArmExercise {
            if armband {
                let arm = exercise == .press ? "qui pousse" : (exercise == .row ? "qui tire" : "qui travaille")
                return [Point("Dans le brassard"), Point("Sur l'avant-bras \(arm)"), Point("Bien serré")]
            }
            if exercise == .row {
                return [Point("Debout, à hauteur de taille"), Point("À deux grands pas, de profil"),
                        Point("Bras qui tire côté iPhone")]
            }
            return [Point("Debout, à hauteur de taille"), Point("À deux grands pas"), Point("Face à toi")]
        }
        switch exercise {
        case .pushups: return [Point("À plat au sol"), Point("Sous ton visage"), Point("Entre tes mains")]
        case .crunches: return [Point("À plat sur ta poitrine"), Point("Tenu d'une main"), Point("Pas au sol")]
        // Avec une barre, les mains sont prises : l'iPhone va dans la poche (ou un brassard)
        case .squats: return [Point("Dans ta poche"), Point("Ou en brassard"), nothingToTouch]
        case .lunges: return [Point("En main"), Point("Ou contre ta poitrine"), nothingToTouch]
        case .pullups, .dips: return [Point("Dans ta poche"), Point("Pantalon ajusté"), Point("5 s pour t'installer")]
        default: return [Point("Face à toi, ou sur toi"), Point("Un geste répété"), nothingToTouch]
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
                                Text(point.title)
                                    .font(theme.font(15, .bold))
                                    .foregroundStyle(theme.text)
                                    .padding(.top, 2)
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
        .sheetNavigation("\(guide.exercise.shortTitle) · placer ton iPhone", display: .inline)
    }
}
