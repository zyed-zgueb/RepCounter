import SwiftUI

extension TrainingPhase {
    /// L'étiquette de la phase.
    var title: String {
        switch kind {
        case .pending: return "En cours"
        case .unreliable: return "Analyse suspendue"
        case .building: return "Construction"
        case .overreaching: return "Surcharge"
        case .lowForm: return "Forme basse"
        case .comeback: return "Reprise"
        case .deloadAdvised: return "Décharge conseillée"
        case .deload: return "Décharge"
        case .rest: return "Pause"
        case .rebound: return "Rebond"
        case .persistentFatigue: return "Fatigue persistante"
        }
    }

    /// L'action proposée, en quelques mots.
    func action(now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = since.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: calendar.startOfDay(for: now)).day ?? 0 } ?? 0
        switch kind {
        case .pending: return "\(progress) / \(Self.minSessions) séances mesurables"
        case .unreliable: return "Comptage juste à \(progress) % · corrige tes séries"
        case .building: return felt ? "Fatigue ressentie · surveille" : "Continue"
        case .overreaching: return "N'augmente plus"
        case .lowForm: return "Séance légère"
        case .comeback: return "Monte progressivement"
        case .deloadAdvised: return "Une semaine allégée"
        case .deload: return "Jour \(min(days + 1, Self.deloadDays)) / \(Self.deloadDays) · moins de volume"
        case .rest: return "\(days) jours sans séance"
        case .rebound: return "Prêt pour un record"
        case .persistentFatigue: return "Repos · avis médical si ça dure"
        }
    }

    func color(_ theme: AppTheme) -> Color {
        switch kind {
        case .overreaching, .lowForm, .deloadAdvised, .persistentFatigue: return theme.warn
        case .rebound: return theme.ok
        case .pending, .unreliable, .rest: return theme.dim
        case .building, .comeback, .deload: return theme.primary
        }
    }
}

/// Le détail de la phase : la phase, la décharge à commencer, la charge des 12 dernières
/// semaines. (i) explique le modèle et ses références.
struct PhasePanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let all: [SessionRecord]
    @State private var deloads = Deloads.starts
    @State private var showsInfo = false

    var body: some View {
        let phase = stats.phase(all: all, deloads: deloads)
        let loads = stats.weeklyLoads(all: all)
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MonitorLabel("Phase")
                    Spacer()
                    Button { showsInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(theme.dim)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("À propos des phases")
                }
                .padding(.vertical, -6)
                Text(phase.title.uppercased())
                    .font(theme.font(22, .bold))
                    .foregroundStyle(phase.kind == .pending || phase.kind == .unreliable ? theme.dim : phase.color(theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(phase.action())
                    .font(theme.font(13))
                    .foregroundStyle(theme.text)
                if phase.kind == .deloadAdvised {
                    Button("Commencer la décharge") {
                        Deloads.start()
                        withAnimation { deloads = Deloads.starts }
                    }
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 48, fontSize: 13))
                    .padding(.top, 4)
                } else if phase.kind == .deload, let started = deloads.last(where: { $0 <= stats.now }),
                          let since = phase.since, Calendar.current.isDate(started, inSameDayAs: since) {
                    Button("Annuler la décharge") {
                        Deloads.cancel(started)
                        withAnimation { deloads = Deloads.starts }
                    }
                    .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 40, fontSize: 11))
                    .padding(.top, 4)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))

            VStack(alignment: .leading, spacing: 12) {
                MonitorLabel("Charge · 12 semaines")
                LoadBars(loads: loads.map(\.load), deloadWeeks: deloadWeeks(loads.map(\.week)))
                    .frame(height: 80)
                HStack {
                    Text("effort × minutes, toutes séances")
                    Spacer()
                    if loads.contains(where: { $0.load > 0 && !$0.answered }) { Text("sans effort noté : ton habituel") }
                }
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
        }
        .sheet(isPresented: $showsInfo) {
            PhaseInfoView()
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }

    /// Semaines qui contiennent un jour de décharge déclarée.
    private func deloadWeeks(_ weeks: [Date]) -> Set<Int> {
        Set(weeks.indices.filter { index in
            deloads.contains { start in
                let end = start.addingTimeInterval(Double(TrainingPhase.deloadDays) * 86_400)
                let weekEnd = weeks[index].addingTimeInterval(7 * 86_400)
                return start < weekEnd && end > weeks[index]
            }
        })
    }
}

/// Histogramme de la charge hebdomadaire ; les semaines de décharge sont marquées.
private struct LoadBars: View {
    @Environment(\.theme) private var theme
    let loads: [Double]
    let deloadWeeks: Set<Int>

    var body: some View {
        Canvas { context, size in
            let top = max(loads.max() ?? 0, 1)
            let slot = size.width / CGFloat(max(loads.count, 1))
            for (index, load) in loads.enumerated() {
                let x = CGFloat(index) * slot
                if deloadWeeks.contains(index) {
                    context.fill(Path(CGRect(x: x, y: 0, width: slot, height: size.height)), with: .color(theme.primary.opacity(0.08)))
                }
                let height = max(size.height * CGFloat(load / top), load > 0 ? 2 : 0)
                let bar = CGRect(x: x + slot * 0.2, y: size.height - height, width: slot * 0.6, height: height)
                let isLast = index == loads.count - 1
                context.fill(Path(roundedRect: bar, cornerRadius: 2), with: .color(isLast ? theme.primary : theme.primary.opacity(0.45)))
            }
        }
        .accessibilityLabel("Charge des 12 dernières semaines")
    }
}

/// (i) : le modèle des phases, ses références et ses limites.
struct PhaseInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PHASES")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Le principe",
                            "On progresse en alternant charge et récupération. Une charge plus forte fait d'abord baisser la performance ; après récupération, elle remonte au-dessus d'avant : c'est le rebond. Si la baisse dure des semaines, la fatigue n'est plus fonctionnelle. Reps confronte ta charge d'entraînement à ta performance mesurée (la Forme), au lieu de supposer l'une à partir de l'autre.")

                    VStack(alignment: .leading, spacing: 10) {
                        MonitorLabel("Les phases")
                        ForEach(Self.phases, id: \.0) { title, rule in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(theme.font(13, .bold))
                                    .foregroundStyle(theme.text)
                                Text(rule)
                                    .font(theme.font(12))
                                    .foregroundStyle(theme.dim)
                                    .lineSpacing(3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    section("La charge",
                            "Charge d'une séance = effort noté en fin de séance (0 à 10) × durée en minutes (méthode de Foster). Sans réponse, ton effort habituel. Toutes les séances comptent : la fatigue ne dépend pas d'un seul exercice.")

                    section("Les limites",
                            "Pas de phase quand le comptage de l'exercice est juste à moins de 90 % (séries corrigées en fin de séance) : mieux vaut ne rien afficher qu'afficher faux. Une baisse se constate sur deux séances de suite : une seule peut être du bruit de mesure. Les 2 semaines viennent du consensus de Meeusen : une surcharge fonctionnelle se récupère en 2 semaines au plus, au-delà il faut des semaines ou des mois. La semaine de décharge vient de Rogerson (6,4 ± 1,7 jours). Les 8 séances sur 4 semaines avant d'afficher une phase sont un choix de l'app. La Forme dépend du comptage de l'app. Reps ne pose aucun diagnostic : une fatigue qui dure malgré le repos relève d'un avis médical.")

                    VStack(alignment: .leading, spacing: 8) {
                        MonitorLabel("Références")
                        ForEach(Self.references, id: \.self) { reference in
                            Text(reference)
                                .font(theme.font(11))
                                .foregroundStyle(theme.dim)
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private static let phases: [(String, String)] = [
        ("Construction", "Forme dans ta variation habituelle."),
        ("Surcharge", "Deux séances de suite sous ta forme habituelle, après une semaine plus chargée que les 4 d'avant."),
        ("Forme basse", "La même baisse, sans hausse de charge : sommeil, stress, maladie…"),
        ("Reprise", "Une baisse juste après une pause : le niveau revient en s'entraînant."),
        ("Décharge conseillée", "La baisse dure depuis 2 semaines."),
        ("Décharge", "Une semaine à volume réduit, commencée d'une touche."),
        ("Pause", "Plus de 7 jours sans séance."),
        ("Rebond", "Après une surcharge ou une décharge, la forme revient au moins à ton niveau, ou un record tombe."),
        ("Fatigue persistante", "La baisse continue après une décharge ou une pause."),
    ]

    private static let references = [
        "Meeusen et al. (2013). Prevention, diagnosis and treatment of the overtraining syndrome. Consensus ECSS / ACSM. Med Sci Sports Exerc 45(1):186–205.",
        "Bell et al. (2023). Deloading practices in strength and physique sports: a Delphi consensus. Sports Med Open 9:87.",
        "Rogerson et al. (2024). Deloading practices in strength and physique sports: a cross-sectional survey. Sports Med Open 10.",
        "Foster et al. (2001). A new approach to monitoring exercise training. J Strength Cond Res 15(1):109–115.",
        "Hopkins (2000). Measures of reliability in sports medicine and science. Sports Med 30(1):1–15.",
        "Saw, Main & Gastin (2016). Monitoring the athlete training response: subjective self-reported measures trump commonly used objective measures. Br J Sports Med 50(5):281–291.",
    ]

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonitorLabel(title)
            Text(text)
                .font(theme.font(13))
                .foregroundStyle(theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
