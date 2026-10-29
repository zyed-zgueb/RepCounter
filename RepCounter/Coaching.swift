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

/// La couleur d'état du Coaching (skill reps-ux, § 5) : bleu, la progression ; orange, séance
/// légère ou Forme basse ; violet, semaine allégée ; vert, prêt pour un record. Nil : rien à
/// signaler (en cours, analyse suspendue, pause).
extension TrainingPhase {
    func stateColor(_ theme: AppTheme) -> Color? {
        switch kind {
        case .building, .comeback: return theme.primary
        case .overreaching, .lowForm, .deloadAdvised, .persistentFatigue: return theme.warn
        case .deload: return theme.rest
        case .rebound: return theme.ok
        case .pending, .unreliable, .rest: return nil
        }
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

/// La bulle qui explique le point d'état, une seule fois, à son premier affichage.
struct StateDotTip: View {
    @Environment(\.theme) private var theme
    static let key = "coaching.dotExplained"
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorLabel("Ton état, en un point", color: theme.primary)
            VStack(alignment: .leading, spacing: 9) {
                row(theme.primary, "Progression", "la séance prévue")
                row(theme.warn, "Séance légère", "Forme basse")
                row(theme.rest, "Semaine allégée", "moins de volume")
                row(theme.ok, "Record possible", "une série max")
            }
            Text("Touche la cible : ton coaching.")
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
            Button("Compris", action: onDone)
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 40, fontSize: 12))
        }
        .padding(14)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius * 1.5, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius * 1.5, style: .continuous).stroke(theme.primary, lineWidth: 1))
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

/// Le Coaching (skill reps-ux) : l'avenir et le plan d'un exercice. De haut en bas : l'objectif
/// et où l'on en est, le bloc sur sa frise, le prévu face au fait, la carte État (phase, Forme,
/// ressenti), puis le mesuré face à l'attendu aux tests.
struct CoachingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SessionRecord.start, order: .reverse) private var sessions: [SessionRecord]
    let exercise: Exercise
    @State private var goal: Goal?
    @State private var editsGoal = false
    @State private var showsInfo = false
    @State private var showsBlockSheet = false
    /// Change quand un jour de séance est déplacé : le plan est recalculé.
    @State private var scheduleVersion = 0

    init(exercise: Exercise) {
        self.exercise = exercise
        _goal = State(initialValue: Goal.load(exercise))
    }

    var body: some View {
        let stats = HistoryStats(sessions: sessions, exercise: exercise)
        let plan = goal == nil ? nil : stats.plan(all: sessions)
        let _ = scheduleVersion
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
                        // Où je vais : l'objectif, le bloc, le prévu face au fait
                        GoalCard(exercise: exercise, goal: goal, current: stats.currentBest) { editsGoal = true }
                        if let plan {
                            BlockCard(plan: plan, exercise: exercise) { scheduleVersion += 1 }
                            PlanWeekTable(plan: plan)
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
                        // Mesuré face à attendu
                        if let plan, !plan.tests.isEmpty || plan.goal.date != nil {
                            TrajectoryCard(plan: plan)
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
        .sheet(isPresented: $editsGoal) {
            GoalEditor(exercise: exercise, goal: goal, current: stats.currentBest) { newGoal in
                Goal.save(newGoal, for: exercise)
                goal = newGoal
            }
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
        }
    }
}

enum CoachingPage: Hashable {
    case state
}

/// L'objectif et où l'on en est : le nombre fait, le départ, ce qui reste, une barre.
private struct GoalCard: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let goal: Goal?
    let current: Int
    let onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonitorLabel("Objectif · \(exercise.shortTitle.lowercased()) d'affilée")
                Spacer()
                if let goal {
                    Button("\(goal.target)", action: onEdit)
                        .font(theme.font(14, .bold))
                        .foregroundStyle(theme.text)
                        .accessibilityLabel("Modifier l'objectif : \(goal.target)")
                }
            }
            if let goal {
                let reached = current >= goal.target
                HStack(alignment: .firstTextBaseline) {
                    Text("\(current)")
                        .font(theme.font(34, .bold))
                        .foregroundStyle(reached ? theme.ok : theme.text)
                        .monospacedDigit()
                    Spacer()
                    Text(reached ? "atteint" : "départ \(goal.start) · reste \(goal.target - current)")
                        .font(theme.font(11))
                        .foregroundStyle(reached ? theme.ok : theme.dim)
                }
                GeometryReader { geometry in
                    let share = goal.target > goal.start
                        ? min(max(Double(current - goal.start) / Double(goal.target - goal.start), 0), 1) : 1
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.grid)
                        Capsule().fill(reached ? theme.ok : theme.primary)
                            .frame(width: geometry.size.width * share)
                    }
                }
                .frame(height: 6)
                if let date = goal.date {
                    Text("pour le \(Format.shortDate(date))")
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                }
            } else {
                Button("Fixer un objectif", action: onEdit)
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: false, height: 44, fontSize: 12))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }
}

/// La carte État (« comment je suis ») : la phase, la Forme mesurée, le ressenti. Une seule carte.
private struct StateCard: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let all: [SessionRecord]

    var body: some View {
        let phase = stats.phase(all: all)
        let advice = Advice.make(stats: stats)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                MonitorLabel("État")
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.dim)
            }
            row("Phase", phase.title, color: phase.stateColor(theme) ?? theme.dim)
            Text(actionText(phase, advice: advice))
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(theme.line).frame(height: 1)
            row("Forme", formText, color: formTextColor)
            row("Ressenti", feelingText, color: theme.text)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }

    /// En construction, le conseil Plateau ou Record à portée sert d'action s'il y en a un.
    private func actionText(_ phase: TrainingPhase, advice: Advice?) -> String {
        if phase.kind == .building, !phase.felt, let advice { return "\(advice.title) · \(advice.short)" }
        return phase.action()
    }

    private func row(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            MonitorLabel(label)
            Spacer(minLength: 8)
            Text(value)
                .font(theme.font(13, .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var lastForm: FormResult? {
        stats.countingIsReliable ? stats.formResults.last?.result : nil
    }

    private var formText: String {
        if let form = lastForm {
            return "\(Int(form.percent.rounded())) % · \(form.zone.title.lowercased())"
        }
        if !stats.countingIsReliable { return "comptage à fiabiliser" }
        return "en cours \(min(stats.measuredSessionCount, FormResult.baselineSessions)) / \(FormResult.baselineSessions)"
    }

    private var formTextColor: Color {
        lastForm.map { formColor($0.zone, theme: theme) } ?? theme.dim
    }

    /// Le ressenti de la dernière séance : fatigue avant (McLean, sur 5), effort après (CR-10).
    private var feelingText: String {
        let last = stats.sessions.first
        let fatigue = last?.fatigueScore.map { "fatigue \($0)/5" }
        let effort = last?.effort.map { "effort \($0)" }
        let parts = [fatigue, effort].compactMap { $0 }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}

/// Fixer ou modifier l'objectif : un nombre, une date facultative.
private struct GoalEditor: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise
    let goal: Goal?
    let current: Int
    let onSave: (Goal?) -> Void
    @State private var target: Int
    @State private var hasDate: Bool
    @State private var date: Date

    init(exercise: Exercise, goal: Goal?, current: Int, onSave: @escaping (Goal?) -> Void) {
        self.exercise = exercise
        self.goal = goal
        self.current = current
        self.onSave = onSave
        _target = State(initialValue: goal?.target ?? max(current + 5, 10))
        _hasDate = State(initialValue: goal?.date != nil)
        _date = State(initialValue: goal?.date ?? Date().addingTimeInterval(16 * 7 * 86_400))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                MonitorLabel("Objectif · \(exercise.shortTitle)", color: theme.primary)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    stepButton("minus", -1)
                    Text("\(target)")
                        .font(theme.font(44, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)
                    stepButton("plus", 1)
                }
                Text("d'affilée · aujourd'hui \(current)")
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .frame(maxWidth: .infinity)
                Toggle(isOn: $hasDate.animation()) {
                    Text("DATE")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(theme.text)
                }
                .tint(theme.primary)
                if hasDate {
                    DatePicker("Pour le", selection: $date, in: Date()..., displayedComponents: .date)
                        .font(theme.font(13))
                        .foregroundStyle(theme.text)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 16)
            VStack(spacing: 10) {
                Button("Enregistrer") {
                    onSave(Goal(target: target, date: hasDate ? date : nil,
                                start: goal?.start ?? current, created: goal?.created ?? Date()))
                    dismiss()
                }
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 54))
                if goal != nil {
                    Button("Retirer l'objectif") {
                        onSave(nil)
                        dismiss()
                    }
                    .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 40, fontSize: 11))
                }
            }
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
