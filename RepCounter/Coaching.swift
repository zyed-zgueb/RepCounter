import SwiftData
import SwiftUI

// MARK: - Objectif

/// L'objectif d'un exercice, saisi par l'utilisateur : un nombre de répétitions d'affilée, avec
/// une date facultative. Le départ est la meilleure série récente au moment où il est fixé.
struct Goal: Codable, Equatable {
    var target: Int
    var date: Date?
    var start: Int
    var created = Date()

    private static func key(_ exercise: Exercise) -> String { "coaching.goal.\(exercise.rawValue)" }

    static func load(_ exercise: Exercise) -> Goal? {
        guard let data = UserDefaults.standard.data(forKey: key(exercise)) else { return nil }
        return try? JSONDecoder().decode(Goal.self, from: data)
    }

    static func save(_ goal: Goal?, for exercise: Exercise) {
        if let goal, let data = try? JSONEncoder().encode(goal) {
            UserDefaults.standard.set(data, forKey: key(exercise))
            PlanAnchor.setIfNeeded(goal.created, for: exercise)
        } else {
            UserDefaults.standard.removeObject(forKey: key(exercise))
        }
    }
}

extension HistoryStats {
    /// Où l'on en est par rapport à un objectif : la meilleure série des 4 dernières semaines.
    var currentBest: Int { bestSet(lastDays: 28) ?? 0 }
}

// MARK: - Point d'état

/// Le point d'état sans plan (skill reps-ux, § 5), sur l'échelle d'intensité : progression,
/// soutenu ; séance légère conseillée (Forme basse, surcharge…) ou décharge, calme ; rebond
/// (record possible), maximal. Nil : rien à signaler (en cours, analyse suspendue, pause).
extension TrainingPhase {
    func stateColor(_ theme: AppTheme) -> Color? {
        switch kind {
        case .building, .comeback: return theme.work
        case .overreaching, .lowForm, .deloadAdvised, .persistentFatigue, .deload: return theme.calm
        case .rebound: return theme.max
        case .pending, .unreliable, .rest: return nil
        }
    }

    /// Une alerte (« ! »), sans couleur propre : surcharge, Forme basse, fatigue persistante.
    var isAlert: Bool {
        [.overreaching, .lowForm, .deloadAdvised, .persistentFatigue].contains(kind)
    }
}

/// L'icône Coaching (une cible) et son point d'état.
struct CoachingButton: View {
    @Environment(\.theme) private var theme
    let dot: Color?
    let action: () -> Void

    var body: some View {
        IconButton(systemImage: "scope", color: theme.dim, action: action)
            .overlay(alignment: .topTrailing) {
                if let dot {
                    Circle()
                        .fill(dot)
                        .frame(width: 8, height: 8)
                        .shadow(color: dot.opacity(0.8 * min(theme.glow, 1)), radius: 4)
                        .offset(x: 2, y: -2)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("Coaching")
    }
}

/// La bulle qui explique le point d'état, une seule fois, à son premier affichage : l'échelle
/// d'intensité en dégradé, puis ses trois niveaux.
struct StateDotTip: View {
    @Environment(\.theme) private var theme
    static let key = "coaching.dotExplained"
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorLabel("Ton plan, en un point", color: theme.text)
            VStack(spacing: 4) {
                Capsule()
                    .fill(LinearGradient(gradient: theme.intensityGradient, startPoint: .leading, endPoint: .trailing))
                    .frame(height: 8)
                HStack {
                    MonitorLabel("calme")
                    Spacer()
                    MonitorLabel("intense")
                }
            }
            VStack(alignment: .leading, spacing: 9) {
                row(theme.calm, "Calme", "semaine allégée, ou séance légère")
                row(theme.work, "Soutenu", "progression : la séance prévue")
                row(theme.max, "Maximal", "◆ jour de test : une série max")
            }
            Text("Touche la cible : ton plan.")
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
            Button("Compris", action: onDone)
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 40, fontSize: 12))
        }
        .padding(14)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius * 1.5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius * 1.5, style: .continuous).stroke(theme.line, lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 20, y: 10)
    }

    private func row(_ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(color).frame(width: 10, height: 10).padding(.top, 3)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(theme.font(12, .bold)).foregroundStyle(theme.text)
                Text(detail).font(theme.font(11)).foregroundStyle(theme.dim)
            }
        }
    }
}

// MARK: - Vue Coaching

/// Le Coaching (skill reps-ux) : l'avenir et le plan d'un exercice, du plus long terme au plus
/// court. L'objectif en très grand, le chemin jusqu'à lui (un graphique), le bloc en cours
/// (intensité, frise, jours, prévu face au fait), puis l'état (phase, Forme, ressenti).
struct CoachingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SessionRecord.start, order: .reverse) private var sessions: [SessionRecord]
    let exercise: Exercise
    @State private var goal: Goal?
    @State private var editor: GoalEditor.Mode?
    @State private var showsMenu = false
    @State private var showsInfo = false
    @State private var showsBlockSheet = false
    /// Change quand un jour de séance est déplacé ou l'objectif retiré : le plan est recalculé.
    @State private var version = 0

    init(exercise: Exercise) {
        self.exercise = exercise
        _goal = State(initialValue: Goal.load(exercise))
    }

    var body: some View {
        let stats = HistoryStats(sessions: sessions, exercise: exercise)
        let _ = version
        let plan = stats.plan(all: sessions)
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Text("COACHING")
                        .font(theme.font(16, .bold))
                        .tracking(3)
                        .foregroundStyle(theme.text)
                    Spacer()
                    MonitorLabel(exercise.shortTitle)
                    IconButton(systemImage: "info.circle", color: theme.dim) { showsInfo = true }
                    IconButton(systemImage: "xmark") { dismiss() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                VerticalScroll {
                    VStack(spacing: 14) {
                        // Où je vais : l'objectif, le chemin, le bloc
                        GoalHeader(goal: goal, current: stats.currentBest,
                                   onEdit: { editor = goal == nil ? .new : .target },
                                   onMenu: { showsMenu = true })
                        if let plan {
                            PathCard(plan: plan)
                            BlockCard(plan: plan, exercise: exercise) { version += 1 }
                        } else if goal != nil {
                            Text("plan · après ta première séance")
                                .font(theme.font(12))
                                .foregroundStyle(theme.dim)
                                .coachingCard(theme)
                        }
                        // Comment je suis
                        if exercise != .auto {
                            NavigationLink(value: CoachingPage.state) {
                                StateCard(stats: stats, all: sessions)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: CoachingPage.self) { page in
                switch page {
                case .state:
                    HistoryDetailView(title: "État") {
                        PhasePanel(stats: stats, all: sessions)
                        FormPanel(stats: stats)
                    }
                }
            }
        }
        .tint(theme.primary)
        .onAppear {
            // Le bloc s'explique une fois, à la première ouverture avec un plan
            if plan != nil, !UserDefaults.standard.bool(forKey: BlockSheet.key) { showsBlockSheet = true }
        }
        .sheet(isPresented: $showsBlockSheet) {
            if let plan {
                BlockSheet(plan: plan)
                    .environment(\.theme, theme)
                    .preferredColorScheme(theme.colorScheme)
            }
        }
        .sheet(isPresented: $showsInfo) {
            PlanInfoView()
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
        .sheet(isPresented: $showsMenu) {
            if let goal {
                GoalMenu(goal: goal,
                         onEditTarget: { editor = .target },
                         onEditDate: { editor = .date },
                         onRemove: {
                             Goal.save(nil, for: exercise)
                             self.goal = nil
                             version += 1
                         })
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
            }
        }
        .sheet(item: $editor) { mode in
            GoalEditor(mode: mode, exercise: exercise, goal: goal, current: stats.currentBest) { newGoal in
                Goal.save(newGoal, for: exercise)
                goal = newGoal
                version += 1
            }
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
        }
    }
}

enum CoachingPage: Hashable {
    case state
}

/// L'en-tête : l'objectif, le chiffre le plus visible de l'écran (vert comme la ligne d'arrivée),
/// « ⌖ pour le 12 fév. » au-dessus ; à droite, « auj. 33 », « reste 7 », ✎ et ⋯.
private struct GoalHeader: View {
    @Environment(\.theme) private var theme
    let goal: Goal?
    let current: Int
    let onEdit: () -> Void
    let onMenu: () -> Void

    var body: some View {
        if let goal {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    MonitorLabel(goal.date.map { "⌖ pour le \(Format.shortDate($0))" } ?? "⌖ objectif")
                    Text("\(goal.target)")
                        .font(theme.font(64, .bold))
                        .foregroundStyle(theme.ok)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 10) {
                    HStack(spacing: 6) {
                        symbolButton("✎", label: "Modifier l'objectif", action: onEdit)
                        symbolButton("⋯", label: "Menu de l'objectif", action: onMenu)
                    }
                    figure("auj.", current)
                    figure("reste", max(goal.target - current, 0))
                }
                .padding(.bottom, 6)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Objectif \(goal.target), aujourd'hui \(current)")
        } else {
            VStack(alignment: .leading, spacing: 10) {
                MonitorLabel("⌖ objectif")
                Button("⌖ Fixer un objectif", action: onEdit)
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: false, height: 44, fontSize: 12))
            }
            .coachingCard(theme)
        }
    }

    private func figure(_ label: String, _ value: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            MonitorLabel(label)
            Text("\(value)")
                .font(theme.font(15, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
        }
    }

    private func symbolButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(symbol)
                .font(theme.font(17, .bold))
                .foregroundStyle(theme.dim)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// ⋯ : modifier l'objectif, la date, ou le retirer, chaque action avec sa conséquence. Retirer
/// demande une confirmation dans la même feuille.
private struct GoalMenu: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let goal: Goal
    let onEditTarget: () -> Void
    let onEditDate: () -> Void
    let onRemove: () -> Void
    @State private var confirming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonitorLabel("⌖ \(goal.target)\(goal.date.map { " · \(Format.shortDate($0))" } ?? "")", color: theme.text)
                .padding(.bottom, 8)
            if confirming {
                Text("✕ Retirer ⌖ \(goal.target) ?")
                    .font(theme.font(14, .bold))
                    .foregroundStyle(theme.text)
                Text("Le plan s'arrête. Ton historique reste.")
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .padding(.bottom, 8)
                HStack(spacing: 8) {
                    Button("Retirer") {
                        onRemove()
                        dismiss()
                    }
                    .buttonStyle(MonitorButtonStyle(color: theme.alarm, filled: false, height: 44, fontSize: 12))
                    Button("Annuler") { withAnimation { confirming = false } }
                        .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 44, fontSize: 12))
                }
            } else {
                row("✎", "Objectif", "recalé au prochain bloc") {
                    dismiss()
                    onEditTarget()
                }
                row("◷", "Date", "déplace la ligne attendue") {
                    dismiss()
                    onEditDate()
                }
                row("✕", "Retirer", "le plan s'arrête") {
                    withAnimation { confirming = true }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.height(260)])
    }

    private func row(_ symbol: String, _ title: String, _ consequence: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(symbol).font(theme.font(14, .bold)).foregroundStyle(theme.text).frame(width: 18)
                Text(title).font(theme.font(13, .bold)).foregroundStyle(theme.text)
                Spacer()
                Text(consequence).font(theme.font(11)).foregroundStyle(theme.dim)
            }
            .padding(.vertical, 10)
            .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// La carte État (« comment je suis ») : la phase en pastille, la Forme en courbe sur ses
/// 8 dernières séances avec sa bande normale, la fatigue sur 5 points, l'effort sur 10 graduations.
private struct StateCard: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let all: [SessionRecord]

    var body: some View {
        let phase = stats.phase(all: all)
        let forms = stats.countingIsReliable ? Array(stats.formResults.suffix(8).map(\.result)) : []
        let last = stats.sessions.first
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                MonitorLabel("État")
                Spacer(minLength: 4)
                Circle().fill(phase.stateColor(theme) ?? theme.dim).frame(width: 8, height: 8)
                Text((phase.isAlert ? "! " : "") + phase.title)
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.dim)
            }
            HStack {
                MonitorLabel("Forme")
                Spacer()
                Text(forms.last.map { "\(Int($0.percent.rounded())) %" } ?? formPending)
                    .font(theme.font(13, .bold))
                    .foregroundStyle(forms.isEmpty ? theme.dim : theme.text)
            }
            if forms.count >= 2 {
                FormSpark(results: forms)
                    .frame(height: 40)
                    .accessibilityLabel(formAccessibility(forms.last))
            }
            HStack {
                MonitorLabel("Fatigue")
                Spacer()
                Scale(value: last?.fatigueScore, count: 5, round: true)
                    .accessibilityLabel(last?.fatigueScore.map { "Fatigue \($0) sur 5, \(Feeling.fatigueLabel($0))" } ?? "Fatigue non notée")
            }
            HStack {
                MonitorLabel("Effort")
                Spacer()
                Scale(value: last?.effort, count: 10, round: false)
                    .accessibilityLabel(last?.effort.map { "Effort \($0) sur 10, \(Feeling.effortLabel($0))" } ?? "Effort non noté")
            }
        }
        .coachingCard(theme)
        .contentShape(Rectangle())
    }

    private var formPending: String {
        if !stats.countingIsReliable { return "comptage à fiabiliser" }
        return "\(min(stats.measuredSessionCount, FormResult.baselineSessions)) / \(FormResult.baselineSessions)"
    }

    private func formAccessibility(_ result: FormResult?) -> String {
        guard let result else { return "Forme" }
        let zone = result.zone == .normal ? "dans ta variation habituelle" : result.zone.title.lowercased()
        return "Forme \(Int(result.percent.rounded())) %, \(zone)"
    }
}

/// Une échelle de points (fatigue, sur 5) ou de graduations (effort, sur 10).
private struct Scale: View {
    @Environment(\.theme) private var theme
    let value: Int?
    let count: Int
    let round: Bool

    var body: some View {
        HStack(spacing: round ? 4 : 2) {
            ForEach(0..<count, id: \.self) { index in
                // Effort : 0 … 10, une graduation par point au-dessus de 0
                let on = index < (value ?? 0)
                Group {
                    if round {
                        Circle().fill(on ? theme.text : .clear).overlay(Circle().stroke(on ? theme.text : theme.line, lineWidth: 1))
                            .frame(width: 10, height: 10)
                    } else {
                        RoundedRectangle(cornerRadius: 1).fill(on ? theme.text : .clear)
                            .overlay(RoundedRectangle(cornerRadius: 1).stroke(on ? theme.text : theme.line, lineWidth: 1))
                            .frame(width: 7, height: 10)
                    }
                }
            }
        }
    }
}

/// La Forme des dernières séances, sur la bande de variation normale.
private struct FormSpark: View {
    @Environment(\.theme) private var theme
    let results: [FormResult]

    var body: some View {
        Canvas { context, size in
            let low = 88.0, high = 112.0
            let y = { (percent: Double) -> CGFloat in
                2 + (size.height - 4) * CGFloat(1 - (min(max(percent, low), high) - low) / (high - low))
            }
            let band = results.last?.band ?? 3
            context.fill(Path(CGRect(x: 0, y: y(100 + band), width: size.width, height: y(100 - band) - y(100 + band))),
                         with: .color(theme.primary.opacity(0.1)))
            let points = results.enumerated().map { index, result in
                CGPoint(x: 4 + (size.width - 8) * CGFloat(index) / CGFloat(max(results.count - 1, 1)), y: y(result.percent))
            }
            var line = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(theme.primary), lineWidth: 1.5)
            for (index, point) in points.enumerated() {
                let radius: CGFloat = index == points.count - 1 ? 3.5 : 1.8
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(theme.primary))
            }
        }
    }
}

/// Fixer l'objectif (nombre et date facultative), modifier le nombre (✎), ou la date (◷).
private struct GoalEditor: View {
    enum Mode: String, Identifiable {
        case new, target, date
        var id: String { rawValue }
    }

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let exercise: Exercise
    let goal: Goal?
    let current: Int
    let onSave: (Goal?) -> Void
    @State private var target: Int
    @State private var hasDate: Bool
    @State private var date: Date

    init(mode: Mode, exercise: Exercise, goal: Goal?, current: Int, onSave: @escaping (Goal?) -> Void) {
        self.mode = mode
        self.exercise = exercise
        self.goal = goal
        self.current = current
        self.onSave = onSave
        _target = State(initialValue: goal?.target ?? max(current + 5, 10))
        _hasDate = State(initialValue: goal?.date != nil || mode == .date)
        _date = State(initialValue: goal?.date ?? Date().addingTimeInterval(16 * 7 * 86_400))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MonitorLabel(mode == .date ? "◷ Date · \(exercise.shortTitle)" : "⌖ Objectif · \(exercise.shortTitle)",
                             color: theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VStack(alignment: .leading, spacing: 18) {
                if mode != .date {
                    HStack(spacing: 12) {
                        stepButton("minus", -1)
                        Text("\(target)")
                            .font(theme.font(44, .bold))
                            .foregroundStyle(theme.ok)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                        stepButton("plus", 1)
                    }
                    Text("d'affilée · auj. \(current)")
                        .font(theme.font(12))
                        .foregroundStyle(theme.dim)
                        .frame(maxWidth: .infinity)
                    if mode == .target {
                        MonitorLabel("recalé au prochain bloc · le bloc en cours continue")
                            .frame(maxWidth: .infinity)
                    }
                }
                if mode != .target {
                    Toggle(isOn: $hasDate.animation()) {
                        Text("◷ DATE")
                            .font(theme.font(13, .bold))
                            .foregroundStyle(theme.text)
                    }
                    .tint(theme.primary)
                    if hasDate {
                        DatePicker("Pour le", selection: $date, in: Date()..., displayedComponents: .date)
                            .font(theme.font(13))
                            .foregroundStyle(theme.text)
                    }
                    if mode == .date {
                        MonitorLabel("déplace la ligne attendue et la projection")
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 16)
            Button("Enregistrer") {
                let date = mode == .target ? goal?.date : (hasDate ? self.date : nil)
                onSave(Goal(target: target, date: date, start: goal?.start ?? current, created: goal?.created ?? Date()))
                dismiss()
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 54))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    private func stepButton(_ systemImage: String, _ step: Int) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.15)) { target = min(max(target + step, 1), 500) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(step < 0 ? "Moins" : "Plus")
    }
}
