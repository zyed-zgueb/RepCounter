import Charts
import SwiftUI
import TipKit

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
        case .light, .deload, .reprise, .comeback: return Intensity.calm
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
        case .reprise(let s): return "! reprise · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .comeback: return "! reprise · une séance"
        case .test: return "◆ test · série max"
        }
    }

    /// Sans le repos : « 29 · 25 · 22 », « ◆ test · série max ».
    var short: String {
        switch self {
        case .session(let s): return s.label
        case .light(let s): return "! léger · \(s.label)"
        case .deload(let s): return "allégée · \(s.label)"
        case .reprise(let s): return "! reprise · \(s.label)"
        case .comeback: return "! reprise"
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
        case .reprise: return "R"
        }
    }

    var name: String {
        switch kind {
        case .progression(let index, let redo): return "Progr. \(index + 1)\(redo ? " bis" : "")"
        case .deload: return "Allégée"
        case .reprise: return "Reprise"
        }
    }

    var intensity: Double { kind == .deload || kind == .reprise ? Intensity.calm : Intensity.work }

    /// Semaine refaite après un décrochage (alerte : « ! »).
    var isRedo: Bool {
        if case .progression(_, let redo) = kind { return redo }
        return false
    }
}

extension TrainingPlan {
    /// La semaine en une ligne : « 2/4 · prochaine jeu. », « semaine faite 4/4 · prochaine lun. »,
    /// « séance en plus · prochaine jeu. » (une séance faite aujourd'hui, un jour non prévu).
    var weekLine: String? {
        let nextText = next.map { "prochaine \(Format.shortWeekday($0))" }
        guard !days.isEmpty else { return nextText }
        let done = days.filter { $0.sessions > 0 }.count
        let extraToday = days.contains { $0.isToday && $0.sessions > 0 && !$0.planned }
        let head: String
        if extraToday {
            head = "séance en plus"
        } else if done >= perWeek {
            head = "semaine faite \(done)/\(perWeek)"
        } else {
            head = "\(done)/\(perWeek)"
        }
        return [head, nextText].compactMap { $0 }.joined(separator: " · ")
    }

    /// L'intensité de la semaine en cours (jour de test : maximale).
    var weekIntensity: Double {
        if today == .test { return Intensity.max }
        return currentWeek?.intensity ?? Intensity.work
    }
}

/// La ligne du jour sous le cadran, en veille : « aujourd'hui · 29 · 25 · 22 · repos 1:30 »,
/// « fait ✓ · 2/4 · prochaine ven. », ou « repos · 2/4 · prochaine ven. ». Démarrer reste possible.
struct TodayLine: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        // En grandes tailles de texte : la version courte (sans le repos), puis sur deux lignes,
        // plutôt qu'un texte tronqué ou rétréci
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { lead(plan.today.label); trail }
            HStack(spacing: 4) { lead(plan.today.short); trail }
            VStack(spacing: 2) { lead(plan.today.label); trail }
        }
        .font(theme.font(12))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    /// « aujourd'hui · 29 · 25 · 22 », « fait ✓ » ou « repos ».
    @ViewBuilder
    private func lead(_ label: String) -> some View {
        switch plan.status {
        case .due:
            HStack(spacing: 4) {
                Text("aujourd'hui ·").foregroundStyle(theme.dim)
                Text(symbols: label).fontWeight(.bold).foregroundStyle(plan.today.color(theme))
            }
        case .done:
            Text(symbols: "fait ✓").fontWeight(.bold).foregroundStyle(theme.ok)
        case .rest:
            Text("repos").fontWeight(.bold).foregroundStyle(theme.dim)
        }
    }

    /// La suite de la semaine, comme sous la rangée des jours du Coaching : « · 2/4 · prochaine
    /// jeu. », « · semaine faite 4/4 · prochaine lun. », « · séance en plus · prochaine jeu. ».
    @ViewBuilder
    private var trail: some View {
        if plan.status != .due, let line = plan.weekLine {
            Text("· " + line).foregroundStyle(theme.text)
        }
    }
}

/// La ligne sous le cadran un jour de test : « ◆ série max · dernier test 33 », « ◆ test 1 / 2 »
/// au bloc 1, « ! ◆ test à faire » en retard (skill reps-ux § 5 : l'alerte porte « ! »).
struct TestDayLine: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        Text(symbols: text)
            .font(theme.font(12, .bold))
            .foregroundStyle(plan.testOverdue ? theme.text : theme.max)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: String {
        if let step = plan.testStep { return "◆ test \(step.number) / \(step.of) · série max" }
        let last = plan.tests.last.map { " · dernier test \($0.value)" } ?? ""
        return plan.testOverdue ? "! ◆ test à faire" + last : "◆ série max" + last
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
            // Sans cible (série au-delà du prévu) : ni ✓ ni vert
            let reached = planned.map { all[index] >= $0 } ?? false
            Text(symbols: "\(all[index])\(reached ? " ✓" : "")").foregroundStyle(reached ? theme.ok : theme.text)
        } else if index == all.count {
            // La série en cours (ou la prochaine) : sa cible, réajustée
            Text(symbols: "\(current.map { "\($0)/" } ?? "")\(next ?? planned ?? 0) ←").foregroundStyle(theme.primary)
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
    /// Largeur réelle de « ▲ tu es ici » (elle grandit avec le texte) : la marque reste dans la frise.
    @State private var hereWidth: CGFloat = 60
    @ScaledMetric(relativeTo: .caption2) private var hereHeight: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(plan.weeks.enumerated()), id: \.offset) { _, week in
                    segment(week)
                }
                VStack(spacing: 4) {
                    Text(symbols: "◆").font(theme.font(8.5, .bold)).foregroundStyle(theme.max)
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
                    Text(symbols: "▲ tu es ici")
                        .font(theme.font(9))
                        .foregroundStyle(theme.text)
                        .fixedSize()
                        .background(GeometryReader { label in
                            Color.clear.preference(key: HereWidthKey.self, value: label.size.width)
                        })
                        .offset(x: min(max(herePosition * geometry.size.width - 6, 0), max(geometry.size.width - hereWidth, 0)))
                }
                .frame(height: hereHeight)
                .onPreferenceChange(HereWidthKey.self) { hereWidth = $0 }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bloc \(plan.block), \(plan.currentWeek?.name ?? "test"), test le \(Format.shortDate(plan.testDate))")
        .accessibilityChartDescriptor(SeriesChartDescriptor(
            title: "Bloc \(plan.block)", summary: "Test le \(Format.shortDate(plan.testDate))",
            xTitle: "Semaine", yTitle: "Répétitions faites",
            points: plan.weeks.enumerated().map { (label: "\($0.offset + 1) \($0.element.short)", value: Double($0.element.doneReps)) }))
    }

    private func segment(_ week: TrainingPlan.Week) -> some View {
        let color = theme.intensity(week.intensity)
        let fill: Double = week.isPast ? 1 : (week.isCurrent ? dayShare(week) : 0)
        return VStack(spacing: 4) {
            Text(symbols: (week.isRedo ? "! " : "") + week.short)
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
                        Text(symbols: "!").font(theme.font(8, .bold)).foregroundStyle(theme.text).frame(width: 6, height: 6)
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
                context.draw(Text(symbols: mark).font(theme.font(7)).foregroundStyle(theme.dim), at: point)
            }
            let a = angle(min(max(level, 0), 1)).radians
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * (radius - 4), y: center.y + CGFloat(sin(a)) * (radius - 4)))
            context.stroke(needle, with: .color(theme.text), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: center.x - 3.5, y: center.y - 3.5, width: 7, height: 7)), with: .color(theme.text))
        }
        .accessibilityLabel("Intensité de la semaine : \(Intensity.word(level))")
        .accessibilityChartDescriptor(SeriesChartDescriptor(
            title: "Intensité de la semaine", summary: Intensity.word(level),
            xTitle: "Semaine", yTitle: "Intensité",
            points: [(label: "cette semaine", value: level * 100)], unit: " %", range: 0...100))
    }
}

/// La largeur mesurée de « ▲ tu es ici ».
private struct HereWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 60
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Cartes du Coaching

/// Le bloc en cours : « B2 · P3 », l'intensité en mots et en jauge, la date du test, la frise,
/// la semaine jour par jour, et le prévu face au fait en barres.
struct BlockCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let plan: TrainingPlan
    let exercise: Exercise
    /// Un jour de séance a été déplacé.
    let onDaysChanged: () -> Void

    var body: some View {
        let level = plan.weekIntensity
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(symbol: "square.stack.3d.up.fill", title: "Bloc")
            TipView(BlockTip())
            // En tailles d'accessibilité, le texte et la jauge l'un sous l'autre
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(alignment: .center))
            layout {
                VStack(alignment: .leading, spacing: 4) {
                    Text(symbols: "B\(plan.block) · \(plan.today == .test ? "◆" : (plan.currentWeek?.short ?? "◆"))")
                        .font(theme.font(15, .bold))
                        .foregroundStyle(theme.text)
                    MonitorLabel("intensité \(Intensity.word(level))", color: theme.intensity(level))
                    if plan.testOverdue {
                        // Le test est à faire : le bloc suivant attend
                        MonitorLabel("! ◆ test à faire · bloc \(plan.block + 1) en attente", color: theme.text)
                    } else {
                        MonitorLabel(plan.today == .test ? "◆ aujourd'hui" : "◆ \(Format.shortDate(plan.testDate))")
                    }
                    if let redo = plan.weeks.last(where: { $0.redoReason != nil }), plan.currentWeek?.kind != .deload {
                        MonitorLabel("! \(redo.short) refaite · \(redo.redoReason ?? "")", color: theme.text)
                    }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                IntensityGauge(level: level)
                    .frame(width: 112, height: 64)
            }
            BlockFrise(plan: plan)
            if !plan.days.isEmpty {
                WeekDays(plan: plan, exercise: exercise, onChange: onDaysChanged)
            }
            WeekBars(plan: plan)
        }
        .coachingCard(theme)
    }
}

/// La semaine en cours, L M M J V S D, en lecture seule : le placement est un choix de l'app ;
/// « ✎ jours » ouvre la feuille qui le change (autant de jours que de séances par semaine). Une
/// ligne dessous dit la suite (« 2/4 · prochaine jeu. »).
struct WeekDays: View {
    @Environment(\.theme) private var theme
    @State private var editing = false
    /// « Jours réinitialisés », une seule fois après une remise aux jours proposés.
    @State private var showsResetNotice = false
    let plan: TrainingPlan
    let exercise: Exercise
    let onChange: () -> Void
    static let letters = ["L", "M", "M", "J", "V", "S", "D"]
    /// Pour VoiceOver : « M » se lirait pareil pour mardi et mercredi.
    static let names = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]

    var body: some View {
        let spaced = plan.days.filter { $0.sessions >= 2 }
        let color = theme.intensity(plan.weekIntensity)
        VStack(alignment: .leading, spacing: 6) {
            // La rangée affiche seulement : les jours se changent par « ✎ jours »
            HStack(spacing: 4) {
                ForEach(Array(plan.days.enumerated()), id: \.offset) { index, day in
                    cell(index, day, color: color)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(accessibility(index, day))
                }
                Button { editing = true } label: {
                    Label("jours", systemImage: "pencil")
                        .font(theme.font(13, .semibold))
                        .foregroundStyle(theme.primary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Modifier les jours d'entraînement")
            }
            if let line = plan.weekLine {
                Text(symbols: line)
                    .font(theme.font(12))
                    .foregroundStyle(theme.text)
            }
            if showsResetNotice {
                Text("Jours réinitialisés : ils ne correspondaient plus à ton plan.")
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let day = spaced.last {
                MonitorLabel("séries espacées · \(Format.weekdayOrDate(day.date))")
            }
        }
        .onAppear {
            if Schedule.takeResetNotice(exercise) { showsResetNotice = true }
        }
        .sheet(isPresented: $editing) {
            DaysEditor(exercise: exercise, perWeek: plan.perWeek,
                       chosen: Set(plan.days.enumerated().filter { $0.element.planned }.map { $0.offset + 1 })) {
                onChange()
            }
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
        }
    }

    /// Prévu : cercle épais de la couleur d'intensité de la semaine ; repos : la lettre seule ;
    /// fait : cercle plein (plus petit un jour non prévu) ; manqué : « ! » ; aujourd'hui souligné.
    private func cell(_ index: Int, _ day: TrainingPlan.Day, color: Color) -> some View {
        let done = day.sessions > 0
        return VStack(spacing: 3) {
            Text(Self.letters[index])
                .font(theme.font(10, day.isToday ? .bold : .regular))
                .foregroundStyle(day.planned || done ? theme.text : theme.dim)
            ZStack {
                if day.missed {
                    Text(symbols: "!").font(theme.font(12, .bold)).foregroundStyle(theme.text)
                } else if done && day.planned {
                    Circle().fill(color)
                } else if done {
                    Circle().fill(color).frame(width: 8, height: 8)
                } else if day.planned {
                    Circle().stroke(color, lineWidth: 2)
                }
            }
            .frame(width: 14, height: 14)
            Rectangle()
                .fill(day.isToday ? theme.text : .clear)
                .frame(width: 10, height: 2)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    /// « lundi, prévu, fait », « mardi, repos », « jeudi, prévu, manqué, aujourd'hui ».
    private func accessibility(_ index: Int, _ day: TrainingPlan.Day) -> String {
        var parts = [Self.names[index], day.planned ? "prévu" : "repos"]
        if day.sessions > 0 { parts.append(day.planned ? "fait" : "séance en plus") }
        if day.missed { parts.append("manqué") }
        if day.isToday { parts.append("aujourd'hui") }
        return parts.joined(separator: ", ")
    }
}

/// « Jours d'entraînement » : les 7 jours cochables ; « Enregistrer » seulement quand le nombre de
/// jours choisis est celui des séances par semaine du plan (on ne change pas ce nombre ici).
private struct DaysEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let perWeek: Int
    @State var chosen: Set<Int>
    let onSave: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(1...7, id: \.self) { day in
                    Button {
                        if chosen.contains(day) { chosen.remove(day) } else { chosen.insert(day) }
                    } label: {
                        HStack {
                            Text(WeekDays.names[day - 1].capitalized)
                                .foregroundStyle(theme.text)
                            Spacer()
                            if chosen.contains(day) {
                                Image(systemName: "checkmark")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(theme.primary)
                            }
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityAddTraits(chosen.contains(day) ? .isSelected : [])
                }
            } header: {
                Text("\(perWeek) séances / semaine · \(chosen.count) choisie\(chosen.count > 1 ? "s" : "")")
            } footer: {
                if chosen.count != perWeek {
                    Text("Choisis \(perWeek) jours.")
                }
            }
            Section {
                Button("Revenir aux jours proposés") {
                    Schedule.save(nil, for: exercise)
                    onSave()
                    dismiss()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: chosen)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    Schedule.save(Array(chosen), for: exercise)
                    onSave()
                    dismiss()
                }
                .disabled(chosen.count != perWeek)
            }
        }
        .navigationTitle("Jours d'entraînement")
        .navigationBarTitleDisplayMode(.inline)
        .embeddedInNavigation()
        .presentationDetents([.large])
    }
}

private extension View {
    /// La feuille a sa propre barre (Annuler, Enregistrer).
    func embeddedInNavigation() -> some View { NavigationStack { self } }
}

/// Prévu face au fait (Swift Charts), une barre par semaine du bloc : barre pâle = prévu (couleur
/// de l'intensité), pleine = fait, ✓ si atteint, ← pour la semaine en cours.
struct WeekBars: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 100
    let plan: TrainingPlan

    private struct Bar: Identifiable {
        let id: Int
        let week: TrainingPlan.Week
        var reached: Bool { week.doneReps >= week.plannedReps && week.plannedReps > 0 }
        /// ✓ atteint, ← en cours, ! manqué, ○ à venir.
        var mark: String { reached ? "✓" : (week.isCurrent ? "←" : (week.isPast ? "!" : "○")) }
        /// Nom unique sur l'axe (« P2 bis » peut suivre « P2 »).
        var name: String { "\(id + 1) \(week.short)" }
    }

    var body: some View {
        let bars = plan.weeks.enumerated().map { Bar(id: $0.offset, week: $0.element) }
        Chart(bars) { bar in
            let color = theme.intensity(bar.week.intensity)
            BarMark(x: .value("Semaine", bar.name), yStart: .value("Prévu", 0.0), yEnd: .value("Prévu", Double(bar.week.plannedReps)),
                    width: .ratio(0.7))
                .foregroundStyle(color.opacity(bar.week.intensity == Intensity.calm ? 0.18 : 0.28))
                .cornerRadius(3)
                .annotation(position: .top) {
                    if bar.week.doneReps <= bar.week.plannedReps {
                        Text(symbols: bar.mark)
                            .font(theme.font(11, .bold))
                            .foregroundStyle(bar.reached ? theme.ok : theme.text)
                    }
                }
            if bar.week.doneReps > 0 {
                BarMark(x: .value("Semaine", bar.name), yStart: .value("Fait", 0.0), yEnd: .value("Fait", Double(bar.week.doneReps)),
                        width: .ratio(0.45))
                    .foregroundStyle((bar.reached ? theme.ok : color).opacity(bar.week.isCurrent ? 0.95 : 0.8))
                    .cornerRadius(2)
                    .annotation(position: .top) {
                        if bar.week.doneReps > bar.week.plannedReps {
                            Text(symbols: bar.mark)
                                .font(theme.font(11, .bold))
                                .foregroundStyle(bar.reached ? theme.ok : theme.text)
                        }
                    }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self), let bar = bars.first(where: { $0.name == name }) {
                        Text(bar.week.short)
                            .fontWeight(bar.week.isCurrent ? .bold : .regular)
                            .foregroundStyle(bar.week.isCurrent ? theme.text : theme.dim)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: height)
        .accessibilityElement(children: .contain)
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
            CardHeader(symbol: "chart.line.uptrend.xyaxis", title: "Chemin")
            PathChart(plan: plan, exercise: exercise, sessions: sessions)
            // Une légende ne montre que ce qui est dessiné (skill reps-ux, § 9)
            let legend = self.legend
            Text(symbols: legend.map(\.symbol).joined(separator: " · "))
                .font(theme.font(10))
                .foregroundStyle(theme.dim)
                .accessibilityLabel("Légende : " + legend.map(\.spoken).joined(separator: " ; "))
            if plan.hasTest {
                HStack {
                    MonitorLabel(plan.testOverdue ? "! ◆ test à faire" : (plan.today == .test ? "◆ test aujourd'hui" : "◆ prochain test"))
                    Spacer()
                    MonitorLabel(Format.shortDate(plan.testDate))
                }
            }
            if let verdict = settledVerdict {
                HStack {
                    Text(symbols: verdictSymbol(verdict))
                        .font(theme.font(13, .bold))
                        .foregroundStyle(theme.text)
                    Spacer()
                    if let projection = plan.projection, let goal = plan.goal {
                        MonitorLabel("⌖ \(goal.target) vers le \(Format.shortDate(projection))")
                    }
                }
            }
        }
        .coachingCard(theme)
    }

    /// Les entrées de la légende, seulement pour ce que le chemin dessine.
    private var legend: [(symbol: String, spoken: String)] {
        var items: [(symbol: String, spoken: String)] = []
        if plan.goal != nil { items.append(("● départ", "rond plein : départ")) }
        // Les points dessinés : les séances depuis le début, hors séances de test
        let start = plan.goal?.created ?? plan.anchor
        let tests = Set(plan.tests.map(\.date))
        if sessions.contains(where: { $0.start >= start && !tests.contains($0.start) && !$0.isTest && $0.bestSet > 0 }) {
            items.append(("• séances", "petits points : séances"))
        }
        if plan.tests.contains(where: { $0.date >= start }) || plan.hasTest { items.append(("◆ test", "losange : test")) }
        if plan.shiftedGoalDate != nil { items.append(("┄ attendu", "pointillés : attendu")) }
        return items
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

/// Le chemin (Swift Charts), sur un axe de dates : les blocs en repères (un filet, B1…Bn), la
/// ligne d'arrivée ⚑, l'attendu en pointillés, la projection, la meilleure série de chaque séance,
/// les tests (◆ pleins et chiffrés, creux à venir), le départ ● et aujourd'hui ▼. Un doigt posé
/// donne la séance la plus proche.
private struct PathChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 170
    let plan: TrainingPlan
    let exercise: Exercise
    let sessions: [SessionRecord]
    @State private var selected: Date?

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let value: Int
    }

    /// Un sommet d'une ligne (attendu, projection) : identifiant propre, même si deux dates
    /// coïncident.
    private struct LinePoint: Identifiable {
        let id: Int
        let date: Date
        let value: Int
    }

    /// La meilleure série de chaque séance depuis le début du plan, hors séances de test.
    private var points: [Point] {
        let start = plan.goal?.created ?? plan.anchor
        let tests = Set(plan.tests.map(\.date))
        return sessions
            .filter { $0.start >= start && !tests.contains($0.start) && !$0.isTest && $0.bestSet > 0 }
            .enumerated()
            .map { Point(id: $0.offset, date: $0.element.start, value: $0.element.bestSet) }
    }

    var body: some View {
        let points = self.points
        let start = plan.goal?.created ?? plan.anchor
        // L'axe englobe aujourd'hui, les séances, les tests et la date de l'objectif (même dépassée)
        let now = Date()
        let latest = ([now, plan.testDate] + points.map(\.date) + plan.tests.map(\.date) + [plan.shiftedGoalDate].compactMap { $0 }).max() ?? now
        let end = max(latest.addingTimeInterval(7 * 86_400), start.addingTimeInterval(16 * 7 * 86_400))
        // Les blocs : ceux faits ou en cours, puis ceux à venir jusqu'à la fin de l'axe
        var starts = plan.blocks.map(\.start)
        var next = (plan.blocks.last?.test ?? start).addingTimeInterval(7 * 86_400)
        // Reprise après une longue absence : pas de bloc ni de test à venir sur le chemin
        while plan.hasTest, next < end {
            starts.append(next)
            next = next.addingTimeInterval(5 * 7 * 86_400)
        }
        // Rien avant le début de l'axe (blocs ou tests antérieurs au départ)
        let blockStarts = starts.filter { $0 >= start && $0 < end }
        // Tests pas encore faits : celui du bloc en cours (s'il n'est pas fait), puis ceux des
        // blocs à venir ; les tests manqués restent à leur date, marqués « ! »
        let currentTestDone = plan.tests.contains { $0.block == plan.block }
        let currentTest = plan.hasTest && !currentTestDone ? [plan.testDate] : []
        let upcoming = (currentTest + starts.dropFirst(plan.blocks.count).map { $0.addingTimeInterval(4 * 7 * 86_400) })
            .filter { $0 >= start && $0 <= end }
        let alerts = Set(plan.missedTests + (plan.testOverdue ? [plan.testDate] : []))
        let missed = plan.missedTests.filter { $0 >= start && $0 <= end }
        let lastMax = plan.tests.last?.value ?? points.last?.value ?? plan.goal?.start
        let fallback = Double(lastMax ?? 0)
        let upcomingLevels = (upcoming + missed).map { plan.expected(at: $0) ?? fallback }
        // L'échelle englobe le départ, l'objectif, les tests (faits et à venir) et les séances
        var values = plan.tests.map { Double($0.value) } + points.map { Double($0.value) } + upcomingLevels
        if let goal = plan.goal { values += [Double(goal.start), Double(goal.target)] }
        let low = (values.min() ?? 0) - 2, high = (values.max() ?? 10) + 2
        let chosen = selected.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) } }

        return VStack(alignment: .leading, spacing: 4) {
            MonitorLabel("\(exercise.shortTitle.lowercased()) d'affilée")
            Chart {
                blockMarks(blockStarts)
                goalMarks(end: end)
                sessionMarks(points, upcoming: upcoming + missed, alerts: alerts, level: { plan.expected(at: $0) ?? fallback })
                testMarks(from: start)
                todayMarks(chosen)
            }
            .chartXScale(domain: start...end)
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
            }
            .chartXSelection(value: $selected)
            .frame(height: height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibility(points))
        }
    }

    @ChartContentBuilder
    private func blockMarks(_ starts: [Date]) -> some ChartContent {
        ForEach(Array(starts.enumerated()), id: \.offset) { index, blockStart in
            RuleMark(x: .value("Date", blockStart))
                .foregroundStyle(theme.grid)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .bottom, alignment: .leading) {
                    Text("B\(index + 1)")
                        .font(theme.font(11, index == plan.blocks.count - 1 ? .bold : .regular))
                        .foregroundStyle(index == plan.blocks.count - 1 ? theme.text : theme.dim)
                }
        }
    }

    /// La ligne d'arrivée ⚑, l'attendu (départ → objectif à la date choisie), la projection.
    @ChartContentBuilder
    private func goalMarks(end: Date) -> some ChartContent {
        if let goal = plan.goal {
            RuleMark(y: .value("Répétitions", Double(goal.target)))
                .foregroundStyle(theme.ok)
                .annotation(position: .top, alignment: .trailing) {
                    Text(symbols: "⚑ \(goal.target)")
                        .font(theme.font(11, .bold))
                        .foregroundStyle(theme.ok)
                }
            if let goalDate = plan.shiftedGoalDate {
                ForEach([LinePoint(id: 0, date: goal.created, value: goal.start),
                         LinePoint(id: 1, date: goalDate, value: goal.target)]) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)), series: .value("Ligne", "attendu"))
                        .foregroundStyle(theme.dim)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            if let projection = plan.projection, let last = plan.tests.last {
                ForEach([LinePoint(id: 0, date: last.date, value: last.value),
                         LinePoint(id: 1, date: min(projection, end), value: goal.target)]) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)), series: .value("Ligne", "projection"))
                        .foregroundStyle(theme.primary)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
                }
            }
        }
    }

    /// La meilleure série de chaque séance, et les tests à venir (◆ creux).
    @ChartContentBuilder
    private func sessionMarks(_ points: [Point], upcoming: [Date], alerts: Set<Date>,
                              level: @escaping (Date) -> Double) -> some ChartContent {
        ForEach(points) { point in
            PointMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)))
                .foregroundStyle(theme.primary.opacity(0.8))
                .symbolSize(14)
        }
        ForEach(upcoming, id: \.self) { test in
            PointMark(x: .value("Date", test), y: .value("Répétitions", level(test)))
                .symbol {
                    Image(systemName: "diamond")
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                }
                .annotation(position: .top, spacing: 0) {
                    // Test pas fait (manqué, ou en retard) : « ! »
                    if alerts.contains(test) {
                        Text(symbols: "!")
                            .font(theme.font(10, .bold))
                            .foregroundStyle(theme.text)
                    }
                }
        }
    }

    /// Les tests faits depuis le début de l'axe (◆ pleins, chiffrés) et le départ ●.
    @ChartContentBuilder
    private func testMarks(from start: Date) -> some ChartContent {
        ForEach(plan.tests.filter { $0.date >= start }, id: \.date) { test in
            PointMark(x: .value("Date", test.date), y: .value("Répétitions", Double(test.value)))
                .symbol {
                    Image(systemName: "diamond.fill")
                        .font(theme.font(12))
                        .foregroundStyle(theme.text)
                }
                .annotation(position: .topTrailing, spacing: 0) {
                    Text("\(test.value)")
                        .font(theme.font(11, .bold))
                        .foregroundStyle(theme.text)
                }
        }
        if let goal = plan.goal {
            PointMark(x: .value("Date", goal.created), y: .value("Répétitions", Double(goal.start)))
                .foregroundStyle(theme.text)
                .symbolSize(60)
        }
    }

    /// Aujourd'hui ▼, et la séance choisie au doigt.
    @ChartContentBuilder
    private func todayMarks(_ chosen: Point?) -> some ChartContent {
        RuleMark(x: .value("Date", Date()))
            .foregroundStyle(theme.primary)
            .lineStyle(StrokeStyle(lineWidth: 1.2))
            .annotation(position: .top, spacing: 0) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(theme.font(9))
                    .foregroundStyle(theme.primary)
            }
        if let chosen {
            RuleMark(x: .value("Date", chosen.date))
                .foregroundStyle(theme.dim.opacity(0.5))
                .annotation(position: .top, spacing: 2, overflowResolution: ChartKit.overflow) {
                    SelectionLabel(title: "\(chosen.value)", detail: Format.shortDate(chosen.date))
                }
        }
    }

    /// « Pompes d'affilée : départ 30, meilleure séance récente 32, dernier test 33, objectif 40 le 12 févr. »
    private func accessibility(_ points: [Point]) -> String {
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

extension View {
    /// Le cadre commun des cartes du Coaching.
    func coachingCard(_ theme: AppTheme) -> some View {
        padding(14)
            .cardBackground(theme)
    }
}

// MARK: - (i)

/// (i) du plan : le bloc, ce qui est sourcé, ce qui est un choix de l'app, ce qui est provisoire.
struct PlanInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Le bloc",
                            "3 semaines de progression, 1 semaine allégée, puis un test : une série max, ton nouveau niveau. Le bloc suivant repart de là. Le rythme 3 + 1 est un choix de l'app : l'ACSM ne trouve pas une programmation par blocs supérieure à une autre, pourvu que la charge progresse.")
                    section("Avec ou sans objectif",
                            "Le plan démarre dès que ta séance habituelle se calcule, objectif ou non : la séance du jour, le bloc et l'état s'affichent. L'objectif ajoute le chemin, la ligne attendue et le verdict. La proposition d'objectif, environ 20 % au-dessus de ton niveau (ta meilleure série des 4 dernières semaines, ou la dernière connue), est un choix de l'app : un point de départ, à modifier. Objectif atteint : la même règle propose le suivant. « Autre exercice » mêle des mouvements : pas de plan ni d'objectif.")
                    section("La séance prévue",
                            "Au moins 2 séances par semaine et 3 séries par séance, enchaînées avec le repos indiqué (ACSM 2026 : « at least twice weekly », « 2–3 sets/session »). La règle de l'ACSM porte sur l'effort : chaque série s'arrête près de l'échec, à 2 ou 3 répétitions en réserve ; aller jusqu'à l'échec n'apporte rien de plus. La série 1 vise ton max moins 3. Avec la fatigue, le nombre baisse d'une série à l'autre : les séries 2 et 3 suivent ta baisse habituelle (mesurée sur tes séances des 4 dernières semaines faites avec un repos proche) ; sans elle, chaque série vise 80 % de la précédente. Une série sous sa cible réajuste aussitôt les suivantes, sans rattrapage. Ces règles, la formule « max − 3 » et les 80 % (une valeur prudente) sont des choix de l'app : l'ACSM précise que la cible exacte n'est pas établie. Le max est celui du dernier test ; au premier bloc, ta meilleure série des 4 dernières semaines.")
                    section("Le repos",
                            "Le tien : ton repos habituel pour l'exercice, arrondi à 15 s. La durée du repos ne change pas les gains de force (ACSM 2026). Des séries faites séparément dans la journée comptent dans la séance du jour, sans pénalité (« séries espacées ») ; la suivante repart de la cible de la série 1. L'ACSM ne les étudie pas : le plan ne les prévoit pas.")
                    section("Les jours",
                            "Les séances sont espacées dans la semaine : 2 séances, lundi et jeudi ; 3, lundi, mercredi et vendredi. Touche un jour dans le Coaching pour le déplacer. Une séance faite un autre jour compte, et remplace la prochaine prévue. L'ACSM ne fixe pas l'espacement : ce placement est un choix de l'app.")
                    section("Le test",
                            "Sourcé : le test recale ton niveau, et les cibles du bloc suivant en partent (ACSM 2026, p. 863 : « regular strength testing »). Le reste est un choix de l'app. Le jour de test est le premier jour de séance après la semaine allégée ; c'est toi qui le lances (« ◆ Lancer le test »), et seules les séries faites en mode test comptent. Un échauffement facile est conseillé, jamais compté : environ un tiers de ton dernier max, puis 2 minutes de repos. Le résultat est ta meilleure série en mode test ; une 2e tentative est possible après au moins 3 minutes, le meilleur des deux compte. La série s'arrête quand le compteur détecte la fin. Au bloc 1 (et à un nouveau bloc 1 après plus de 28 jours sans séance), 2 tests sur 2 jours de la première semaine, et le meilleur sert de départ. Un test lancé en semaine allégée compte et clôt le bloc ; lancé en semaine de progression, il ne clôt pas le bloc mais relève le max s'il le dépasse. Plusieurs tests : le meilleur, du premier test au début du bloc suivant. Lancé puis abandonné sans série : il reste à faire. Pas lancé : « à faire » à chaque jour de séance suivant, avec une séance allégée en attendant (elle compte comme séance, pas comme test) ; 7 jours après le jour prévu, le bloc suivant repart de ton dernier max, sans recalage. Plus de 7 jours sans séance : une semaine de reprise avant le test. Entre deux tests, un écart de moins d'environ 10 % se lit « dans la variation » (seuil provisoire ; principe : Hopkins). Entre deux tests, une série au moins 3 au-dessus de sa cible relève le max, et les cibles suivent dès la séance suivante. Pas de mode test pour « Autre exercice ».")
                    section("Après une longue absence",
                            "Après plus de 28 jours sans séance, le plan ne propose qu'une séance de reprise, libre : elle ouvre un nouveau bloc 1, ancré sur elle. Ce bloc commence, comme le tout premier, par 2 tests dans la première semaine ; sans ces tests, la semaine 1 calibre (les cibles suivent chaque séance), puis les cibles restent fixes jusqu'au test, sauf si une série relève le max. Le seuil de 28 jours et ce calibrage sont des choix de l'app.")
                    section("La progression",
                            "Par le test : ton nouveau max recale la cible du bloc suivant (l'ACSM recommande des tests réguliers). Entre deux tests, la cible ne monte pas d'elle-même : aucune hausse d'une semaine à l'autre, l'article n'en chiffre aucune. Mais une série faite au moins 3 au-dessus de sa cible relève le max (du dépassement), et les cibles suivent dès la séance suivante (choix de l'app).")
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
        .sheetNavigation("Le plan", display: .large)
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
