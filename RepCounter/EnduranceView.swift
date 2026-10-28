import SwiftUI

/// Jauge d'endurance : un arc de graduations (comme le cadran), ouvert en bas. Avec un barème
/// (pompes, profil renseigné), l'arc est découpé en cinq zones de niveau et rempli jusqu'à la
/// meilleure série ; sinon, il se remplit jusqu'au record personnel.
struct EnduranceGauge: View {
    @Environment(\.theme) private var theme
    let score: Int
    /// Remplissage (0…1).
    let fill: Double
    /// Niveau publié, s'il y en a un.
    let level: EnduranceLevel?

    private static let ticksPerZone = 9
    private static let zones = 5
    /// Arc de 270°, ouvert en bas.
    private static let startAngle = 135.0, sweep = 270.0

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Canvas { context, size in draw(in: context, size: size) }
                    .shadow(color: theme.primary.opacity(0.35 * min(theme.glow, 1)), radius: 8)
                VStack(spacing: side * 0.02) {
                    Text("\(score)")
                        .font(theme.font(side * 0.27, .bold))
                        .foregroundStyle(LinearGradient(colors: [theme.secondary, theme.primary],
                                                        startPoint: .leading, endPoint: .trailing))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if let level {
                        Text(level.title.uppercased())
                            .font(theme.font(side * 0.075, .bold))
                            .tracking(1)
                            .foregroundStyle(theme.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(side * 0.2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score d'endurance \(score)" + (level.map { ", niveau \($0.title)" } ?? ""))
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 - 4
        // Avec des niveaux : cinq groupes de graduations séparés par un vide ; sinon, un arc continu
        let zoned = level != nil
        let count = zoned ? Self.ticksPerZone * Self.zones : Self.ticksPerZone * Self.zones + Self.zones - 1
        let slots = Self.ticksPerZone * Self.zones + Self.zones - 1
        let lit = Int((fill * Double(count)).rounded())
        for i in 0..<count {
            let slot = zoned ? i + i / Self.ticksPerZone : i
            let angle = (Self.startAngle + Self.sweep * Double(slot) / Double(slots - 1)) * .pi / 180
            let major = zoned ? i % Self.ticksPerZone == Self.ticksPerZone / 2 : i % 5 == 0
            let inner = outer * (major ? 0.86 : 0.92)
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
            let color = i < lit ? theme.secondary.mixed(with: theme.primary, by: Double(i) / Double(max(count - 1, 1))) : theme.line
            context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: major ? 3.4 : 2.4, lineCap: .round))
        }
        // Repère : là où l'on se situe
        let markerSlot = zoned
            ? Double(min(lit, count - 1)) + Double(min(lit, count - 1) / Self.ticksPerZone)
            : Double(min(lit, count - 1))
        let angle = (Self.startAngle + Self.sweep * markerSlot / Double(slots - 1)) * .pi / 180
        let point = CGPoint(x: center.x + CGFloat(cos(angle)) * (outer + 1), y: center.y + CGFloat(sin(angle)) * (outer + 1))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)), with: .color(theme.text))
    }
}

/// « Score d'endurance » dans l'historique d'un exercice : la jauge, l'évolution sur 4 semaines, la
/// courbe sur 12, et le niveau selon le barème quand il y en a un. (i) explique le calcul.
struct EndurancePanel: View {
    @Environment(\.theme) private var theme
    @AppStorage(Profile.sexKey) private var sexID = ""
    @AppStorage(Profile.birthYearKey) private var birthYear = 0
    let stats: HistoryStats
    let exercise: Exercise
    @State private var showsInfo = false

    var body: some View {
        let score = stats.performanceIndex()
        let previous = stats.previousPerformanceIndex
        let curve = stats.sessionIndices()
        let first = stats.firstScored
        let assessment = EnduranceAssessment.make(exercise: exercise, bestSet: stats.bestSet(lastDays: 28))
        let record = stats.sessions.compactMap(\.performanceIndex).max()
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonitorLabel("Score d'endurance")
                Spacer()
                Button { showsInfo = true } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(theme.dim)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("À propos du score d'endurance")
            }
            .padding(.vertical, -6)

            if let score {
                HStack(alignment: .center, spacing: 16) {
                    EnduranceGauge(score: Int(score.rounded()),
                                   fill: assessment?.position ?? min(score / max(record ?? score, 1), 1),
                                   level: assessment?.level)
                        .frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 8) {
                        if let previous, previous > 0 {
                            // Assez d'historique : évolution sur 4 semaines
                            let change = (score - previous) / previous * 100
                            Text("\(change >= 0 ? "▲" : "▼") \(Format.percent(change)) %")
                                .font(theme.font(20, .bold))
                                .foregroundStyle(change >= 0 ? theme.ok : theme.dim)
                            Text("en 4 semaines")
                                .font(theme.font(11))
                                .foregroundStyle(theme.dim)
                                .padding(.top, -6)
                        } else if let first, curve.points.count >= 2 {
                            // Au début : évolution depuis la première séance notée
                            let change = Int(score.rounded()) - Int(first.value.rounded())
                            Text("\(change >= 0 ? "▲" : "▼") \(Format.signed(change))")
                                .font(theme.font(20, .bold))
                                .foregroundStyle(change >= 0 ? theme.ok : theme.dim)
                            Text("depuis le \(Format.shortDate(first.date))")
                                .font(theme.font(11))
                                .foregroundStyle(theme.dim)
                                .padding(.top, -6)
                        }
                        if curve.points.count >= 2 {
                            LineChart(points: curve.points, span: curve.span)
                                .frame(height: 40)
                        }
                        if assessment == nil, let record {
                            HStack {
                                MonitorLabel("Record")
                                Spacer()
                                Text("\(Int(record.rounded()))")
                                    .font(theme.font(14, .bold))
                                    .foregroundStyle(theme.text)
                            }
                        }
                    }
                }
            }
            Text(caption(score: score, assessment: assessment))
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
        .sheet(isPresented: $showsInfo) {
            EnduranceInfoView(exercise: exercise)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }

    private func caption(score: Double?, assessment: EnduranceAssessment?) -> String {
        if score == nil {
            return "Le score se calcule sur les séances d'au moins 3 séries."
                + (exercise.isWeighted ? " Pense à régler ta charge sous le cadran." : "")
        }
        if let assessment {
            return "Meilleure série : \(assessment.reps) pompes · niveau \(assessment.level.title.lowercased()) pour \(assessment.sex == .male ? "un homme" : "une femme") de \(assessment.ageBand) (barème SCPE)."
        }
        if exercise == .pushups {
            return "Renseigne ton âge et ton sexe dans les Réglages pour situer ton niveau sur le barème de référence."
        }
        return "La jauge se remplit jusqu'à ton record."
    }
}

/// (i) : ce que mesure le score d'endurance, comment il se calcule, et ses limites.
struct EnduranceInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SCORE D'ENDURANCE")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Ce qu'il mesure",
                            "L'endurance musculaire locale : la capacité d'un groupe de muscles à répéter un mouvement série après série, avec peu de repos. Elle combine trois qualités : le nombre de répétitions d'affilée, le maintien de ce nombre d'une série à l'autre, et la vitesse de récupération entre les séries.")

                    VStack(alignment: .leading, spacing: 10) {
                        MonitorLabel("Le calcul")
                        formula
                        paragraph("r₁, r₂, r₃ : les répétitions des trois premières séries de la séance. R : le repos qui précède la série (borné entre 15 s et 5 min). Un format commun de trois séries rend les séances — et les personnes — comparables, quel que soit le nombre de séries faites ensuite.")
                        weightTable
                    }

                    section("Pourquoi le repos compte",
                            "Pendant un effort bref et intense, le muscle puise dans ses réserves de phosphocréatine. Entre deux séries, elles se reconstituent vite au début puis de plus en plus lentement : une bonne moitié en quelques dizaines de secondes, presque tout en 3 à 5 minutes. Refaire autant de répétitions après un repos court demande donc plus d'endurance. Le coefficient k(R) en tient compte : l'exposant 0,2 compense à peu près la baisse de répétitions qu'entraîne un repos deux fois plus court, si bien que le choix du repos ne change pas le score à niveau égal — seule la progression le fait monter.")

                    if exercise.isWeighted {
                        section("Avec une charge",
                                "Pour Biceps et Développé, le score est multiplié par la charge totale soulevée — 2 haltères de 5 kg : 10 kg. C'est le tonnage (répétitions × charge), la mesure classique du travail en musculation. Plus lourd ou plus de répétitions : le score monte.")
                    }

                    section("Ton niveau",
                            "Pour les pompes, ta meilleure série des 4 dernières semaines est comparée au barème du test de pompes de la Société canadienne de physiologie de l'exercice (SCPE), repris par l'American College of Sports Medicine : cinq niveaux, de « À améliorer » à « Excellent », selon l'âge et le sexe. Le test consiste à faire le plus de pompes possible d'affilée ; pour les femmes, il se fait genoux au sol, si bien qu'avec des pompes classiques le niveau affiché est sous-estimé. Les autres exercices n'ont pas de barème aussi solide : leur jauge se remplit jusqu'à ton record.")

                    section("Les limites",
                            "Le score suppose des séries proches de ton maximum : arrêter une série bien avant la fatigue le fait baisser. Il dépend du comptage de l'app (corrige une série en fin de séance si besoin). Il ne mesure pas la qualité du mouvement (amplitude, posture). C'est un repère d'entraînement, pas une évaluation médicale.")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private var formula: some View {
        VStack(spacing: 8) {
            Text("r₁ + r₂·k(R₂) + r₃·k(R₃)")
            Text("k(R) = (60 s ÷ R)^0,2")
                .foregroundStyle(theme.dim)
        }
        .font(theme.font(16, .bold))
        .foregroundStyle(theme.text)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }

    /// Le poids d'une répétition selon le repos qui la précède.
    private var weightTable: some View {
        HStack(spacing: 0) {
            ForEach([(15.0, "15 s"), (30.0, "30 s"), (60.0, "1 min"), (120.0, "2 min"), (180.0, "3 min")], id: \.1) { rest, label in
                VStack(spacing: 4) {
                    Text(label)
                        .font(theme.font(10))
                        .foregroundStyle(theme.dim)
                    Text("×\(Format.decimal(pow(60 / rest, 0.2)))")
                        .font(theme.font(14, .bold))
                        .foregroundStyle(rest == 60 ? theme.text : (rest < 60 ? theme.ok : theme.dim))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonitorLabel(title)
            paragraph(text)
        }
    }

    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(theme.font(13))
            .foregroundStyle(theme.text)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// La tuile Score d'endurance de l'historique : le score, le niveau (ou l'évolution sur 4
/// semaines) et la courbe. Avant le premier score, où l'on en est (« 2 / 3 séries »).
struct EnduranceTile: View {
    @Environment(\.theme) private var theme
    @AppStorage(Profile.sexKey) private var sexID = ""
    @AppStorage(Profile.birthYearKey) private var birthYear = 0
    let stats: HistoryStats
    let exercise: Exercise

    var body: some View {
        let curve = stats.sessionIndices()
        HistoryTile(title: "Score d'endurance") {
            if let score = stats.performanceIndex() {
                Text("\(Int(score.rounded()))")
                    .font(theme.font(32, .bold))
                    .foregroundStyle(LinearGradient(colors: [theme.secondary, theme.primary],
                                                    startPoint: .leading, endPoint: .trailing))
                    .monospacedDigit()
                Text(subtitle(score: score))
                    .font(theme.font(11, .bold))
                    .foregroundStyle(theme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if curve.points.count >= 2 {
                    LineChart(points: curve.points, span: curve.span)
                        .frame(height: 26)
                }
            } else {
                // En cours : le score demande une séance d'au moins 3 séries
                let needed = SessionRecord.indexSets
                let sets = min(stats.sessions.map { $0.orderedSets.count }.max() ?? 0, needed - 1)
                Text("\(sets) / \(needed)")
                    .font(theme.font(32, .bold))
                    .foregroundStyle(theme.dim)
                    .monospacedDigit()
                Text("séries dans une séance")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// Le niveau quand il y a un barème ; sinon l'évolution sur 4 semaines.
    private func subtitle(score: Double) -> String {
        if let assessment = EnduranceAssessment.make(exercise: exercise, bestSet: stats.bestSet(lastDays: 28)) {
            return assessment.level.title
        }
        if let previous = stats.previousPerformanceIndex, previous > 0 {
            let change = (score - previous) / previous * 100
            return "\(change >= 0 ? "▲" : "▼") \(Format.percent(change)) % en 4 sem."
        }
        return " "
    }
}
