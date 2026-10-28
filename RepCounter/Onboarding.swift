import SwiftUI

/// Premier lancement : une seule page, la promesse et le cadran qui compte. Pas de compte, pas
/// de questionnaire : les réglages par défaut conviennent, on les découvre plus tard.
struct WelcomeView: View {
    static let key = "onboarding.welcomed"

    @Environment(\.theme) private var theme
    let onStart: () -> Void
    @State private var count = 0

    private static let target = 12

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            Dial(face: DialFace(lit: count * DialFace.tickCount / Self.target, palette: .gradient)) { side in
                VStack(spacing: 6) {
                    Text("\(count)")
                        .font(theme.font(side * 0.42, .bold))
                        .foregroundStyle(LinearGradient(colors: [theme.secondary, theme.primary],
                                                        startPoint: .leading, endPoint: .trailing))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    MonitorLabel("Pompes · série 02")
                }
            }
            .frame(width: 250, height: 250)
            .accessibilityHidden(true)

            Spacer(minLength: 24)
            (Text("Pose ton iPhone.\nEntraîne-toi.\n") + Text("Il compte.").foregroundStyle(theme.primary))
                .font(theme.font(30, .bold))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Text("Rien n'est filmé. Tout reste sur ton iPhone.")
                .font(theme.font(13))
                .foregroundStyle(theme.dim)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 310)
                .padding(.top, 18)
            Spacer(minLength: 24)

            Button("Commencer", action: onStart)
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 60))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(theme.background.ignoresSafeArea())
        .task {
            // Le cadran compte, comme pendant une série
            for value in 1...Self.target {
                try? await Task.sleep(nanoseconds: 420_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { count = value }
            }
        }
    }
}

/// La première séance commentée : trois cartes, une à la fois, au moment où elles servent.
/// Chacune est vue une fois pour toutes (même si la séance s'arrête avant la suivante).
enum Coach {
    static let key = "onboarding.coachStep"

    /// Étapes : 1 la détection, 2 la récupération, 3 la fin de séance.
    static let steps = 3

    static func text(_ step: Int) -> String {
        switch step {
        case 1: return "À ton rythme. Je valide la série à la 3e répétition."
        case 2: return "Repos chronométré. Reprends quand tu veux."
        default: return "Pour finir, maintiens Terminer."
        }
    }
}

/// Une carte de la première séance.
struct CoachCard: View {
    @Environment(\.theme) private var theme
    let step: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                MonitorLabel("Première séance", color: theme.primary)
                Spacer()
                MonitorLabel("\(step) / \(Coach.steps)")
            }
            Text(Coach.text(step))
                .font(theme.font(13))
                .foregroundStyle(theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.primary.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
