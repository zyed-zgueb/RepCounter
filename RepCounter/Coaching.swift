import Charts
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
    /// Le niveau, jamais 0 : la meilleure série des 4 dernières semaines, sinon la dernière
    /// meilleure série connue (son ancienneté s'affiche : `levelDate`).
    var currentBest: Int {
        bestSet(lastDays: 28) ?? sessions.sorted { $0.start > $1.start }.first { $0.bestSet > 0 }?.bestSet ?? 0
    }

    /// La date du niveau quand il a plus de 28 jours (nil : niveau récent, ou aucun).
    var levelDate: Date? {
        guard bestSet(lastDays: 28) == nil else { return nil }
        return sessions.sorted { $0.start > $1.start }.first { $0.bestSet > 0 }?.start
    }
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

// MARK: - Vue Coaching

/// Le Coaching (skill reps-ux) : l'avenir et le plan d'un exercice, l'exercice en titre natif
/// (un glissement ou le menu du titre passent à un autre de Mes exercices). Du plus proche au plus lointain : la
/// séance du jour, l'objectif (ou l'invitation à en fixer un), le chemin jusqu'à lui, le bloc
/// en cours, puis l'état (phase, Forme, ressenti). Sans objectif, le plan tourne quand même sur
/// la séance habituelle : seul le chemin attend un objectif.
struct CoachingView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SessionRecord.start, order: .reverse) private var sessions: [SessionRecord]
    @State private var exercise: Exercise
    /// Mes exercices, dans l'ordre du cadran.
    let exercises: [Exercise]
    /// Démarrer : la séance de cet exercice, au cadran.
    let onStart: (Exercise) -> Void
    /// « ◆ Lancer le test » : le test de cet exercice, au cadran.
    var onStartTest: (Exercise) -> Void = { _ in }
    @State private var goal: Goal?
    @State private var editor: GoalEditor.Mode?
    @State private var showsMenu = false
    @State private var showsInfo = false
    /// Change quand un jour de séance est déplacé ou l'objectif retiré : le plan est recalculé.
    @State private var version = 0

    init(exercise: Exercise, exercises: [Exercise], onStart: @escaping (Exercise) -> Void,
         onStartTest: @escaping (Exercise) -> Void = { _ in }) {
        _exercise = State(initialValue: exercise)
        self.exercises = exercises.contains(exercise) ? exercises : [exercise] + exercises
        self.onStart = onStart
        self.onStartTest = onStartTest
        _goal = State(initialValue: Goal.load(exercise))
    }

    var body: some View {
        let stats = HistoryStats(sessions: sessions, exercise: exercise)
        let _ = version
        let plan = stats.plan(all: sessions)
        NavigationStack {
            VStack(spacing: 0) {
                VerticalScroll {
                    VStack(spacing: 14) {
                        if exercise == .auto {
                            // « Autre exercice » mêle des mouvements : ni plan ni objectif
                            Text("Le coaching suit un exercice précis.")
                                .font(theme.font(15))
                                .foregroundStyle(theme.dim)
                                .coachingCard(theme)
                        } else if stats.isEmpty {
                            // Rien à caler : la première séance d'abord
                            FirstSessionCard(exercise: exercise) { onStart(exercise) }
                            if goal != nil {
                                GoalHeader(goal: goal, shiftedDate: plan?.shiftedGoalDate, shiftWeeks: plan?.shiftWeeks ?? 0, exercise: exercise, current: stats.currentBest,
                                           levelDate: stats.levelDate, now: stats.now,
                                           onEdit: { editor = .target },
                                           onMenu: { showsMenu = true },
                                           onNext: { editor = .new })
                            } else {
                                GoalInvitation(level: nil) { editor = .new }
                            }
                        } else {
                            if let plan {
                                TodayCard(plan: plan, todaySets: todaySets(stats), onStart: { onStart(exercise) },
                                          onStartTest: { onStartTest(exercise) })
                            }
                            // Où je vais : l'objectif, le chemin, le bloc
                            if goal != nil {
                                GoalHeader(goal: goal, shiftedDate: plan?.shiftedGoalDate, shiftWeeks: plan?.shiftWeeks ?? 0, exercise: exercise, current: stats.currentBest,
                                           levelDate: stats.levelDate, now: stats.now,
                                           onEdit: { editor = .target },
                                           onMenu: { showsMenu = true },
                                           onNext: { editor = .new })
                            } else {
                                GoalInvitation(level: stats.currentBest) { editor = .new }
                            }
                            if let plan {
                                if goal != nil {
                                    PathCard(plan: plan, exercise: exercise, sessions: stats.sessions)
                                }
                                // Reprise après une longue absence : pas encore de bloc ni de test
                                if plan.hasTest {
                                    BlockCard(plan: plan)
                                }
                            }
                        }
                        // Comment je suis
                        if !stats.isEmpty {
                            NavigationLink(value: CoachingPage.state) {
                                StateCard(stats: stats, all: sessions)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .id(exercise)
                    .transition(.opacity)
                }
                .simultaneousGesture(swipe)
            }
            .background(theme.background.ignoresSafeArea())
            // Le titre est l'exercice courant, en ligne pour que son menu soit toujours accessible
            // (comme Photos ou Notes) ; le menu ou un glissement passent à un autre exercice
            .navigationTitle(exercise.shortTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                if exercises.count > 1 {
                    Picker("Exercice", selection: exerciseSelection) {
                        ForEach(exercises) { item in
                            Text(item.shortTitle).tag(item)
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showsInfo = true } label: { Image(systemName: "info.circle") }
                        .accessibilityLabel("Le plan, explications")
                    CloseButton()
                }
            }
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
        .onChange(of: exercise) { _, exercise in
            goal = Goal.load(exercise)
            version += 1
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
            GoalEditor(mode: mode, exercise: exercise, goal: goal, current: stats.currentBest,
                       proposed: mode == .new ? GoalInvitation.proposal(stats.currentBest) : nil) { newGoal in
                Goal.save(newGoal, for: exercise)
                goal = newGoal
                version += 1
            }
            .environment(\.theme, theme)
            .preferredColorScheme(theme.colorScheme)
        }
        .sensoryFeedback(.selection, trigger: exercise)
    }

    /// Le choix de l'exercice dans le menu du titre (le système dessine la coche).
    private var exerciseSelection: Binding<Exercise> {
        Binding(get: { exercise }, set: { item in
            guard item != exercise else { return }
            withAnimation(.easeInOut(duration: 0.2)) { exercise = item }
        })
    }

    /// Glisser à gauche ou à droite : l'exercice suivant ou précédent (le défilement vertical reste).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > 70, abs(dx) > abs(dy) * 2 else { return }
                move(by: dx < 0 ? 1 : -1)
            }
    }

    /// Passe à l'exercice voisin dans Mes exercices (en boucle).
    private func move(by step: Int) {
        guard exercises.count > 1, let index = exercises.firstIndex(of: exercise) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            exercise = exercises[(index + step + exercises.count) % exercises.count]
        }
    }

    /// Les séries faites aujourd'hui (séances espacées comprises), dans l'ordre.
    private func todaySets(_ stats: HistoryStats) -> [Int] {
        stats.sessions
            .filter { stats.calendar.isDate($0.start, inSameDayAs: stats.now) }
            .sorted { $0.start < $1.start }
            .flatMap { $0.orderedSets.map(\.reps) }
    }
}

enum CoachingPage: Hashable {
    case state
}

/// La séance du jour, en tête du Coaching (la ligne sous le cadran en est le résumé) :
/// - à faire : les cibles en barres, ◷ le repos, l'intensité (pastille et mot), Démarrer ;
/// - faite : « ✓ fait », le fait face aux cibles, puis la prochaine séance ;
/// - repos conseillé : sa raison (« test demain »), puis la prochaine séance et ses cibles ;
/// - séance légère : « ! léger », barres réduites ; semaine allégée : « allégée ».
private struct TodayCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    /// Les séries faites aujourd'hui.
    let todaySets: [Int]
    let onStart: () -> Void
    var onStartTest: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(symbol: "calendar", title: "Aujourd'hui") {
                if plan.status == .due { intensity(plan.today) }
            }
            switch plan.status {
            case .due where plan.today == .test:
                // Jour de test (ou test « à faire ») : la personne le lance ; la séance allégée reste possible
                MonitorLabel(testMark, color: plan.testOverdue ? theme.text : theme.max)
                Text(symbols: "◆ série max" + (plan.tests.last.map { " · dernier test \($0.value)" } ?? ""))
                    .font(theme.font(15, .bold))
                    .foregroundStyle(theme.text)
                if plan.testOverdue, let fallback = plan.fallback {
                    Text("En attendant : séance allégée · \(fallback.sets) série\(fallback.sets > 1 ? "s" : "")")
                        .font(theme.font(12))
                        .foregroundStyle(theme.dim)
                }
                Button(action: onStartTest) { Text(symbols: "◆ Lancer le test") }
                    .buttonStyle(MonitorButtonStyle(color: theme.max, height: 48, fontSize: 13))
                // Bloc 1 : la séance de calibrage (normale) ; sinon la séance allégée
                Button(plan.testStep != nil ? "Séance normale à la place"
                       : (plan.testOverdue ? "Séance allégée" : "Séance allégée à la place"), action: onStart)
                    .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 44, fontSize: 12, wraps: true))
            case .due:
                if let mark = mark(plan.today) {
                    MonitorLabel(mark, color: theme.text)
                }
                session(plan.today, done: todaySets.isEmpty ? nil : todaySets)
                Button("Démarrer", action: onStart)
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 48, fontSize: 13))
            case .done:
                HStack {
                    Text(symbols: plan.targetMissed ? "fait · cible non atteinte" : "✓ fait")
                        .font(theme.font(15, .bold))
                        .foregroundStyle(plan.targetMissed ? theme.text : theme.ok)
                    Spacer()
                }
                TargetBars(targets: plan.todaySession?.targets ?? [], done: todaySets, color: plan.today.color(theme))
                upcoming
            case .rest:
                HStack {
                    Text("repos conseillé")
                        .font(theme.font(15, .bold))
                        .foregroundStyle(theme.dim)
                    Spacer()
                }
                if let reason = plan.restReason {
                    Text(reason.short)
                        .font(theme.font(12))
                        .foregroundStyle(theme.text)
                }
                upcoming
            }
            // Moins de 2 séances sur 7 jours : le minimum, une ligne discrète (METHODE-JOURS.md, règle 6)
            if plan.belowMinimum, plan.status != .done {
                MonitorLabel("au moins 2 séances par semaine")
            }
        }
        .coachingCard(theme)
    }

    /// « ! ◆ test à faire », « ◆ test 1 / 2 » (bloc 1) ou « ◆ jour de test ».
    private var testMark: String {
        if plan.testOverdue { return "! ◆ test à faire" }
        if let step = plan.testStep { return "◆ test \(step.number) / \(step.of)" }
        return "◆ jour de test"
    }

    /// « Aujourd'hui · ! léger » à gauche, l'intensité (pastille et mot) à droite.
    private func title(_ label: String, _ day: TrainingPlan.Today) -> some View {
        HStack(spacing: 6) {
            MonitorLabel(label, color: theme.text)
            if let mark = mark(day) {
                MonitorLabel(mark, color: theme.text)
            }
            Spacer(minLength: 4)
            intensity(day)
        }
        .accessibilityElement(children: .combine)
    }

    /// L'intensité du jour : une pastille et son mot, dans sa couleur.
    private func intensity(_ day: TrainingPlan.Today) -> some View {
        HStack(spacing: 6) {
            Circle().fill(day.color(theme)).frame(width: 8, height: 8)
            MonitorLabel(Intensity.word(day.intensity), color: day.color(theme))
        }
    }

    private func mark(_ day: TrainingPlan.Today) -> String? {
        switch day {
        case .light: return "! léger"
        case .deload: return "allégée"
        case .reprise, .comeback: return "! reprise"
        case .test: return "◆ test"
        case .session: return nil
        }
    }

    /// Les cibles en barres et le repos, ou, un jour de test, la série max.
    @ViewBuilder
    private func session(_ day: TrainingPlan.Today, done: [Int]?, compact: Bool = false) -> some View {
        if case .test = day {
            Text(symbols: "◆ série max")
                .font(theme.font(compact ? 14 : 22, .bold))
                .foregroundStyle(day.color(theme))
        } else if case .comeback = day {
            // Plus de 28 jours sans séance : une séance libre, le plan repart de ton niveau
            Text("Reprise : fais une séance, le plan repart de ton niveau.")
                .font(theme.font(compact ? 13 : 15))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        } else if let s = sessionOf(day) {
            HStack(alignment: .bottom, spacing: 12) {
                TargetBars(targets: s.targets, done: done, color: day.color(theme), compact: compact)
                Text(symbols: "◷ \(Format.clock(Double(s.rest)))")
                    .font(theme.font(compact ? 11 : 13, .bold))
                    .foregroundStyle(theme.dim)
                    .padding(.bottom, 4)
                    .accessibilityLabel("Repos \(Format.clock(Double(s.rest)))")
            }
        }
    }

    private func sessionOf(_ day: TrainingPlan.Today) -> Prescription.Session? {
        switch day {
        case .session(let s), .light(let s), .deload(let s), .reprise(let s): return s
        case .test, .comeback: return nil
        }
    }

    /// « prochaine · vendredi » et ses cibles, en petit.
    @ViewBuilder
    private var upcoming: some View {
        if let next = plan.next {
            title("prochaine · \(Format.weekdayOrDate(next))", plan.upcoming)
            session(plan.upcoming, done: nil, compact: true)
                .opacity(0.85)
            Button("Démarrer quand même", action: onStart)
                .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 40, fontSize: 12))
        }
    }
}

/// Une séance en barres (Swift Charts), une par série : hauteur = cible, valeur au-dessus. Avec
/// ce qui est fait : barre pâle = cible, pleine = fait, verte et ✓ si la cible est atteinte.
private struct TargetBars: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var regularHeight: CGFloat = 84
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 52
    let targets: [Int]
    let done: [Int]?
    let color: Color
    var compact = false

    private struct Bar: Identifiable {
        let id: Int
        let target: Int?
        let done: Int?
        var name: String { "S\(id + 1)" }
        /// Pas de cible, pas de ✓ ni de vert (règle 6).
        var reached: Bool { done.map { value in target.map { value >= $0 } ?? false } ?? false }
    }

    var body: some View {
        let count = max(targets.count, done?.count ?? 0)
        let bars = (0..<count).map { index in
            Bar(id: index, target: index < targets.count ? targets[index] : nil,
                done: done.flatMap { index < $0.count ? $0[index] : nil })
        }
        Chart(bars) { bar in
            if let target = bar.target {
                BarMark(x: .value("Série", bar.name), yStart: .value("Cible", 0.0), yEnd: .value("Cible", Double(target)),
                        width: .ratio(0.7))
                    .foregroundStyle(done == nil ? color.opacity(0.8) : theme.line.opacity(0.6))
                    .cornerRadius(3)
                    .annotation(position: .top) {
                        if bar.done == nil {
                            Text("\(target)")
                                .font(theme.font(compact ? 11 : 13, .bold))
                                .foregroundStyle(theme.text)
                        }
                    }
            }
            if let value = bar.done {
                BarMark(x: .value("Série", bar.name), yStart: .value("Fait", 0.0), yEnd: .value("Fait", Double(value)),
                        width: .ratio(0.45))
                    .foregroundStyle(bar.reached ? theme.ok : (bar.target == nil ? theme.dim : theme.primary))
                    .cornerRadius(2)
                    .annotation(position: .top) {
                        Text(symbols: "\(value)\(bar.reached ? " ✓" : "")")
                            .font(theme.font(11, .bold))
                            .foregroundStyle(bar.reached ? theme.ok : theme.text)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...Double(max((targets + (done ?? [])).max() ?? 1, 1)) * 1.25)
        .frame(height: compact ? compactHeight : regularHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let planned = "Cibles " + targets.map(String.init).joined(separator: ", ")
        guard let done, !done.isEmpty else { return planned }
        return planned + ". Fait " + done.map(String.init).joined(separator: ", ")
    }
}


/// Sans historique : la première séance cale le plan.
private struct FirstSessionCard: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CardHeader(symbol: "calendar", title: "Aujourd'hui")
            Text("Fais une première séance : le plan partira de ton niveau.")
                .font(theme.font(13))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Button("Démarrer", action: onStart)
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 48, fontSize: 13))
        }
        .coachingCard(theme)
    }
}

/// Sans objectif : « ⌖ Fixe un objectif pour voir ton chemin », avec une proposition tirée du
/// niveau (« 33 → 40 ? »).
private struct GoalInvitation: View {
    @Environment(\.theme) private var theme
    /// Le niveau (meilleure série récente) ; nil ou 0 : pas de proposition.
    let level: Int?
    let onSet: () -> Void

    /// La proposition : environ 20 % au-dessus du niveau, arrondie, au moins +1. Un choix de
    /// l'app, pas une norme : un point de départ que l'on modifie.
    static func proposal(_ level: Int) -> Int? {
        guard level > 0 else { return nil }
        return max(Int((Double(level) * 1.2).rounded()), level + 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            CardHeader(symbol: "scope", title: "Objectif")
            MonitorLabel("Fixe un objectif pour voir ton chemin", color: theme.text)
            if let level, let proposal = Self.proposal(level) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(level)")
                        .font(theme.font(28, .bold))
                        .foregroundStyle(theme.text)
                    Text("→")
                        .font(theme.font(20, .bold))
                        .foregroundStyle(theme.dim)
                    Text("\(proposal) ?")
                        .font(theme.font(28, .bold))
                        .foregroundStyle(theme.ok)
                    Spacer()
                }
                .monospacedDigit()
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Niveau \(level), objectif proposé \(proposal)")
                MonitorLabel("niveau · proposé +20 %, choix de l'app")
            }
            Button(action: onSet) { Text(symbols: "⌖ Fixer un objectif") }
                .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: false, height: 44, fontSize: 12))
        }
        .coachingCard(theme)
    }
}

/// L'en-tête : l'objectif, le chiffre le plus visible de l'écran (vert comme la ligne d'arrivée),
/// « ⌖ pour le 12 fév. » au-dessus, l'unité dessous (« pompes d'affilée ») ; à droite,
/// « niveau 33 », « reste 7 », ✎ et ⋯.
private struct GoalHeader: View {
    @Environment(\.theme) private var theme
    /// Lu pour que le grand chiffre (au-delà du grand titre) suive un changement de taille de texte.
    @Environment(\.dynamicTypeSize) private var typeSize
    let goal: Goal?
    /// La date de l'objectif décalée des semaines refaites (celle du chemin), si le plan existe.
    var shiftedDate: Date? = nil
    /// Les semaines de décalage (semaines refaites, attente du test).
    var shiftWeeks = 0
    let exercise: Exercise
    let current: Int
    /// Le niveau date de plus de 28 jours : son ancienneté s'affiche.
    var levelDate: Date? = nil
    /// Le jour de référence des statistiques (`HistoryStats.now`).
    var now = Date()
    let onEdit: () -> Void
    let onMenu: () -> Void
    /// Objectif atteint : fixer le suivant.
    var onNext: () -> Void = {}

    var body: some View {
        let _ = typeSize
        if let goal {
            VStack(alignment: .leading, spacing: 4) {
                CardHeader(symbol: "scope", title: "Objectif") {
                    if let date = shiftedDate ?? goal.date {
                        // Décalée des semaines refaites et de l'attente du test : « +n sem. »
                        MonitorLabel("pour le \(Format.shortDate(date))" + (shiftWeeks > 0 ? " · +\(shiftWeeks) sem." : ""))
                    }
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("\(goal.target)")
                            .font(theme.font(64, .bold))
                            .foregroundStyle(theme.ok)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        MonitorLabel("\(exercise.shortTitle.lowercased()) d'affilée")
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 10) {
                        HStack(spacing: 6) {
                            symbolButton("pencil", label: "Modifier l'objectif", action: onEdit)
                            symbolButton("ellipsis", label: "Menu de l'objectif", action: onMenu)
                        }
                        figure("niveau", current)
                        if let age = levelAge {
                            MonitorLabel(age)
                        }
                        if current >= goal.target {
                            // Atteint ou dépassé : en vert (skill reps-ux, § 5), à la place de « reste 0 »
                            Text(symbols: "✓ atteint")
                                .font(theme.font(15, .bold))
                                .foregroundStyle(theme.ok)
                                .accessibilityLabel("Objectif atteint")
                        } else {
                            figure("reste", goal.target - current)
                        }
                    }
                    .padding(.bottom, 6)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Objectif \(goal.target) \(exercise.shortTitle.lowercased()) d'affilée, niveau \(current)"
                                    + (current >= goal.target ? ", atteint" : ""))
                if current >= goal.target, let next = GoalInvitation.proposal(current) {
                    // L'objectif suivant : même règle que la proposition (+20 %, choix de l'app)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(symbols: "suivant · \(current) → \(next) ?")
                            .font(theme.font(13, .medium))
                            .foregroundStyle(theme.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("Objectif suivant : \(current) à \(next) ?")
                        Spacer(minLength: 8)
                        Button(action: onNext) {
                            Text(symbols: "⌖ Fixer")
                                .font(theme.font(15, .semibold))
                                .foregroundStyle(theme.primary)
                                .padding(.horizontal, 14)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Fixer l'objectif suivant")
                    }
                    .padding(.top, 4)
                }
            }
            .coachingCard(theme)
        }
    }

    /// « il y a 6 sem. » pour un niveau de plus de 28 jours.
    private var levelAge: String? {
        guard let levelDate else { return nil }
        let weeks = Int(now.timeIntervalSince(levelDate) / (7 * 86_400))
        return "il y a \(max(weeks, 4)) sem."
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

    private func symbolButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(theme.font(17, .bold))
                .foregroundStyle(theme.dim)
                .frame(width: 44, height: 44)
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
                Text(symbols: "✕ Retirer ⌖ \(goal.target) ?")
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
        // Ajustée au texte (Dynamic Type), plus une hauteur fixe
        .presentationDetents([.medium, .large])
    }

    private func row(_ symbol: String, _ title: String, _ consequence: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(symbols: symbol).font(theme.font(14, .bold)).foregroundStyle(theme.text).frame(width: 18)
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
            CardHeader(symbol: "waveform.path.ecg", title: "État", opens: true) {
                Circle().fill(phase.stateColor(theme) ?? theme.dim).frame(width: 8, height: 8)
                Text(symbols: (phase.isAlert ? "! " : "") + phase.title)
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
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

/// La Forme des dernières séances (Swift Charts), sur sa bande de variation normale. Dans la carte
/// État, qui s'ouvre d'une touche : pas de sélection au doigt.
private struct FormSpark: View {
    @Environment(\.theme) private var theme
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 44
    let results: [FormResult]

    var body: some View {
        let band = results.last?.band ?? 3
        // L'échelle s'élargit pour contenir toutes les valeurs (88–112 % au moins) : rien n'est
        // rogné sans le dire
        let values = results.map(\.percent)
        let low = min(88, (values.min() ?? 100) - 1)
        let high = max(112, (values.max() ?? 100) + 1)
        Chart {
            RectangleMark(xStart: .value("Séance", -0.3), xEnd: .value("Séance", Double(max(results.count - 1, 1)) + 0.3),
                          yStart: .value("Bande", max(100 - band, low)), yEnd: .value("Bande", min(100 + band, high)))
                .foregroundStyle(theme.primary.opacity(0.1))
            ForEach(Array(results.enumerated()), id: \.offset) { index, result in
                LineMark(x: .value("Séance", Double(index)), y: .value("Forme", result.percent))
                    .foregroundStyle(theme.primary)
                PointMark(x: .value("Séance", Double(index)), y: .value("Forme", result.percent))
                    .foregroundStyle(theme.primary)
                    .symbolSize(index == results.count - 1 ? 50 : 14)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: low...high)
        .chartXScale(domain: -0.3...(Double(max(results.count - 1, 1)) + 0.3))
        .frame(height: height)
    }
}


/// Fixer l'objectif (nombre et date facultative), modifier le nombre (✎), ou la date (◷).
private struct GoalEditor: View {
    enum Mode: String, Identifiable {
        case new, target, date
        var id: String { rawValue }
    }

    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.dismiss) private var dismiss
    let mode: Mode
    let exercise: Exercise
    let goal: Goal?
    let current: Int
    let onSave: (Goal?) -> Void
    @State private var target: Int
    @State private var hasDate: Bool
    @State private var date: Date

    init(mode: Mode, exercise: Exercise, goal: Goal?, current: Int, proposed: Int? = nil, onSave: @escaping (Goal?) -> Void) {
        self.mode = mode
        self.exercise = exercise
        self.goal = goal
        self.current = current
        self.onSave = onSave
        _target = State(initialValue: (mode == .new ? proposed : goal?.target) ?? proposed ?? max(current + 5, 10))
        _hasDate = State(initialValue: goal?.date != nil || mode == .date)
        _date = State(initialValue: goal?.date ?? Date().addingTimeInterval(16 * 7 * 86_400))
    }

    var body: some View {
        let _ = typeSize
        VStack(spacing: 0) {
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
                    Text("d'affilée · niveau \(current)")
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
                        Text(symbols: "◷ DATE")
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
                // Un nouvel objectif (le premier, ou le suivant une fois atteint) part du niveau
                // actuel ; modifier le nombre ou la date garde le départ
                onSave(mode == .new ? Goal(target: target, date: date, start: current, created: Date())
                                    : Goal(target: target, date: date, start: goal?.start ?? current, created: goal?.created ?? Date()))
                dismiss()
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 54))
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .sheetNavigation(mode == .date ? "Date · \(exercise.shortTitle)" : "Objectif · \(exercise.shortTitle)", display: .inline)
        .sensoryFeedback(.selection, trigger: target)
    }

    private func stepButton(_ systemImage: String, _ step: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.15)) { target = min(max(target + step, 1), 500) }
        } label: {
            Image(systemName: systemImage)
                .font(theme.font(16, .bold))
                .foregroundStyle(theme.text)
                .frame(width: 48, height: 48)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(step < 0 ? "Moins" : "Plus")
    }
}
