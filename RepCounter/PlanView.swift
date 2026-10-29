import SwiftUI

// MARK: - Intensité et mots du plan

/// L'intensité (skill reps-ux, § 5) : calme (semaine allégée, séance légère) → soutenu
/// (progression) → maximal (jour de test).
enum Intensity {
    static let calm = 0.0
    static let work = AppTheme.workLevel
    static let max = 1.0

    static func word(_ level: Double) -> String {
        level < 0.3 ? "calme" : (level < 0.85 ? "soutenue" : "maximale")
    }
}

extension TrainingPlan.Today {
    /// Le niveau d'intensité du jour.
    var intensity: Double {
        switch self {
        case .session: return Intensity.work
        case .light, .deload: return Intensity.calm
        case .test: return Intensity.max
        }
    }

    /// La couleur du jour, sur l'échelle d'intensité.
    func color(_ theme: AppTheme) -> Color { theme.intensity(intensity) }

    /// « 29 · 25 · 22 · repos 1:30 », « ! léger · 29 · 25 · repos 1:30 », « allégée · … »,
    /// « test · série max ». La séance légère est une alerte : « ! ».
    var label: String {
        switch self {
        case .session(let s): return "\(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .light(let s): return "! léger · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .deload(let s): return "allégée · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .test: return "◆ test · série max"
        }
    }

    /// Sans le repos : « 29 · 25 · 22 », « ◆ test · série max ».
    var short: String {
        switch self {
        case .session(let s): return s.label
        case .light(let s): return "! léger · \(s.label)"
        case .deload(let s): return "allégée · \(s.label)"
        case .test: return "◆ test · série max"
        }
    }
}

extension TrainingPlan.Week {
    /// « P1 », « P2 bis », « A ».
    var short: String {
        switch kind {
        case .progression(let index, let redo): return "P\(index + 1)\(redo ? " bis" : "")"
        case .deload: return "A"
        }
    }

    var name: String {
        switch kind {
        case .progression(let index, let redo): return "Progr. \(index + 1)\(redo ? " bis" : "")"
        case .deload: return "Allégée"
        }
    }

    var intensity: Double { kind == .deload ? Intensity.calm : Intensity.work }

    /// Semaine refaite après un décrochage (alerte : « ! »).
    var isRedo: Bool {
        if case .progression(_, let redo) = kind { return redo }
        return false
    }
}

extension TrainingPlan {
    /// L'intensité de la semaine en cours (jour de test : maximale).
    var weekIntensity: Double {
        if today == .test { return Intensity.max }
        return currentWeek?.intensity ?? Intensity.work
    }
}

/// La ligne du jour sous le cadran, en veille : « aujourd'hui · 29 · 25 · 22 · repos 1:30 »,
/// « fait ✓ · prochaine vendredi », ou « repos · prochaine vendredi ». Démarrer reste possible.
struct TodayLine: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        HStack(spacing: 4) {
            switch plan.status {
            case .due:
                Text("aujourd'hui ·").foregroundStyle(theme.dim)
                Text(plan.today.label).fontWeight(.bold).foregroundStyle(plan.today.color(theme))
            case .done:
                Text("fait ✓").fontWeight(.bold).foregroundStyle(theme.ok)
                nextText
            case .rest:
                Text("repos").fontWeight(.bold).foregroundStyle(theme.dim)
                nextText
            }
        }
        .font(theme.font(12))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var nextText: some View {
        if let next = plan.next {
            Text("· prochaine \(Format.weekdayOrDate(next))").foregroundStyle(theme.dim)
        }
    }
}

/// La séance en cours, sous le cadran : une case par série prévue (« 29 ✓ · 25 ← · 22 »).
/// Faites : le nombre réel, en vert si la cible est atteinte ; en cours : marquée ; à venir : la cible.
struct SetRow: View {
    @Environment(\.theme) private var theme
    let planDay: WorkoutModel.PlanDay
    /// Séries faites dans cette séance.
    let done: [Int]
    /// Répétitions de la série en cours (nil pendant la récupération).
    let current: Int?

    var body: some View {
        let all = planDay.earlierToday + done
        let next = Prescription.nextTarget(planDay.session, ratios: planDay.ratios, dayDone: all, sessionDone: done)
        HStack(spacing: 6) {
            ForEach(0..<max(planDay.session.sets, all.count), id: \.self) { index in
                if index > 0 { Text("·").foregroundStyle(theme.dim) }
                cell(index, all: all, next: next)
            }
        }
        .font(theme.font(14, .bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cell(_ index: Int, all: [Int], next: Int?) -> some View {
        let planned = index < planDay.session.sets ? planDay.session.targets[index] : nil
        if index < all.count {
            let reached = planned.map { all[index] >= $0 } ?? true
            Text("\(all[index])\(reached ? " ✓" : "")").foregroundStyle(reached ? theme.ok : theme.text)
        } else if index == all.count {
            // La série en cours (ou la prochaine) : sa cible, réajustée
            Text("\(current.map { "\($0)/" } ?? "")\(next ?? planned ?? 0) ←").foregroundStyle(theme.primary)
        } else {
            Text("\(planned ?? 0)").foregroundStyle(theme.dim)
        }
    }
}

// MARK: - Frise

/// Le bloc sur sa frise (skill reps-ux, § 4 : jamais sur le cadran) : les semaines colorées par
/// l'intensité (progression ambre, allégée bleue, test rouge), un point par séance (● faite,
/// ○ prévue, ! manquée), et « tu es ici ».
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
                    Text("◆").font(theme.font(8.5, .bold)).foregroundStyle(theme.max)
                    Rectangle()
                        .stroke(theme.max, lineWidth: 1.5)
                        .frame(width: 9, height: 9)
                        .rotationEffect(.degrees(45))
                        .padding(.vertical, 1)
                    Circle().stroke(theme.line, lineWidth: 1).frame(width: 6, height: 6)
                }
                .frame(width: 22)
            }
            if showsHere {
                GeometryReader { geometry in
                    Text("▲ tu es ici")
                        .font(theme.font(9))
                        .foregroundStyle(theme.text)
                        .fixedSize()
                        .offset(x: min(max(herePosition * geometry.size.width - 6, 0), geometry.size.width - 60))
                }
                .frame(height: 12)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bloc \(plan.block), \(plan.currentWeek?.name ?? "test"), test le \(Format.shortDate(plan.testDate))")
    }

    private func segment(_ week: TrainingPlan.Week) -> some View {
        let color = theme.intensity(week.intensity)
        let fill: Double = week.isPast ? 1 : (week.isCurrent ? dayShare(week) : 0)
        return VStack(spacing: 4) {
            Text((week.isRedo ? "! " : "") + week.short)
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
                    if index >= week.done && week.isPast {
                        Text("!").font(theme.font(8, .bold)).foregroundStyle(theme.text).frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(index < week.done ? theme.text : .clear)
                            .overlay(Circle().stroke(index < week.done ? theme.text : theme.line, lineWidth: 1))
                            .frame(width: 6, height: 6)
                    }
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

// MARK: - Jauge d'intensité

/// L'intensité de la semaine en demi-cercle : un arc en dégradé (calme → maximal), une aiguille,
/// les repères A (allégée), P (progression), ◆ (test). Ce n'est pas le cadran de comptage.
struct IntensityGauge: View {
    @Environment(\.theme) private var theme
    let level: Double

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height - 6)
            let radius = min(size.width / 2, size.height) - 8
            let angle = { (value: Double) -> Angle in .radians(.pi * (1 + value)) }
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .radians(.pi), endAngle: .radians(2 * .pi), clockwise: false)
            context.stroke(arc, with: .linearGradient(theme.intensityGradient,
                                                       startPoint: CGPoint(x: center.x - radius, y: 0),
                                                       endPoint: CGPoint(x: center.x + radius, y: 0)),
                           style: StrokeStyle(lineWidth: 8, lineCap: .round))
            for (value, mark) in [(0.1, "A"), (Intensity.work, "P"), (0.95, "◆")] {
                let a = angle(value).radians
                let point = CGPoint(x: center.x + CGFloat(cos(a)) * (radius - 15), y: center.y + CGFloat(sin(a)) * (radius - 15))
                context.draw(Text(mark).font(theme.font(7)).foregroundStyle(theme.dim), at: point)
            }
            let a = angle(min(max(level, 0), 1)).radians
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * (radius - 4), y: center.y + CGFloat(sin(a)) * (radius - 4)))
            context.stroke(needle, with: .color(theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)), with: .color(theme.text))
        }
        .accessibilityLabel("Intensité de la semaine : \(Intensity.word(level))")
    }
}

// MARK: - Cartes du Coaching

/// Le bloc en cours : « B2 · P3 », l'intensité en mots et en jauge, la date du test, la frise,
/// la semaine jour par jour, et le prévu face au fait en barres.
struct BlockCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    let exercise: Exercise
    /// Un jour de séance a été déplacé.
    let onDaysChanged: () -> Void

    var body: some View {
        let level = plan.weekIntensity
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("B\(plan.block) · \(plan.today == .test ? "◆" : (plan.currentWeek?.short ?? "◆"))")
                        .font(theme.font(15, .bold))
                        .foregroundStyle(theme.text)
                    MonitorLabel("intensité \(Intensity.word(level))", color: theme.intensity(level))
                    MonitorLabel(plan.today == .test ? "◆ aujourd'hui" : "◆ \(Format.shortDate(plan.testDate))")
                    if let redo = plan.weeks.last(where: { $0.redoReason != nil }), plan.currentWeek?.kind != .deload {
                        MonitorLabel("! \(redo.short) refaite · \(redo.redoReason ?? "")", color: theme.text)
                    }
                }
                Spacer(minLength: 8)
                IntensityGauge(level: level)
                    .frame(width: 112, height: 64)
            }
            BlockFrise(plan: plan)
            if !plan.days.isEmpty {
                WeekDays(plan: plan, exercise: exercise, onChange: onDaysChanged)
            }
            WeekBars(plan: plan)
                .frame(height: 92)
        }
        .coachingCard(theme)
    }
}

/// La semaine en cours, L M M J V S D : ○ prévu, ● fait, ! manqué, aujourd'hui souligné.
/// Toucher un jour l'ajoute ou le retire des jours de séance (2 au moins) : le placement est un
/// choix de l'app, l'utilisateur le déplace. L'astuce s'affiche une fois.
struct WeekDays: View {
    @Environment(\.theme) private var theme
    @AppStorage("coaching.daysHintSeen") private var hintSeen = false
    let plan: TrainingPlan
    let exercise: Exercise
    let onChange: () -> Void
    private static let letters = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        let spaced = plan.days.filter { $0.sessions >= 2 }
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    Button { toggle(index + 1) } label: { cell(index, day) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Self.letters[index]) \(day.planned ? "prévu" : "repos")\(day.sessions > 0 ? ", fait" : "")\(day.missed ? ", manqué" : "")")
                }
            }
            if !hintSeen {
                Text("☝ touche un jour pour le déplacer")
                    .font(theme.font(10))
                    .foregroundStyle(theme.dim)
                    .frame(maxWidth: .infinity)
            }
            if let day = spaced.last {
                MonitorLabel("séries espacées · \(Format.weekdayOrDate(day.date))")
            }
        }
    }

    private func cell(_ index: Int, _ day: TrainingPlan.Day) -> some View {
        let done = day.sessions > 0
        return VStack(spacing: 3) {
            Text(Self.letters[index])
                .font(theme.font(10, day.isToday ? .bold : .regular))
                .foregroundStyle(day.isToday ? theme.text : theme.dim)
            ZStack {
                if day.missed {
                    Text("!").font(theme.font(12, .bold)).foregroundStyle(theme.text)
                } else {
                    Circle()
                        .fill(done ? theme.text : .clear)
                        .overlay(Circle().stroke(day.planned || done ? theme.text : theme.line, lineWidth: day.planned ? 1.5 : 1))
                }
            }
            .frame(width: 14, height: 14)
            Rectangle()
                .fill(day.isToday ? theme.text : .clear)
                .frame(width: 10, height: 2)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private func toggle(_ weekday: Int) {
        var days = Set(plan.days.enumerated().filter { $0.element.planned }.map { $0.offset + 1 })
        if days.contains(weekday) {
            guard days.count > Prescription.minSessionsPerWeek else { return }
            days.remove(weekday)
        } else {
            days.insert(weekday)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        hintSeen = true
        Schedule.save(Array(days), for: exercise)
        onChange()
    }
}

/// Prévu face au fait, une barre par semaine du bloc : contour = prévu (couleur de
/// l'intensité), plein = fait, ✓ si atteint, ← pour la semaine en cours.
struct WeekBars: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        Canvas { context, size in
            let weeks = plan.weeks
            guard !weeks.isEmpty else { return }
            let top = CGFloat(weeks.map { max($0.plannedReps, $0.doneReps) }.max() ?? 1)
            let slot = size.width / CGFloat(weeks.count)
            let barWidth = min(slot * 0.62, 44)
            let base = size.height - 16
            let scale = (base - 18) / max(top, 1)
            for (index, week) in weeks.enumerated() {
                let x = CGFloat(index) * slot + (slot - barWidth) / 2
                let color = theme.intensity(week.intensity)
                let plannedHeight = CGFloat(week.plannedReps) * scale
                let doneHeight = CGFloat(week.doneReps) * scale
                let planned = CGRect(x: x, y: base - plannedHeight, width: barWidth, height: plannedHeight)
                context.stroke(Path(roundedRect: planned, cornerRadius: 2), with: .color(color.opacity(0.75)),
                               style: StrokeStyle(lineWidth: 1, dash: week.kind == .deload ? [3, 2] : []))
                let reached = week.doneReps >= week.plannedReps && week.plannedReps > 0
                if week.doneReps > 0 {
                    let done = CGRect(x: x + 3, y: base - doneHeight, width: barWidth - 6, height: doneHeight)
                    context.fill(Path(roundedRect: done, cornerRadius: 1.5),
                                 with: .color((reached ? theme.ok : color).opacity(week.isCurrent ? 0.9 : 0.75)))
                }
                let mark = reached ? "✓" : (week.isCurrent ? "←" : (week.isPast ? "!" : "○"))
                context.draw(Text(mark).font(theme.font(10, .bold)).foregroundStyle(reached ? theme.ok : theme.text),
                             at: CGPoint(x: x + barWidth / 2, y: base - max(plannedHeight, doneHeight) - 8))
                context.draw(Text(week.short).font(theme.font(9, week.isCurrent ? .bold : .regular))
                                .foregroundStyle(week.isCurrent ? theme.text : theme.dim),
                             at: CGPoint(x: x + barWidth / 2, y: size.height - 6))
            }
        }
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        guard let week = plan.currentWeek else { return "Prévu face au fait par semaine" }
        return "Semaine en cours : \(week.doneReps) répétitions faites sur \(week.plannedReps) prévues"
    }
}

// MARK: - Le chemin vers l'objectif

/// Le chemin, du départ à la date de l'objectif, pour ce qui est mesuré (« pompes d'affilée ») :
/// le départ ●, la meilleure série de chaque séance •, les tests ◆ (pleins et chiffrés une fois
/// faits, creux à venir), la ligne attendue en pointillés, l'objectif ⚑, aujourd'hui ▼. Les blocs
/// sont de simples repères (un filet à chaque début, B1…Bn sous l'axe) : l'intensité est dans la
/// carte du bloc. Une légende d'une ligne.
struct PathCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    let exercise: Exercise
    /// Les séances de l'exercice (la meilleure série de chacune est un point).
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PathChart(plan: plan, exercise: exercise, sessions: sessions)
                .frame(height: 160)
            Text("● départ · • séances · ◆ test · ┄ attendu")
                .font(theme.font(10))
                .foregroundStyle(theme.dim)
            HStack {
                MonitorLabel(plan.today == .test ? "◆ test aujourd'hui" : "◆ prochain test")
                Spacer()
                MonitorLabel(Format.shortDate(plan.testDate))
            }
            if let verdict = settledVerdict {
                HStack {
                    Text(verdictSymbol(verdict))
                        .font(theme.font(13, .bold))
                        .foregroundStyle(verdict == .ahead ? theme.ok : theme.text)
                    Spacer()
                    if let projection = plan.projection, let goal = plan.goal {
                        MonitorLabel("⌖ \(goal.target) vers le \(Format.shortDate(projection))")
                    }
                }
            }
        }
        .coachingCard(theme)
    }

    /// Le verdict, seulement une fois établi (3 tests).
    private var settledVerdict: TrainingPlan.Verdict? {
        guard let verdict = plan.verdict else { return nil }
        if case .pending = verdict { return nil }
        return verdict
    }

    private func verdictSymbol(_ verdict: TrainingPlan.Verdict) -> String {
        switch verdict {
        case .ahead: return "▲ en avance"
        case .onTrack: return "= dans le rythme"
        case .behind: return "▼ en retard"
        case .pending: return ""
        }
    }
}

private struct PathChart: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    let exercise: Exercise
    let sessions: [SessionRecord]

    /// La meilleure série de chaque séance depuis le début du plan, hors séances de test.
    private var points: [(date: Date, value: Int)] {
        let start = plan.goal?.created ?? plan.anchor
        let tests = Set(plan.tests.map(\.date))
        return sessions
            .filter { $0.start >= start && !tests.contains($0.start) && $0.bestSet > 0 }
            .map { (date: $0.start, value: $0.bestSet) }
    }

    var body: some View {
        let points = self.points
        Canvas { context, size in
            let start = plan.goal?.created ?? plan.anchor
            var end = max(plan.shiftedGoalDate ?? plan.testDate, plan.testDate)
            end = max(end, start.addingTimeInterval(16 * 7 * 86_400))
            let left: CGFloat = 22, right: CGFloat = 16, top: CGFloat = 22, bottom = size.height - 16
            let span = max(end.timeIntervalSince(start), 1)
            let x = { (date: Date) -> CGFloat in left + CGFloat(date.timeIntervalSince(start) / span) * (size.width - left - right) }
            // L'échelle englobe le départ, l'objectif, les tests et les séances
            var values = plan.tests.map { Double($0.value) } + points.map { Double($0.value) }
            if let goal = plan.goal { values += [Double(goal.start), Double(goal.target)] }
            let low = (values.min() ?? 0) - 2, high = (values.max() ?? 10) + 2
            let y = { (value: Double) -> CGFloat in bottom - CGFloat((value - low) / max(high - low, 1)) * (bottom - top) }

            // Ce qui est mesuré
            context.draw(Text("\(exercise.shortTitle.lowercased()) d'affilée").font(theme.font(9, .bold)).foregroundStyle(theme.dim),
                         at: CGPoint(x: 0, y: 6), anchor: .leading)

            // Les blocs : un filet à chaque début, B1…Bn sous l'axe ; puis ceux à venir
            var starts = plan.blocks.map(\.start)
            var next = (plan.blocks.last?.test ?? start).addingTimeInterval(7 * 86_400)
            while next < end {
                starts.append(next)
                next = next.addingTimeInterval(5 * 7 * 86_400)
            }
            let tests = plan.blocks.map(\.test) + starts.dropFirst(plan.blocks.count).map { $0.addingTimeInterval(4 * 7 * 86_400) }
            for (index, blockStart) in starts.enumerated() where blockStart < end {
                var rule = Path()
                rule.move(to: CGPoint(x: x(blockStart), y: top))
                rule.addLine(to: CGPoint(x: x(blockStart), y: bottom))
                context.stroke(rule, with: .color(theme.grid), lineWidth: 1)
                let blockEnd = index + 1 < starts.count ? min(starts[index + 1], end) : end
                let current = index == plan.blocks.count - 1
                context.draw(Text("B\(index + 1)").font(theme.font(8, current ? .bold : .regular))
                                .foregroundStyle(current ? theme.text : theme.dim),
                             at: CGPoint(x: (x(blockStart) + x(blockEnd)) / 2, y: bottom + 9))
            }

            if let goal = plan.goal {
                // L'objectif : la ligne d'arrivée ⚑
                var finish = Path()
                finish.move(to: CGPoint(x: left, y: y(Double(goal.target))))
                finish.addLine(to: CGPoint(x: size.width - right, y: y(Double(goal.target))))
                context.stroke(finish, with: .color(theme.ok), lineWidth: 1)
                context.draw(Text("⚑").font(theme.font(10)).foregroundStyle(theme.ok),
                             at: CGPoint(x: size.width - right + 8, y: y(Double(goal.target))))
                context.draw(Text("\(goal.target)").font(theme.font(8)).foregroundStyle(theme.ok),
                             at: CGPoint(x: left - 10, y: y(Double(goal.target))))
                context.draw(Text("\(goal.start)").font(theme.font(8)).foregroundStyle(theme.dim),
                             at: CGPoint(x: left - 10, y: y(Double(goal.start))))
                // L'attendu : départ → objectif à la date choisie
                if let goalDate = plan.shiftedGoalDate {
                    var expected = Path()
                    expected.move(to: CGPoint(x: x(goal.created), y: y(Double(goal.start))))
                    expected.addLine(to: CGPoint(x: x(goalDate), y: y(Double(goal.target))))
                    context.stroke(expected, with: .color(theme.dim), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            // Projection (après 3 tests)
            if let projection = plan.projection, let last = plan.tests.last, let goal = plan.goal {
                var line = Path()
                line.move(to: CGPoint(x: x(last.date), y: y(Double(last.value))))
                line.addLine(to: CGPoint(x: x(min(projection, end)), y: y(Double(goal.target))))
                context.stroke(line, with: .color(theme.primary), style: StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
            }
            // Les séances : la meilleure série de chacune
            for point in points {
                let p = CGPoint(x: x(point.date), y: y(Double(point.value)))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 1.8, y: p.y - 1.8, width: 3.6, height: 3.6)),
                             with: .color(theme.primary.opacity(0.8)))
            }
            // Les tests à venir : ◆ creux, sur la ligne attendue ou au niveau du dernier max
            let lastMax = plan.tests.last?.value ?? points.last?.value ?? plan.goal?.start
            for test in tests.dropFirst(plan.tests.count) where test <= end {
                let level = plan.expected(at: test) ?? lastMax.map(Double.init) ?? low + 2
                context.stroke(diamond(CGPoint(x: x(test), y: y(level)), 4), with: .color(theme.dim), lineWidth: 1.2)
            }
            // Les tests faits : ◆ pleins, chiffrés
            for test in plan.tests {
                let point = CGPoint(x: x(test.date), y: y(Double(test.value)))
                context.fill(diamond(point, 5), with: .color(theme.text))
                context.draw(Text("\(test.value)").font(theme.font(9, .bold)).foregroundStyle(theme.text),
                             at: CGPoint(x: point.x + 11, y: point.y - 7))
            }
            // Le départ
            if let goal = plan.goal {
                let p = CGPoint(x: x(goal.created), y: y(Double(goal.start)))
                context.fill(Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), with: .color(theme.text))
            }
            // Aujourd'hui
            let now = x(Date())
            var today = Path()
            today.move(to: CGPoint(x: now, y: top))
            today.addLine(to: CGPoint(x: now, y: bottom))
            context.stroke(today, with: .color(theme.primary), lineWidth: 1.2)
            context.draw(Text("▼").font(theme.font(9)).foregroundStyle(theme.primary), at: CGPoint(x: now, y: top - 6))
        }
        .accessibilityLabel(accessibility(points))
    }

    private func diamond(_ center: CGPoint, _ radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.closeSubpath()
        return path
    }

    /// « Pompes d'affilée : départ 30, meilleure séance récente 32, dernier test 33, objectif 40 le 12 févr. »
    private func accessibility(_ points: [(date: Date, value: Int)]) -> String {
        var parts: [String] = []
        if let goal = plan.goal { parts.append("départ \(goal.start)") }
        if let recent = points.suffix(4).map(\.value).max() { parts.append("meilleure séance récente \(recent)") }
        if let last = plan.tests.last { parts.append("dernier test \(last.value)") }
        if let goal = plan.goal {
            parts.append("objectif \(goal.target)" + (plan.shiftedGoalDate.map { " le \(Format.shortDate($0))" } ?? ""))
        }
        return "\(exercise.shortTitle) d'affilée : " + parts.joined(separator: ", ")
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
            MonitorLabel("Un bloc = 4 semaines", color: theme.text)
                .padding(.top, 20)
            BlockFrise(plan: plan, showsHere: false)
            Text("Enchaîne les séries, avec le repos indiqué.")
                .font(theme.font(12, .bold))
                .foregroundStyle(theme.text)
            VStack(alignment: .leading, spacing: 12) {
                row(theme.work, "3 semaines de progression", "3 séries, 2 ou 3 en réserve")
                row(theme.calm, "1 semaine allégée", "moins de volume : la fatigue retombe")
                row(theme.max, "◆ Le test", "une série max : ton nouveau niveau")
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
                            "3 semaines de progression, 1 semaine allégée, puis un test : une série max, ton nouveau niveau. Le bloc suivant repart de là. Le rythme 3 + 1 est un choix de l'app : l'ACSM ne trouve pas une programmation par blocs supérieure à une autre, pourvu que la charge progresse.")
                    section("La séance prévue",
                            "Au moins 2 séances par semaine et 3 séries par séance, enchaînées avec le repos indiqué (ACSM 2026 : « at least twice weekly », « 2–3 sets/session »). La règle de l'ACSM porte sur l'effort : chaque série s'arrête près de l'échec, à 2 ou 3 répétitions en réserve ; aller jusqu'à l'échec n'apporte rien de plus. La série 1 vise ton max moins 3. Avec la fatigue, le nombre baisse d'une série à l'autre : les séries 2 et 3 suivent ta baisse habituelle (mesurée sur tes séances des 4 dernières semaines faites avec un repos proche) ; sans elle, chaque série vise 80 % de la précédente. Une série sous sa cible réajuste aussitôt les suivantes, sans rattrapage. Ces règles, la formule « max − 3 » et les 80 % (une valeur prudente) sont des choix de l'app : l'ACSM précise que la cible exacte n'est pas établie. Le max est celui du dernier test ; au premier bloc, ta meilleure série des 4 dernières semaines.")
                    section("Le repos",
                            "Le tien : ton repos habituel pour l'exercice, arrondi à 15 s. La durée du repos ne change pas les gains de force (ACSM 2026). Des séries faites séparément dans la journée comptent dans la séance du jour, sans pénalité (« séries espacées ») ; la suivante repart de la cible de la série 1. L'ACSM ne les étudie pas : le plan ne les prévoit pas.")
                    section("Les jours",
                            "Les séances sont espacées dans la semaine : 2 séances, lundi et jeudi ; 3, lundi, mercredi et vendredi. Touche un jour dans le Coaching pour le déplacer. Une séance faite un autre jour compte, et remplace la prochaine prévue. L'ACSM ne fixe pas l'espacement : ce placement est un choix de l'app.")
                    section("La progression",
                            "Par le test : ton nouveau max recale la cible du bloc suivant (l'ACSM recommande des tests réguliers). Entre deux tests, la cible reste la même : en devenant plus fort, tu as plus de répétitions en réserve. Aucune hausse d'une semaine à l'autre : l'article n'en chiffre aucune.")
                    section("Ce que la science ne dit pas",
                            "L'entraînement améliore l'endurance musculaire, mais les études ne permettent pas de dire quel dosage l'améliore le mieux (ACSM 2026). Le plan applique donc les recommandations générales (fréquence, séries, effort près de l'échec) et vérifie le résultat, test après test.")
                    section("La semaine allégée",
                            "7 jours à volume réduit : la moitié des séries, arrondie au-dessus (part choisie par l'app). Réduire le volume fait consensus (Bell et al. 2023) ; les athlètes de force allègent en moyenne 6,4 jours (Rogerson et al. 2024). L'ACSM ne traite pas des décharges.")
                    section("Quand ça décroche",
                            "Une semaine de progression avec des séances manquées, ou deux séances en Forme basse, est refaite (deux fois au plus par bloc). Le test recule d'autant, et la date de l'objectif aussi. Forme basse aujourd'hui : séance légère, la moitié des séries. Ces règles sont des choix de l'app ; deux mesures plutôt qu'une, pour ne pas confondre une baisse et le bruit (Hopkins 2000) ; au-delà de 2 semaines de baisse, une semaine allégée (Meeusen et al. 2013).")
                    section("Mesuré face à attendu",
                            "L'attendu est le rythme qu'il te faut pour aller de ton départ à ton objectif à la date choisie : ce n'est pas une prédiction, aucune courbe de progression au poids du corps n'est publiée. « En avance » ou « en retard » seulement après 3 tests, quand la pente de tes tests (Theil-Sen, intervalle à 99 %, Sen 1968) est sûrement au-dessus ou au-dessous du rythme nécessaire.")
                    section("Références",
                            "Currier et al. (2026). Resistance training prescription for muscle function, hypertrophy and physical performance in healthy adults: an overview of reviews. Med Sci Sports Exerc 58(4):851–872. Bell et al. (2023), Sports Med Open 9:87. Rogerson et al. (2024), Sports Med Open 10:26. Meeusen et al. (2013), Med Sci Sports Exerc 45(1):186–205. Hopkins (2000), Sports Med 30(1):1–15. Sen (1968), J Am Stat Assoc 63:1379–1389.")
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
