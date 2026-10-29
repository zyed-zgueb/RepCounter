import SwiftUI

// MARK: - Couleurs et mots du plan

extension TrainingPlan.Today {
    /// La couleur d'état (skill reps-ux, § 5) : bleu, séance prévue ; orange, séance légère ;
    /// violet, semaine allégée ; vert, jour de test.
    func color(_ theme: AppTheme) -> Color {
        switch self {
        case .session: return theme.primary
        case .light: return theme.warn
        case .deload: return theme.rest
        case .test: return theme.ok
        }
    }

    /// « 4 × 15 », « léger · 2 × 15 », « allégée · 2 × 15 », « test · série max ».
    var label: String {
        switch self {
        case .session(let s): return "\(s.sets) × \(s.reps)"
        case .light(let s): return "léger · \(s.sets) × \(s.reps)"
        case .deload(let s): return "allégée · \(s.sets) × \(s.reps)"
        case .test: return "test · série max"
        }
    }
}

extension TrainingPlan.Week {
    var name: String {
        switch kind {
        case .progression(let index, let redo): return "Progr. \(index + 1)\(redo ? " bis" : "")"
        case .deload: return "Allégée"
        }
    }
}

/// La ligne du jour sous le cadran, en veille : « aujourd'hui · 4 × 15 ».
struct TodayLine: View {
    @Environment(\.theme) private var theme
    let today: TrainingPlan.Today

    var body: some View {
        HStack(spacing: 4) {
            Text("aujourd'hui ·")
                .foregroundStyle(theme.dim)
            Text(today.label)
                .fontWeight(.bold)
                .foregroundStyle(today.color(theme))
        }
        .font(theme.font(12))
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Frise

/// Le bloc sur sa frise (skill reps-ux, § 4 : jamais sur le cadran) : les semaines, un point par
/// séance (plein : faite ; orange : manquée), le test, et « tu es ici ».
struct BlockFrise: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    var showsHere = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(plan.weeks.enumerated()), id: \.offset) { _, week in
                    segment(week)
                }
                VStack(spacing: 4) {
                    Text("TEST").font(theme.font(8.5, .bold)).foregroundStyle(theme.dim)
                    Rectangle()
                        .stroke(theme.ok, lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                        .rotationEffect(.degrees(45))
                        .padding(.vertical, 1)
                    Circle().stroke(theme.line, lineWidth: 1).frame(width: 6, height: 6)
                }
                .frame(width: 26)
            }
            if showsHere {
                GeometryReader { geometry in
                    Text("▲ tu es ici")
                        .font(theme.font(9))
                        .foregroundStyle(theme.primary)
                        .fixedSize()
                        .offset(x: min(max(herePosition * geometry.size.width - 6, 0), geometry.size.width - 60))
                }
                .frame(height: 12)
            }
        }
    }

    private func segment(_ week: TrainingPlan.Week) -> some View {
        let color = week.kind == .deload ? theme.rest : theme.primary
        let fill: Double = week.isPast ? 1 : (week.isCurrent ? dayShare(week) : 0)
        return VStack(spacing: 4) {
            Text(week.name.uppercased())
                .font(theme.font(8.5, week.isCurrent ? .bold : .regular))
                .foregroundStyle(week.isCurrent ? theme.text : theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).stroke(week.isCurrent ? color : theme.line, lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(week.isCurrent ? 1 : 0.55))
                        .frame(width: geometry.size.width * fill)
                }
            }
            .frame(height: 10)
            HStack(spacing: 3) {
                ForEach(0..<max(week.plannedSessions, week.done), id: \.self) { index in
                    let done = index < week.done
                    let missed = !done && week.isPast
                    Circle()
                        .fill(done ? theme.primary : .clear)
                        .overlay(Circle().stroke(done ? theme.primary : (missed ? theme.warn : theme.line), lineWidth: 1))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dayShare(_ week: TrainingPlan.Week) -> Double {
        min(max(Date().timeIntervalSince(week.start) / (7 * 86_400), 0), 1)
    }

    /// Où l'on est sur la frise (0 … 1).
    private var herePosition: CGFloat {
        let count = Double(plan.weeks.count) + 0.4
        if let index = plan.weeks.firstIndex(where: { $0.isCurrent }) {
            return CGFloat((Double(index) + dayShare(plan.weeks[index])) / count)
        }
        return CGFloat(Double(plan.weeks.count) / count)
    }
}

// MARK: - Cartes du Coaching

/// Le bloc en cours : son numéro, la date du test, la frise ; une semaine refaite le dit.
struct BlockCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let redo = plan.weeks.last(where: { $0.redoReason != nil }), plan.currentWeek?.kind != .deload {
                HStack {
                    Circle().fill(theme.warn).frame(width: 8, height: 8)
                    Text("\(redo.name.uppercased()) REFAITE")
                        .font(theme.font(12, .bold))
                        .foregroundStyle(theme.warn)
                    Spacer()
                    Text(redo.redoReason ?? "")
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                }
            }
            HStack {
                Text("BLOC \(plan.block)")
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                MonitorLabel(plan.today == .test ? "test aujourd'hui" : "test le \(Format.shortDate(plan.testDate))",
                             color: plan.today == .test ? theme.ok : theme.dim)
            }
            BlockFrise(plan: plan)
        }
        .coachingCard(theme)
    }
}

/// Prévu face au fait, par semaine, en répétitions.
struct PlanWeekTable: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonitorLabel("Prévu / fait · répétitions")
            Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 6) {
                GridRow {
                    Text("").gridColumnAlignment(.leading)
                    header("Prévu")
                    header("Fait")
                    header("Écart")
                }
                ForEach(Array(plan.weeks.enumerated()), id: \.offset) { _, week in
                    if week.isPast || week.isCurrent {
                        GridRow {
                            Text(week.name).foregroundStyle(theme.text).gridColumnAlignment(.leading)
                            Text("\(week.plannedReps)").foregroundStyle(theme.dim)
                            Text(week.isCurrent ? "\(week.doneReps) / \(week.plannedReps)" : "\(week.doneReps)")
                                .foregroundStyle(theme.text)
                            gap(week)
                        }
                    }
                }
            }
            .font(theme.font(11))
            .monospacedDigit()
        }
        .coachingCard(theme)
    }

    private func header(_ text: String) -> some View {
        Text(text.uppercased()).font(theme.font(9, .bold)).foregroundStyle(theme.dim)
    }

    @ViewBuilder
    private func gap(_ week: TrainingPlan.Week) -> some View {
        if week.isCurrent {
            Text("en cours").foregroundStyle(theme.dim)
        } else if week.plannedReps > 0 {
            let percent = Int((Double(week.doneReps - week.plannedReps) / Double(week.plannedReps) * 100).rounded())
            Text("\(Format.signed(percent)) %").foregroundStyle(percent >= 0 ? theme.ok : theme.dim)
        }
    }
}

/// Mesuré face à attendu : le max à chaque test, la ligne du rythme nécessaire (départ →
/// objectif à la date choisie), et la projection après 3 tests.
struct TrajectoryCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                MonitorLabel("Max aux tests")
                Spacer()
                if let verdict = plan.verdict {
                    Text(verdictText(verdict))
                        .font(theme.font(12, .bold))
                        .foregroundStyle(verdictColor(verdict))
                }
            }
            TrajectoryChart(plan: plan)
                .frame(height: 150)
            Text(plan.goal.date == nil
                 ? "losanges : ton max à chaque test · fixe une date pour voir le rythme nécessaire"
                 : "pointillés : le rythme nécessaire · losanges : ton max à chaque test")
                .font(theme.font(10))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            if let projection = plan.projection {
                HStack {
                    MonitorLabel("À ce rythme")
                    Spacer()
                    Text("\(plan.goal.target) vers le \(Format.shortDate(projection))")
                        .font(theme.font(12, .bold))
                        .foregroundStyle(theme.text)
                }
            }
            if plan.shiftWeeks > 0, let shifted = plan.shiftedGoalDate {
                HStack {
                    MonitorLabel("Objectif \(plan.goal.target)")
                    Spacer()
                    Text("le \(Format.shortDate(shifted)) · +\(plan.shiftWeeks) sem.")
                        .font(theme.font(12, .bold))
                        .foregroundStyle(theme.warn)
                }
            }
        }
        .coachingCard(theme)
    }

    private func verdictText(_ verdict: TrainingPlan.Verdict) -> String {
        switch verdict {
        case .pending(let count): return "\(count) / \(TrainingPlan.minTests) tests"
        case .ahead: return "en avance"
        case .onTrack: return "dans le rythme"
        case .behind: return "en retard"
        }
    }

    private func verdictColor(_ verdict: TrainingPlan.Verdict) -> Color {
        switch verdict {
        case .ahead: return theme.ok
        case .behind: return theme.warn
        case .onTrack, .pending: return theme.dim
        }
    }
}

private struct TrajectoryChart: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        Canvas { context, size in
            let start = plan.goal.created
            let end = max(plan.shiftedGoalDate ?? plan.testDate, plan.tests.last?.date ?? start, plan.testDate)
                .addingTimeInterval(7 * 86_400)
            let values = plan.tests.map { Double($0.value) } + [Double(plan.goal.start), Double(plan.goal.target)]
            let low = (values.min() ?? 0) - 2, high = (values.max() ?? 1) + 2
            let x = { (date: Date) -> CGFloat in
                CGFloat(date.timeIntervalSince(start) / max(end.timeIntervalSince(start), 1)) * (size.width - 8) + 4
            }
            let y = { (value: Double) -> CGFloat in
                size.height - 6 - CGFloat((value - low) / max(high - low, 1)) * (size.height - 12)
            }
            // Objectif
            var goalLine = Path()
            goalLine.move(to: CGPoint(x: 0, y: y(Double(plan.goal.target))))
            goalLine.addLine(to: CGPoint(x: size.width, y: y(Double(plan.goal.target))))
            context.stroke(goalLine, with: .color(theme.ok.opacity(0.5)), lineWidth: 0.8)
            // Rythme nécessaire
            if let goalDate = plan.shiftedGoalDate {
                var line = Path()
                line.move(to: CGPoint(x: x(start), y: y(Double(plan.goal.start))))
                line.addLine(to: CGPoint(x: x(goalDate), y: y(Double(plan.goal.target))))
                context.stroke(line, with: .color(theme.dim), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            }
            // Projection (tendance des tests)
            if let projection = plan.projection, let last = plan.tests.last {
                var line = Path()
                line.move(to: CGPoint(x: x(last.date), y: y(Double(last.value))))
                line.addLine(to: CGPoint(x: x(min(projection, end)), y: y(Double(plan.goal.target))))
                context.stroke(line, with: .color(theme.primary), style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
            }
            // Tests mesurés
            for test in plan.tests {
                let point = CGPoint(x: x(test.date), y: y(Double(test.value)))
                var diamond = Path()
                diamond.move(to: CGPoint(x: point.x, y: point.y - 5))
                diamond.addLine(to: CGPoint(x: point.x + 5, y: point.y))
                diamond.addLine(to: CGPoint(x: point.x, y: point.y + 5))
                diamond.addLine(to: CGPoint(x: point.x - 5, y: point.y))
                diamond.closeSubpath()
                context.fill(diamond, with: .color(theme.ok))
                context.draw(Text("\(test.value)").font(theme.font(9)).foregroundStyle(theme.text),
                             at: CGPoint(x: point.x + 12, y: point.y - 6))
            }
        }
        .accessibilityLabel("Max mesuré aux tests face au rythme nécessaire")
    }
}

// MARK: - La fiche du bloc (une fois)

/// « Un bloc = 4 semaines », à la première ouverture du Coaching avec un plan.
struct BlockSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    static let key = "coaching.blockExplained"
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MonitorLabel("Un bloc = 4 semaines", color: theme.primary)
                .padding(.top, 20)
            BlockFrise(plan: plan, showsHere: false)
            VStack(alignment: .leading, spacing: 12) {
                row(theme.primary, "3 semaines de progression", "ta séance habituelle, chaque semaine")
                row(theme.rest, "1 semaine allégée", "moins de volume : la fatigue retombe")
                row(theme.ok, "Le test", "une série max : ton nouveau niveau")
                row(theme.line, "Puis le bloc suivant", "recalé sur ce nouveau niveau")
            }
            Spacer(minLength: 0)
            Button("Compris") {
                UserDefaults.standard.set(true, forKey: Self.key)
                dismiss()
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 54))
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func row(_ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 12, height: 12).padding(.top, 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(theme.font(13, .bold)).foregroundStyle(theme.text)
                Text(detail).font(theme.font(11)).foregroundStyle(theme.dim)
            }
        }
    }
}

extension View {
    /// Le cadre commun des cartes du Coaching.
    func coachingCard(_ theme: AppTheme) -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }
}

// MARK: - (i)

/// (i) du plan : le bloc, ce qui est sourcé, ce qui est un choix de l'app, ce qui est provisoire.
struct PlanInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LE PLAN")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Le bloc",
                            "3 semaines de progression, 1 semaine allégée, puis un test : une série max, ton nouveau niveau. Le bloc suivant repart de là. Le rythme 3 + 1 et le test toutes les 4 semaines sont des choix de l'app.")
                    section("La séance prévue",
                            "Provisoire : ta séance habituelle pour l'exercice (séries, répétitions par série, repos, séances par semaine : médianes des 4 semaines avant le bloc), sans augmentation d'une semaine à l'autre. Les valeurs recommandées seront reprises de la prise de position de l'ACSM (2026) une fois lue en texte intégral.")
                    section("La semaine allégée",
                            "7 jours à volume réduit : la moitié des séries (part provisoire, choix de l'app). Réduire le volume fait consensus (Bell et al. 2023) ; les athlètes de force allègent en moyenne 6,4 jours (Rogerson et al. 2024).")
                    section("Quand ça décroche",
                            "Une semaine de progression avec des séances manquées, ou deux séances en Forme basse, est refaite (deux fois au plus par bloc). Le test recule d'autant, et la date de l'objectif aussi. Forme basse aujourd'hui : séance légère, la moitié des séries. Ces règles sont des choix de l'app ; deux mesures plutôt qu'une, pour ne pas confondre une baisse et le bruit (Hopkins 2000) ; au-delà de 2 semaines de baisse, une semaine allégée (Meeusen et al. 2013).")
                    section("Mesuré face à attendu",
                            "L'attendu est le rythme qu'il te faut pour aller de ton départ à ton objectif à la date choisie : ce n'est pas une prédiction, aucune courbe de progression au poids du corps n'est publiée. « En avance » ou « en retard » seulement après 3 tests, quand la pente de tes tests (Theil-Sen, intervalle à 99 %, Sen 1968) est sûrement au-dessus ou au-dessous du rythme nécessaire.")
                    section("Séance faite",
                            "Une séance compte comme faite dès que le total prévu est atteint, même si les séries diffèrent un peu (choix de l'app).")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

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
