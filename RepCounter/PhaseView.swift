import Charts
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

    /// Sur l'échelle d'intensité (skill reps-ux, § 5) ; les alertes n'ont pas de couleur propre
    /// (elles portent « ! »).
    func color(_ theme: AppTheme) -> Color {
        switch kind {
        case .overreaching, .lowForm, .deloadAdvised, .persistentFatigue: return theme.text
        case .rebound: return theme.max
        case .pending, .unreliable, .rest: return theme.dim
        case .building, .comeback: return theme.work
        case .deload: return theme.calm
        }
    }

    /// Le titre, précédé de « ! » pour une alerte.
    var marked: String { (isAlert ? "! " : "") + title }
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
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    MonitorLabel("Phase")
                    Spacer()
                    Button { showsInfo = true } label: {
                        Image(systemName: "info.circle")
                            .font(theme.font(17, .regular))
                            .foregroundStyle(theme.dim)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("À propos des phases")
                }
                .padding(.vertical, -6)
                Text(symbols: phase.marked.uppercased())
                    .font(theme.font(22, .bold))
                    .foregroundStyle(phase.kind == .pending || phase.kind == .unreliable ? theme.dim : phase.color(theme))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(phase.action())
                    .font(theme.font(17))
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
            .padding(20)
            .cardBackground(theme)

            VStack(alignment: .leading, spacing: 16) {
                MonitorLabel("Charge · 12 semaines")
                LoadBars(loads: loads.map(\.load), deloadWeeks: deloadWeeks(loads.map(\.week)))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Effort × minutes, toutes séances.")
                    if loads.contains(where: { $0.load > 0 && !$0.answered }) { Text("Sans effort noté : ton effort habituel.") }
                }
                .font(theme.font(15))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .cardBackground(theme)
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
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 80
    let loads: [Double]
    let deloadWeeks: Set<Int>
    @State private var selected: Int?

    var body: some View {
        Chart {
            ForEach(Array(loads.enumerated()), id: \.offset) { index, load in
                if deloadWeeks.contains(index) {
                    RectangleMark(xStart: .value("Semaine", Double(index) - 0.5), xEnd: .value("Semaine", Double(index) + 0.5),
                                  yStart: .value("Charge", 0.0), yEnd: .value("Charge", max(loads.max() ?? 1, 1)))
                        .foregroundStyle(theme.primary.opacity(0.08))
                }
                BarMark(x: .value("Semaine", Double(index)), y: .value("Charge", load), width: .fixed(12))
                    .foregroundStyle(index == loads.count - 1 ? theme.primary : theme.primary.opacity(0.45))
                    .cornerRadius(2)
            }
            if let selected, loads.indices.contains(selected) {
                RuleMark(x: .value("Semaine", Double(selected)))
                    .foregroundStyle(theme.dim.opacity(0.5))
                    .annotation(position: .top, spacing: 2, overflowResolution: ChartKit.overflow) {
                        SelectionLabel(title: "\(Int(loads[selected].rounded()))",
                                       detail: selected == loads.count - 1 ? "cette semaine" : "il y a \(loads.count - 1 - selected) semaines")
                    }
            }
        }
        .chartXScale(domain: -0.5...(Double(loads.count) - 0.5))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXSelection(value: Binding(get: { selected.map(Double.init) },
                                        set: { selected = $0.map { Int($0.rounded()) } }))
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Charge des 12 dernières semaines")
    }
}

/// (i) : le modèle des phases, ses références et ses limites.
struct PhaseInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Le principe",
                            "On progresse en alternant charge et récupération. Une charge plus forte fait d'abord baisser la performance ; après récupération, elle remonte au-dessus d'avant : c'est le rebond. Si la baisse dure des semaines, la fatigue n'est plus fonctionnelle. Reps confronte ta charge d'entraînement à ta performance mesurée (la Forme), au lieu de supposer l'une à partir de l'autre.")

                    VStack(alignment: .leading, spacing: 10) {
                        MonitorLabel("Les phases")
                        ForEach(Self.phases, id: \.0) { title, rule in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(theme.font(15, .bold))
                                    .foregroundStyle(theme.text)
                                Text(rule)
                                    .font(theme.font(15))
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
                                .font(theme.font(15))
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
        .sheetNavigation("Phases", display: .large)
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
            Text(title)
                .font(theme.font(17, .bold))
                .foregroundStyle(theme.text)
            Text(text)
                .font(theme.font(17))
                .foregroundStyle(theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
