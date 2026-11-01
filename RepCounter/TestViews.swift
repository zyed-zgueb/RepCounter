import SwiftUI
import TipKit

// MARK: - Test annoncé : les écrans du compteur (Science/METHODE-TEST.md, maquette étapes 11 à 14)

/// La lecture d'un test face au précédent : l'écart en nombre, « dans la variation » sous ~10 %
/// (provisoire, Hopkins pour le principe), sinon ▲ ou ▼ en couleur de texte (skill § 5).
enum TestReading {
    static func gap(_ value: Int, previous: Int?) -> String? {
        guard let previous, previous > 0 else { return nil }
        let delta = value - previous
        if abs(Double(delta)) / Double(previous) < TrainingPlan.testVariation {
            return "\(Format.signed(delta)) · dans la variation"
        }
        return Format.trend(Double(delta))
    }

    /// Pour VoiceOver : « 35, plus 2 par rapport au dernier test, dans la variation ».
    static func spoken(_ value: Int, previous: Int?) -> String {
        guard let previous, previous > 0 else { return "Résultat du test : \(value)." }
        let delta = value - previous
        let within = abs(Double(delta)) / Double(previous) < TrainingPlan.testVariation
        let sign = delta == 0 ? "égal au dernier test" : "\(delta > 0 ? "plus" : "moins") \(abs(delta)) par rapport au dernier test"
        return "Résultat du test : \(value), \(sign)" + (within ? ", dans la variation." : ".")
    }
}

/// L'échauffement proposé avant le test : le cadran reste neutre (l'exercice), la consigne est
/// dessous ; il ne compte, en couleur calme, que pendant la série d'échauffement.
struct WarmupOfferFace: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise

    var body: some View {
        Dial(face: CounterDialFace(lit: 0, color: theme.primary)) { side in
            VStack(spacing: side * 0.04) {
                ExerciseIcon(exercise: exercise, size: side * 0.24)
                    .foregroundStyle(theme.primary)
                Text(exercise.shortTitle.uppercased())
                    .font(theme.font(15, .bold))
                    .tracking(2)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(width: side * 0.5)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// Le résultat du test, dans le cadran de récupération : le nombre en grand, le dernier test,
/// l'écart, le nouveau niveau ; puis la 2e tentative (après 3:00) et « Terminer le test ».
struct TestResultPanel: View {
    @Environment(\.theme) private var theme
    @ObservedObject var model: WorkoutModel
    let exercise: Exercise
    /// Le dernier test (nil : premier test).
    let previous: Int?
    /// Le test clôt le bloc (jour de test, semaine allégée) ; sinon, en progression, il ne relève
    /// le max que s'il le dépasse.
    let closesBlock: Bool
    let currentMax: Int?
    let goal: Goal?
    /// Bloc 1 : « test 1 / 2 » ou « test 2 / 2 » (calibrage).
    var step: TrainingPlan.TestStep? = nil

    var body: some View {
        let best = model.testBest ?? 0
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(best)")
                    .font(theme.font(34, .bold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                Text("\(exercise.shortTitle.lowercased()) d'affilée")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(theme.dim)
                    .lineLimit(2)
            }
            .accessibilityElement(children: .combine)
            VStack(spacing: 6) {
                if let step {
                    // Bloc 1 : 2 tests, le meilleur fixe le départ
                    if step.number < step.of {
                        row("Test \(step.number) sur \(step.of)", "le meilleur des deux fixe ton départ")
                    } else {
                        row("Départ", "\(max(best, previous ?? 0)) (meilleur des deux) → cibles calculées")
                    }
                } else if let previous {
                    row("Dernier test", "\(previous)")
                }
                if step == nil, let gap = TestReading.gap(best, previous: previous) {
                    row("Écart", gap)
                }
                if step != nil {
                    EmptyView()
                } else if closesBlock {
                    row("Nouveau niveau", "\(best) → cibles recalées")
                } else if let currentMax, best > currentMax {
                    row("Max relevé", "\(best) → cibles mises à jour")
                } else if let currentMax {
                    row("Max", "reste \(currentMax)")
                }
                if let goal, best >= goal.target {
                    HStack {
                        MonitorLabel("Objectif")
                        Spacer()
                        Text(symbols: "✓ atteint")
                            .font(theme.font(13, .bold))
                            .foregroundStyle(theme.ok)
                            .accessibilityLabel("Objectif atteint")
                    }
                }
            }
            .padding(10)
            .cardBackground(theme)
            if model.testAttempts < WorkoutModel.maxTestAttempts {
                secondAttempt
            }
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var secondAttempt: some View {
        let remaining = max(0, WorkoutModel.secondAttemptRest - model.testRestElapsed)
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonitorLabel("2e tentative")
                Spacer()
                if remaining > 0 {
                    Text(symbols: "◷ dans \(Format.clock(remaining))")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                        .accessibilityLabel("Deuxième tentative possible dans \(Format.clock(remaining))")
                }
            }
            Text("Le meilleur des deux compte.")
                .font(theme.font(13))
                .foregroundStyle(theme.dim)
            if remaining == 0 {
                Button { model.startSecondAttempt() } label: { Text(symbols: "◆ Lancer la 2e tentative") }
                    .buttonStyle(MonitorButtonStyle(color: theme.max, filled: false, height: 44, fontSize: 12))
            }
        }
        .padding(10)
        .cardBackground(theme)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(theme.font(13, .semibold))
                .foregroundStyle(theme.dim)
                .lineLimit(2)
            Spacer(minLength: 8)
            Text(symbols: value)
                .font(theme.font(13, .bold))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        // « → » se lit en mots
        .accessibilityLabel(label + " : " + value.replacingOccurrences(of: "→", with: "puis"))
    }
}
