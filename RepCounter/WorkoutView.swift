import SwiftData
import StoreKit
import SwiftUI
import TipKit

/// L'écran unique de l'app : le cadran. En veille, on y glisse d'un exercice à l'autre ;
/// pendant l'effort, il n'affiche que le nombre ; en récupération, le chronomètre ; à la fin,
/// le total. Tout le reste est rangé dans les Réglages.
struct WorkoutView: View {
    @Environment(\.theme) private var theme
    /// Réduire les animations : un fondu au lieu d'un mouvement.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model: WorkoutModel
    @AppStorage(SettingsView.analysisModeKey) private var analysisMode = false
    @AppStorage(Exercise.armbandKey) private var hasArmband = false
    @AppStorage(Coach.key) private var coachStep = 0
    /// Fiche « Placer ton iPhone » affichée ; `guideStartsSession` : la séance démarre ensuite.
    @State private var guideExercise: Exercise?
    @State private var guideStartsSession = false
    @State private var bump = false
    @State private var showsHistory = false
    @State private var showsCoaching = false
    /// Exercice dont la séance démarre à la fermeture du Coaching (Démarrer touché).
    @State private var coachingStart: Exercise?
    @State private var cachedPlan: TrainingPlan?
    @State private var planComputed = false
    /// La bulle qui explique le point d'état a été vue (une seule fois).
    /// La séance terminée, enregistrée dans l'historique.
    @State private var record: SessionRecord?
    /// Exercice affiché dans le cadran pendant qu'on glisse ; adopté une fois le geste posé.
    @State private var browsing: Exercise
    /// Charge de l'haltère de l'exercice affiché (Biceps, Développé), mémorisée par exercice.
    @State private var load: Double
    @State private var loadKind: LoadKind
    @State private var pendingSelection: DispatchWorkItem?
    @State private var autoStarted = false
    /// Brassard déclaré quand l'écran a été créé (ses capteurs en dépendent).
    @State private var builtWithArmband = Exercise.hasArmband
    @State private var pausedForSettings = false
    /// Séances enregistrées (la question de fatigue n'arrive qu'après les premières).
    @Query(sort: \SessionRecord.start, order: .reverse) private var sessions: [SessionRecord]
    /// Fatigue notée aujourd'hui, avant la séance.
    @State private var fatigue = Feeling.todayFatigue()
    /// Adopte un autre exercice : l'écran est recréé avec ses capteurs.
    /// Le second paramètre demande de démarrer la séance aussitôt (Démarrer touché en glissant).
    let onSelectExercise: (Exercise, Bool) -> Void
    /// Démarrer la séance dès l'affichage.
    let startsSession: Bool
    /// Les exercices du cadran (Mes exercices), dans l'ordre.
    let exercises: [Exercise]
    /// Ouvre les Réglages. Ils sont présentés au-dessus de cet écran, pas par lui : un réglage
    /// qui recrée l'écran (brassard, exercice retiré) ne les referme pas.
    let onOpenSettings: () -> Void
    /// Demande à recréer l'écran : ses capteurs ne correspondent plus au réglage du brassard.
    let onRebuild: () -> Void
    /// Réglages ouverts : un changement de brassard attend leur fermeture (pas de caméra qui
    /// s'allume derrière eux à chaque essai).
    let settingsShown: Bool

    /// Délai sans geste avant d'adopter l'exercice affiché : passer vite de Pompes à Biceps
    /// n'allume pas et n'éteint pas la caméra à chaque étape.
    private static let selectionDelay = 0.4

    init(exercise: Exercise, exercises: [Exercise], startsSession: Bool = false,
         settingsShown: Bool, onOpenSettings: @escaping () -> Void, onRebuild: @escaping () -> Void,
         onSelectExercise: @escaping (Exercise, Bool) -> Void) {
        _model = StateObject(wrappedValue: WorkoutModel(exercise: exercise))
        _browsing = State(initialValue: exercise)
        _load = State(initialValue: exercise.load)
        _loadKind = State(initialValue: exercise.loadKind)
        self.onSelectExercise = onSelectExercise
        self.startsSession = startsSession
        self.exercises = exercises
        self.onOpenSettings = onOpenSettings
        self.onRebuild = onRebuild
        self.settingsShown = settingsShown
    }

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                topBar
                if analysisMode, model.isRecording { recordingBanner.padding(.top, 8) }
                if analysisMode, model.showsDiagnostics { diagnosticsPanel.padding(.top, 8) }

                if model.phase == .finished {
                    SessionSummary(model: model, record: record)
                } else {
                    hero
                    bottom
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .onAppear {
            model.start()
            if startsSession, !autoStarted {
                autoStarted = true
                model.beginSession()
            }
        }
        .onDisappear {
            pendingSelection?.cancel()
            model.stop()
        }
        .onChange(of: load) { _, new in browsing.load = new }
        .onChange(of: loadKind) { _, new in browsing.loadKind = new }
        .onChange(of: model.phase) { _, phase in
            // Le plan du jour est figé au départ de la séance
            switch phase {
            case .ready:
                planComputed = false
            case .finished:
                break
            default:
                if !planComputed {
                    let dayPlan = plan(model.exercise)
                    cachedPlan = dayPlan
                    planComputed = true
                    // Les cibles du jour, et les séries déjà faites aujourd'hui (séries espacées)
                    let earlier = sessions
                        .filter { $0.exercise == model.exercise && Calendar.current.isDateInToday($0.start) }
                        .sorted { $0.start < $1.start }
                        .flatMap { $0.orderedSets.map(\.reps) }
                    model.planDay = dayPlan?.todaySession.map {
                        WorkoutModel.PlanDay(session: $0, ratios: dayPlan?.ratios, earlierToday: earlier)
                    }
                }
            }
        }
        .onChange(of: browsing) { _, exercise in
            load = exercise.load
            loadKind = exercise.loadKind
            pendingSelection?.cancel()
            guard exercise != model.exercise else { return }
            let selection = DispatchWorkItem { onSelectExercise(exercise, false) }
            pendingSelection = selection
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionDelay, execute: selection)
        }
        .onChange(of: model.repPulse) {
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bump = false }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
        .animation(.easeInOut(duration: 0.35), value: model.isResting)
        .animation(.easeInOut(duration: 0.35), value: model.state)
        // Plein écran pendant une série seulement (skill reps-ux, § 11)
        .statusBarHidden(model.phase == .active && !model.isResting)
        .sheet(item: $model.finishedRecording) { finished in
            RecordingSheet(finished: finished)
                .systemSheet()
        }
        .onChange(of: model.phase) { _, phase in
            // Séance terminée : enregistrée aussitôt ; nouvelle séance : on repart de rien
            if phase == .finished {
                record = SessionRecord.save(model, load: model.exercise.load, loadKind: model.exercise.loadKind, in: modelContext)
            } else if phase == .ready {
                record = nil
                rebuildIfNeeded()
            }
        }
        // Réglages ouverts : capteurs en pause (rien à compter, caméra éteinte, interface fluide).
        // À leur fermeture, l'écran reprend, ou se recrée si le brassard a changé.
        .onChange(of: model.state) { advanceCoach() }
        .onChange(of: model.phase) { advanceCoach() }
        .sheet(item: $guideExercise) { exercise in
            PlacementGuideView(guide: PlacementGuide(exercise: exercise, armband: hasArmband),
                               buttonTitle: guideStartsSession ? "C'est parti" : "J'ai compris") {
                if guideStartsSession { start(exercise) }
            }
            .systemSheet()
        }
        .onChange(of: settingsShown) { _, shown in
            if shown {
                // Un enregistrement en cours (mode analyse) continue
                guard !model.isRecording else { return }
                model.stop()
                pausedForSettings = true
            } else if !rebuildIfNeeded(), pausedForSettings {
                pausedForSettings = false
                model.start()
            }
        }
        .sheet(isPresented: $showsHistory) {
            HistoryView(exercise: model.exercise)
                .systemSheet()
        }
        .sheet(isPresented: $showsCoaching, onDismiss: {
            // Démarrer touché dans le Coaching : la séance de cet exercice, au cadran
            guard let exercise = coachingStart else { return }
            coachingStart = nil
            if model.phase == .ready || exercise != model.exercise { start(exercise) }
        }) {
            CoachingView(exercise: model.exercise, exercises: exercises) { exercise in
                coachingStart = exercise
                showsCoaching = false
            }
            .systemSheet()
        }
    }

    /// Le point d'état de l'icône Coaching (skill reps-ux, § 5) : celui du plan du jour s'il y a
    /// un objectif, sinon la couleur de la phase de l'exercice.
    private var stateDot: Color? {
        guard browsing != .auto else { return nil }
        if let today = plan(browsing)?.today { return today.color(theme) }
        return HistoryStats(sessions: sessions, exercise: browsing).phase(all: sessions).stateColor(theme)
    }

    /// Le plan d'un exercice (nil sans séance pour le caler).
    private func plan(_ exercise: Exercise) -> TrainingPlan? {
        HistoryStats(sessions: sessions, exercise: exercise).plan(all: sessions)
    }

    /// Brassard déclaré ou retiré pour un exercice de bras : l'écran est recréé avec les bons
    /// capteurs, une fois les Réglages refermés, et seulement en veille. Une séance terminée
    /// (son résumé) reste affichée ; le changement s'applique à la nouvelle séance.
    /// - Returns: vrai si l'écran va être recréé.
    @discardableResult
    private func rebuildIfNeeded() -> Bool {
        guard model.exercise.isArmExercise, hasArmband != builtWithArmband,
              model.phase == .ready, !settingsShown else { return false }
        onRebuild()
        return true
    }

    // MARK: - Fond

    /// Halo derrière le cadran, de la couleur de l'état : profondeur sans décor.
    private var backdrop: some View {
        ZStack {
            theme.background
            RadialGradient(colors: [haloColor.opacity(0.13 * max(theme.glow, 0.5)), haloColor.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 0.44), startRadius: 0, endRadius: 240)
        }
        .ignoresSafeArea()
    }

    private var haloColor: Color {
        switch model.phase {
        case .countdown: return theme.warn
        case .finished: return theme.ok
        case .active where model.isResting: return theme.warn
        default: return theme.primary
        }
    }

    // MARK: - Barre du haut

    private var topBar: some View {
        HStack(spacing: 8) {
            if model.phase == .ready || model.phase == .finished {
                IconButton(systemImage: "chart.bar.fill", color: theme.dim) { showsHistory = true }
            }
            if model.phase == .ready {
                Spacer()
            } else {
                StatusLED(color: statusColor)
                MonitorLabel(statusText, color: statusColor)
                Spacer(minLength: 4)
                if model.phase == .active || model.phase == .finished {
                    Text("T+ \(Format.clock(model.sessionDuration))")
                        .font(theme.font(13, .semibold))
                        .tracking(1)
                        .foregroundStyle(theme.dim)
                        .monospacedDigit()
                }
            }
            // Outils d'analyse : visibles seulement si le mode analyse est activé dans les Réglages
            if analysisMode, model.phase != .finished {
                IconButton(systemImage: model.isRecording ? "stop.fill" : "record.circle",
                           color: theme.alarm, highlighted: model.isRecording) { model.toggleRecording() }
                IconButton(systemImage: "waveform.path.ecg", color: theme.primary,
                           highlighted: model.showsDiagnostics) { model.showsDiagnostics.toggle() }
            }
            if model.phase == .ready || model.phase == .finished {
                CoachingButton(dot: model.phase == .ready ? stateDot : nil) {
                    StateTip().invalidate(reason: .actionPerformed)
                    showsCoaching = true
                }
                // Le point d'état s'explique une fois (TipKit), à son premier affichage, en veille
                .popoverTip(StateTip())
                .task(id: model.phase == .ready && stateDot != nil) {
                    StateTip.dotShown = model.phase == .ready && stateDot != nil
                }
                IconButton(systemImage: "gearshape", color: theme.dim) { onOpenSettings() }
            }
        }
        .frame(height: 44)
    }

    private var statusText: String {
        switch model.phase {
        case .ready: return ""
        case .positioning: return model.placement.isComplete ? "Prêt" : "Mise en place"
        case .countdown: return "Mise en place"
        case .finished: return "Séance terminée"
        case .active:
            if model.isResting { return "Récupération" }
            let set = "Série \(String(format: "%02d", model.setNumber))"
            return model.state == .counting ? set : "\(set) · détection"
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .ready: return theme.dim
        case .positioning: return model.placement.isComplete ? theme.ok : theme.warn
        case .countdown: return theme.warn
        case .finished: return theme.ok
        case .active:
            if model.isResting { return theme.warn }
            return model.state == .counting ? theme.ok : theme.primary
        }
    }

    // MARK: - Cadran

    @ViewBuilder
    private var hero: some View {
        VStack(spacing: 14) {
            switch model.phase {
            case .ready:
                Dial(face: CounterDialFace(lit: 0, color: theme.primary, live: model.live, palePulse: true)) { side in
                    ExerciseCarousel(selection: $browsing, exercises: exercises, side: side)
                }
                // La séance du jour, si un plan existe (skill reps-ux : une ligne, pas le plan)
                if let browsingPlan = plan(browsing) {
                    TodayLine(plan: browsingPlan)
                }
                placementText(browsing)
                loadControl
                if asksFatigue {
                    FatigueQuestion(fatigue: $fatigue)
                        .padding(.horizontal, 20)
                }
            case .positioning:
                PlacementView(placement: model.placement, exercise: model.exercise,
                              showsCamera: model.placementKind?.usesCamera == true) { showGuide(model.exercise) }
            case .countdown(let remaining):
                let total = max(model.countdownTotal, 1)
                let elapsed = Double(total - remaining) / Double(total)
                Dial(face: DialFace(lit: Int(elapsed * Double(DialFace.tickCount)), palette: .solid(theme.warn))) { side in
                    Text("\(remaining)")
                        .font(theme.dialFont(side * 0.5, .bold))
                        .foregroundStyle(theme.warn)
                        .contentTransition(.numericText())
                }
                if model.placementKind != nil {
                    // Mise en place faite : il n'y a plus qu'à attendre le départ
                    Text("Ne bouge plus")
                        .font(theme.font(13))
                        .foregroundStyle(theme.ok)
                } else {
                    Text("Mets-toi en position")
                        .font(theme.font(13))
                        .foregroundStyle(theme.text)
                    placementText(model.exercise)
                }
            case .active where model.isResting:
                // Un segment par tranche de 15 s (avec le bip), jusqu'au repos prévu, puis vert
                let planned = plannedRest
                let slices = max(1, planned / Self.restSlice)
                let done = model.restDuration >= Double(planned)
                let color = done ? theme.ok : theme.warn
                Dial(face: CounterDialFace(lit: min(Int(model.restDuration) / Self.restSlice, slices), segments: slices, color: color)) { side in
                    VStack(spacing: side * 0.03) {
                        Text(Format.clock(model.restDuration))
                            .font(theme.dialFont(side * 0.24, .bold))
                            .foregroundStyle(color)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        MonitorLabel("sur \(Format.clock(Double(planned)))")
                    }
                    .padding(side * 0.2)
                }
                // La reprise automatique s'explique une fois (première séance), pas à chaque repos
                if let step = coachCard { CoachCard(step: step) }
                if let planDay = model.planDay {
                    nextSetLine(planDay)
                    SetRow(planDay: planDay, done: model.sets.map(\.reps), current: nil)
                } else {
                    setsLog
                }
            case .active:
                let counting = model.state == .counting
                let done = counting ? model.setReps : model.tentative
                let target = counting ? seriesTarget : nil
                let reached = target.map { done >= $0 } ?? false
                Dial(face: CounterDialFace(lit: CounterDial.lit(done),
                                           color: reached ? theme.ok : (counting ? theme.primary : theme.primary.opacity(0.42)),
                                           goalSegment: CounterDial.goalSegment(done: done, target: target),
                                           live: model.live, palePulse: !counting),
                     pulse: counting ? nil : model.tentativePulse) { side in
                    dialCount(side: side, counting: counting)
                }
                if let planDay = model.planDay {
                    SetRow(planDay: planDay, done: model.sets.map(\.reps), current: counting ? model.setReps : nil)
                } else if counting || model.totalReps > 0 {
                    statsLine
                }
                if !counting, let step = coachCard { CoachCard(step: step) }
            case .finished:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// « Fatigue ? » avant la première séance du jour (et toute la journée une fois répondu),
    /// à partir de la 4e séance, tant que les questions de ressenti sont actives.
    private var asksFatigue: Bool {
        guard Feeling.asks(after: sessions.count) else { return false }
        return fatigue != nil || !sessions.contains { Calendar.current.isDateInToday($0.start) }
    }

    /// Charge (Biceps, Développé), réglée avant de démarrer : l'équipement (1 haltère,
    /// 2 haltères, barre ; une touche passe au suivant) et le poids d'un haltère ou de la barre
    /// (un appui long fait défiler). Sa place est réservée pour tous les exercices : le cadran
    /// ne bouge pas.
    private var loadControl: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.snappy(duration: 0.15)) { loadKind = loadKind.next }
            } label: {
                HStack(spacing: 4) {
                    Text(loadKind.title.uppercased())
                        .font(theme.font(11, .bold))
                        .tracking(1)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(theme.primary)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.primary.opacity(0.5), lineWidth: 1))
                .frame(height: 44)
                .contentShape(Rectangle())
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Équipement : \(loadKind.title)")
            loadButton("minus", step: -0.5)
            Text(loadKind.describe(load))
                .font(theme.font(15, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .frame(minWidth: 84)
            loadButton("plus", step: 0.5)
        }
        .frame(height: 44)
        .opacity(browsing.isWeighted ? 1 : 0)
        .allowsHitTesting(browsing.isWeighted)
        .accessibilityHidden(!browsing.isWeighted)
        .sensoryFeedback(.selection, trigger: loadKind)
        .sensoryFeedback(.selection, trigger: load)
        .animation(.easeInOut(duration: 0.2), value: browsing.isWeighted)
    }

    private func loadButton(_ systemImage: String, step: Double) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.15)) { load = min(max(load + step, 0.5), 100) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(step < 0 ? "Alléger" : "Alourdir")
    }

    /// Nombre de la série ; avant la validation, répétitions détectées en pâle et témoins 1/3, 2/3…
    /// Pendant la série : « sur N » (objectif de la série) et une pastille par dizaine.
    private func dialCount(side: CGFloat, counting: Bool) -> some View {
        VStack(spacing: 4) {
            Text(counting ? "\(model.setReps)" : (model.tentative > 0 ? "\(model.tentative)" : "–"))
                .font(theme.dialFont(side * 0.36, .bold))
                .tracking(-side * 0.01)
                .foregroundStyle(counting ? theme.text : (model.tentative > 0 ? theme.primary.opacity(0.5) : theme.dim))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .scaleEffect(bump && !reduceMotion ? 1.08 : 1)
                .opacity(bump && reduceMotion ? 0.75 : 1)
            if counting, let target = seriesTarget {
                MonitorLabel("sur \(target)", color: model.setReps >= target ? theme.ok : theme.dim)
                LapDots(target: target, done: model.setReps)
                    .padding(.top, 2)
            } else if counting {
                MonitorLabel("reps")
            } else {
                HStack(spacing: 6) {
                    ForEach(0..<AutoCounter.cyclesToLock, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < model.tentative ? theme.primary : theme.line)
                            .frame(width: 16, height: 6)
                    }
                }
                .padding(.vertical, 4)
                MonitorLabel(model.tentative > 0 ? "à valider" : "en attente du mouvement")
            }
        }
        .padding(side * 0.2)
    }

    // MARK: - Objectif de série, repos prévu

    /// Tranche de récupération : un segment, un bip.
    private static let restSlice = 15

    /// Séances récentes de l'exercice (4 dernières semaines), hors séance en cours.
    private var recentSessions: [SessionRecord] {
        let since = Date().addingTimeInterval(-28 * 86_400)
        return sessions.filter { $0.exercise == model.exercise && $0.start > since }
    }

    /// Le plan de l'exercice de la séance, calculé une fois au départ (pas à chaque répétition).
    private var sessionPlan: TrainingPlan? { cachedPlan }

    /// Objectif de la série : la cible du plan pour cette série (réajustée d'après la précédente) ;
    /// jour de test ou toutes les séries prévues faites, aucun ; sans plan, la meilleure série des
    /// 4 dernières semaines (nil sans historique).
    private var seriesTarget: Int? {
        if sessionPlan != nil { return model.currentTarget }
        return recentSessions.map(\.bestSet).max().flatMap { $0 > 0 ? $0 : nil }
    }

    /// Pendant la récupération : la série suivante et sa cible (« Ensuite · série 2 · 25 »), ou
    /// « Dernière série » ; une cible abaissée par la série précédente le dit.
    @ViewBuilder
    private func nextSetLine(_ planDay: WorkoutModel.PlanDay) -> some View {
        let index = planDay.earlierToday.count + model.sets.count
        if let target = model.currentTarget, index < planDay.session.sets {
            let last = index == planDay.session.sets - 1
            HStack(spacing: 6) {
                MonitorLabel(last ? "Dernière série" : "Ensuite · série \(index + 1)")
                Text("\(target)")
                    .font(theme.font(14, .bold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                if target < planDay.session.targets[index] {
                    MonitorLabel("· ! cible réajustée", color: theme.text)
                }
            }
        } else {
            MonitorLabel("Séance faite ✓", color: theme.ok)
        }
    }

    /// Repos prévu, sans plan : ton repos habituel pour l'exercice (médiane des récupérations
    /// des 4 dernières semaines, arrondie à 15 s, entre 30 s et 5 min) ; 60 s sans historique
    /// (la référence du score d'endurance). Choix de l'app.
    private var plannedRest: Int {
        if let rest = sessionPlan?.todaySession?.rest { return rest }
        let rests = recentSessions.flatMap { session in
            (1..<max(session.orderedSets.count, 1)).compactMap { session.rest(before: $0) }
        }
        guard rests.count >= 3 else { return 60 }
        let sorted = rests.sorted()
        let median = sorted[sorted.count / 2]
        let rounded = Int((median / Double(Self.restSlice)).rounded()) * Self.restSlice
        return min(max(rounded, 30), 300)
    }

    /// Consigne de placement, terminée par « Plus de détails » (la fiche, d'une touche). Sa
    /// hauteur est toujours celle de la plus longue consigne : le cadran ne bouge pas d'un
    /// exercice à l'autre. Le changement de texte est un fondu sur place.
    private func placementText(_ exercise: Exercise) -> some View {
        Button { showGuide(exercise) } label: {
            ZStack(alignment: .top) {
                placementLine(Self.longestPlacement)
                    .hidden()
                placementLine(exercise.placement(armband: hasArmband))
                    .id(exercise)
                    .transition(.opacity)
            }
            .frame(maxWidth: 300)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Ouvre la fiche pour placer ton iPhone.")
    }

    private func placementLine(_ text: String) -> some View {
        (Text(text + "  ") + Text(Image(systemName: "questionmark.circle")).foregroundStyle(theme.primary))
            .font(theme.font(13))
            .foregroundStyle(theme.dim)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Ouvre la fiche « Placer ton iPhone » ; `thenStart` : la séance démarre en la refermant.
    private func showGuide(_ exercise: Exercise, thenStart: Bool = false) {
        guideStartsSession = thenStart
        guideExercise = exercise
    }

    /// Carte de la première séance à montrer maintenant (nil : aucune). Une étape à la fois,
    /// dans l'ordre : la détection (1re série), la récupération (après la 1re série), la fin.
    private var coachCard: Int? {
        guard model.phase == .active else { return nil }
        let step: Int
        if model.isResting {
            step = model.sets.count == 1 ? 2 : 3
        } else if model.sets.isEmpty, model.state != .counting {
            step = 1
        } else {
            return nil
        }
        return step == coachStep + 1 ? step : nil
    }

    /// Une étape est acquise quand on a vécu ce qu'elle annonce : la 1re série lancée, une
    /// série reprise après une récupération, une séance de deux séries terminée.
    private func advanceCoach() {
        switch coachStep {
        case 0 where model.state == .counting:
            coachStep = 1
        case 1 where model.phase == .active && !model.sets.isEmpty && model.state == .counting:
            coachStep = 2
        case 2 where model.phase == .finished && model.sets.count >= 2:
            coachStep = 3
        default:
            break
        }
    }

    private static let longestPlacement = Exercise.allCases
        .flatMap { [$0.placement(armband: false), $0.placement(armband: true)] }
        .max { $0.count < $1.count } ?? ""


    /// Une ligne discrète sous le cadran : total de la séance (et régularité en mode analyse).
    private var statsLine: some View {
        HStack(spacing: 18) {
            stat("Total", "\(model.totalReps)")
            if analysisMode {
                stat("Régul.", model.regularity > 0 ? "\(Int((model.regularity * 100).rounded()))" : "—", unit: "%")
            }
        }
    }

    private func stat(_ label: String, _ value: String, unit: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(label.uppercased())
                .font(theme.font(12))
                .tracking(1)
                .foregroundStyle(theme.dim)
            Text(value)
                .font(theme.font(15, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
            if let unit {
                Text(unit)
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
            }
        }
    }

    /// Dernières séries sur une ligne fixe ; les plus anciennes sont résumées par « +N ».
    private var setsLog: some View {
        let shown = model.sets.suffix(Self.setsShown)
        let hidden = model.sets.count - shown.count
        return HStack(spacing: 6) {
            if hidden > 0 { setChip(label: "+\(hidden)", value: nil, latest: false) }
            ForEach(shown) { set in
                setChip(label: String(format: "S%02d", set.number), value: "\(set.reps)", latest: set.id == model.sets.last?.id)
            }
        }
    }

    private static let setsShown = 4

    private func setChip(label: String, value: String?, latest: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(theme.dim)
            if let value { Text(value).foregroundStyle(theme.text) }
        }
        .font(theme.font(12, .bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(latest ? theme.warn.opacity(0.6) : theme.line, lineWidth: 1))
    }

    // MARK: - Commandes

    @ViewBuilder
    private var bottom: some View {
        switch model.phase {
        case .ready:
            if model.cameraDenied {
                cameraDenied
            } else {
                VStack(spacing: 12) {
                    signalStrip
                    Button("Démarrer") { start() }
                        .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 64))
                }
            }
        case .positioning, .countdown:
            Button("Annuler") { model.cancelCountdown() }
                .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 52))
        case .active:
            // Pendant l'effort : deux commandes discrètes ; Terminer se maintient (pas de fin par erreur)
            HStack(spacing: 10) {
                Button("Annuler série") { model.cancelSet() }
                    .buttonStyle(MonitorButtonStyle(color: theme.warn, filled: false, height: 50, fontSize: 12))
                    .disabled(model.setReps == 0 && model.sets.isEmpty)
                HoldButton(title: "Terminer", color: theme.alarm) { model.finishSession() }
            }
        case .finished:
            EmptyView()
        }
    }

    /// Démarrer. La première fois pour un exercice, la fiche « Placer ton iPhone » d'abord.
    /// Si l'exercice affiché n'est pas encore adopté (Démarrer touché juste après un
    /// glissement), il l'est tout de suite, et sa séance démarre dès son affichage.
    /// `exercise` : un autre exercice que celui affiché (Démarrer du Coaching, de la fiche).
    private func start(_ exercise: Exercise? = nil) {
        let exercise = exercise ?? browsing
        if !PlacementGuide(exercise: exercise, armband: hasArmband).seen {
            showGuide(exercise, thenStart: true)
            return
        }
        if exercise != model.exercise {
            pendingSelection?.cancel()
            onSelectExercise(exercise, true)
        } else {
            model.beginSession()
        }
    }

    /// Tracé du mouvement capté, pour se placer avant de démarrer, et un voyant d'état (pas une
    /// alerte) : gris au repos, couleur principale pour un léger mouvement, vert quand il est
    /// assez net pour être compté.
    private var signalStrip: some View {
        VStack(spacing: 4) {
            // Le voyant est collé au capteur qu'il décrit ; ses mots ne servent qu'à VoiceOver
            HStack(spacing: 6) {
                StatusLED(color: presenceColor)
                MonitorLabel("Mouvement · \(model.source?.code ?? model.exercise.sensorTag)")
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityValue(presenceText)
            SignalTrace(live: model.live)
                .frame(height: 46)
        }
    }

    private var presenceColor: Color {
        switch model.presence {
        case .absent: return theme.dim
        case .weak: return theme.primary
        case .clear: return theme.ok
        }
    }

    private var presenceText: String {
        switch model.presence {
        case .absent: return "Au repos"
        case .weak: return "Léger"
        case .clear: return "Net"
        }
    }

    // MARK: - Enregistrement et diagnostic

    private var recordingBanner: some View {
        HStack(spacing: 8) {
            StatusLED(color: theme.alarm)
            MonitorLabel("Enregistrement \(Format.clock(model.recordingDuration))", color: theme.alarm)
            Spacer()
            MonitorLabel("■ pour arrêter")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.alarm.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.alarm.opacity(0.5), lineWidth: 1))
    }

    /// Ce que voit chaque capteur : amplitude du mouvement par rapport au seuil,
    /// cycles détectés, note de régularité (il faut ≥ 0,60 pour démarrer).
    private var diagnosticsPanel: some View {
        MonitorPanel("Diagnostic · \(Int(model.framesPerSecond.rounded())) mesures/s") {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(model.diagnostics, id: \.source) { item in
                    HStack(spacing: 8) {
                        Text(item.source.code)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("ampl \(Int((100 * item.amplitude / item.source.minAmplitude).rounded()))%")
                            .foregroundStyle(item.amplitude >= item.source.minAmplitude ? theme.ok : theme.dim)
                        Text("\(item.cycles) cyc")
                        Text(String(format: "rég %.2f", item.regularity))
                            .foregroundStyle(item.regularity >= 0.6 ? theme.ok : theme.dim)
                    }
                    .font(theme.font(11))
                    .foregroundStyle(theme.text)
                }
                if model.diagnostics.isEmpty {
                    MonitorLabel("En attente de mesures")
                }
            }
        }
    }

    /// Caméra refusée : à la place de Démarrer, de quoi l'autoriser. Le cadran reste
    /// utilisable pour glisser vers un exercice sans caméra.
    private var cameraDenied: some View {
        VStack(spacing: 12) {
            HStack(spacing: 5) {
                StatusLED(color: theme.alarm)
                MonitorLabel("Accès caméra refusé", color: theme.alarm)
            }
            Text(model.exercise.isArmExercise ? "Rien n'est filmé. Ou passe au brassard (Réglages)."
                                              : "Rien n'est filmé, rien n'est enregistré.")
                .font(theme.font(12))
                .foregroundStyle(theme.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Autoriser la caméra") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 64))
        }
    }
}

// MARK: - Cadran

/// Couleurs des graduations du cadran.
enum DialPalette {
    /// Mouvement suivi, pas encore validé.
    case pale
    /// Comptage : dégradé de la couleur secondaire à la principale.
    case gradient
    /// Une seule couleur (compte à rebours, récupération, fin).
    case solid(Color)
}

/// 60 graduations, dont les `lit` premières sont allumées (sens horaire depuis midi).
struct DialFace: View {
    @Environment(\.theme) private var theme
    static let tickCount = 60
    let lit: Int
    let palette: DialPalette

    var body: some View {
        let colors = tickColors
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 3
            for i in 0..<Self.tickCount {
                let angle = Double(i) / Double(Self.tickCount) * 2 * .pi - .pi / 2
                let major = i % 5 == 0
                let inner = outer * (major ? 0.88 : 0.935)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner, y: center.y + CGFloat(sin(angle)) * inner))
                tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer, y: center.y + CGFloat(sin(angle)) * outer))
                context.stroke(tick, with: .color(colors[i]),
                               style: StrokeStyle(lineWidth: major ? 3.4 : 2.2, lineCap: .round))
            }
        }
        .shadow(color: glowColor.opacity(0.45 * min(theme.glow, 1)), radius: 10)
    }

    private var tickColors: [Color] {
        (0..<Self.tickCount).map { i in
            let on = i < lit
            switch palette {
            case .pale: return on ? theme.primary.opacity(0.42) : theme.line
            case .gradient: return on ? theme.secondary.mixed(with: theme.primary, by: Double(i) / Double(Self.tickCount - 1)) : theme.line
            case .solid(let color): return on ? color : theme.line
            }
        }
    }

    private var glowColor: Color {
        switch palette {
        case .pale: return .clear
        case .gradient: return theme.primary
        case .solid(let color): return color
        }
    }
}

/// Cadran carré, aussi grand que la place le permet (350 pt au plus), avec son contenu au centre.
/// `pulse` : une onde part du centre à chaque changement (répétition détectée, pas encore validée).
struct Dial<Face: View, Center: View>: View {
    let face: Face
    var pulse: Int? = nil
    @ViewBuilder let center: (CGFloat) -> Center

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                face
                if let pulse { Ripple(pulse: pulse).padding(side * 0.08) }
                center(side)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 350)
    }
}

/// Onde : invisible au repos (déployée et transparente), relancée à chaque changement de `pulse`.
private struct Ripple: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pulse: Int
    @State private var expanded = true

    var body: some View {
        Circle()
            .stroke(theme.primary, lineWidth: 2)
            // Réduire les animations : l'onde ne grandit plus, elle s'efface sur place
            .scaleEffect(reduceMotion || expanded ? 1.0 : 0.55)
            .opacity(expanded ? 0 : 0.8)
            .onChange(of: pulse) {
                var reset = Transaction()
                reset.disablesAnimations = true
                withTransaction(reset) { expanded = false }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.7)) { expanded = true }
                }
            }
    }
}

/// Bouton à maintenir 0,8 s : une jauge se remplit sous le doigt, l'action part au bout.
/// Évite de terminer une séance par un appui involontaire.
private struct HoldButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let color: Color
    let action: () -> Void
    @State private var progress: CGFloat = 0
    /// Maintiens menés au bout (retour haptique de succès).
    @State private var completions = 0
    private static let duration = 0.8

    var body: some View {
        VStack(spacing: 3) {
            Text(title.uppercased())
                .font(theme.font(12, .bold))
                .tracking(1.5)
            Text("MAINTENIR")
                .font(theme.font(8, .semibold))
                .tracking(1.5)
                .opacity(0.75)
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(alignment: .leading) {
            GeometryReader { geometry in
                Rectangle()
                    .fill(color.opacity(0.28))
                    .frame(width: geometry.size.width * progress)
            }
        }
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(color.opacity(0.6), lineWidth: 1))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: Self.duration, maximumDistance: 40) {
            completions += 1
            progress = 0
            action()
        } onPressingChanged: { pressing in
            if pressing {
                withAnimation(.linear(duration: Self.duration)) { progress = 1 }
            } else {
                withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
        .sensoryFeedback(.success, trigger: completions)
    }
}

/// Tracé des 8 dernières secondes du signal suivi, façon électrocardiogramme apaisé : plat
/// sans mouvement, ample et lumineux quand le geste est net. Courbe lissée, qui s'estompe
/// vers la gauche : le passé compte moins que l'instant.
private struct SignalTrace: View {
    @Environment(\.theme) private var theme
    @ObservedObject var live: LiveSignal

    var body: some View {
        let presence = Double(min(max(live.strength, 0), 1))
        Canvas { context, size in
            let samples = live.samples
            guard samples.count > 1 else { return }
            let points = samples.enumerated().map { i, value in
                CGPoint(x: size.width * CGFloat(i) / CGFloat(samples.count - 1),
                        y: 4 + (size.height - 8) * (1 - CGFloat(value)))
            }
            // Courbe passant par le milieu des segments : pas d'angles
            var path = Path()
            path.move(to: points[0])
            for i in 1..<points.count - 1 {
                let middle = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
                path.addQuadCurve(to: middle, control: points[i])
            }
            path.addLine(to: points[points.count - 1])
            let fade = Gradient(stops: [.init(color: theme.primary.opacity(0), location: 0),
                                        .init(color: theme.primary.opacity(0.7), location: 0.5),
                                        .init(color: theme.primary, location: 1)])
            context.stroke(path, with: .linearGradient(fade, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                           style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // Point à la dernière mesure
            let last = points[points.count - 1]
            context.fill(Path(ellipseIn: CGRect(x: last.x - 7, y: last.y - 3.5, width: 7, height: 7)), with: .color(theme.primary))
        }
        .opacity(0.35 + 0.65 * presence)
        .shadow(color: theme.primary.opacity(0.4 * presence * min(theme.glow, 1)), radius: 4)
    }
}

// MARK: - Fin de séance

/// Le total dans le cadran, l'écart avec la séance précédente et les records battus, les séries
/// (une touche sur une barre pour corriger son compte), trois mesures (score d'endurance, forme,
/// durée), et « Nouvelle séance ». Après un record, une seule fois : la note App Store, puis le don.
private struct SessionSummary: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var tipJar: TipJar
    @ObservedObject var model: WorkoutModel
    /// La séance enregistrée (nil si aucune répétition).
    let record: SessionRecord?
    @Query(sort: \SessionRecord.start, order: .reverse) private var history: [SessionRecord]
    @State private var editing: Int?
    /// Corrections − / + d'une série (retour haptique léger).
    @State private var corrections = 0
    @State private var showsTipPrompt = false
    @State private var showsSupport = false

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Dial(face: DialFace(lit: DialFace.tickCount, palette: .gradient)) { side in
                VStack(spacing: 6) {
                    Text("\(total)")
                        .font(theme.dialFont(side * 0.4, .bold))
                        .tracking(-side * 0.01)
                        .foregroundStyle(LinearGradient(colors: [theme.secondary, theme.primary],
                                                        startPoint: .leading, endPoint: .trailing))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                    MonitorLabel("\(model.exercise.shortTitle) · répétitions")
                }
                .padding(side * 0.14)
            }
            .frame(maxWidth: 236)

            if let record {
                highlights(record)
                SetBars(sets: record.orderedSets.map(\.reps), recordIndex: recordSetIndex(record), editing: editing) { index in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { editing = editing == index ? nil : index }
                }
                .frame(height: 100)
                corrector(record)
            } else {
                MonitorLabel("Aucune série comptée")
            }

            if let record {
                HStack {
                    enduranceStat(record)
                    if record.exercise != .auto { formStat(record) }
                    summaryStat("Durée", Format.clock(record.duration))
                }
                .padding(.top, 12)
                .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
                planResult(record)
                phaseLine(record)
            }
            Spacer(minLength: 0)

            if let record, asksFeeling(record) {
                EffortQuestion(record: record)
            }
            if showsTipPrompt {
                TipPrompt(onSupport: { showsSupport = true },
                          onDismiss: { withAnimation { showsTipPrompt = false } })
                    .transition(.opacity)
            }
            Button("Nouvelle séance") { model.newSession() }
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 58))
        }
        .task(id: record?.persistentModelID) { await askIfDue() }
        .onDisappear {
            // Ressenti : sans aucune réponse plusieurs séances de suite, on ne demande plus
            if let record, asksFeeling(record) {
                Feeling.sessionEnded(answered: record.effort != nil || record.fatigueScore != nil)
            }
        }
        .sheet(isPresented: $showsSupport, onDismiss: { showsTipPrompt = false }) {
            SupportView()
                .environmentObject(tipJar)
                .systemSheet()
        }
        .sensoryFeedback(.selection, trigger: editing)
        .sensoryFeedback(.impact(weight: .light), trigger: corrections)
    }

    /// Après un record : la note App Store (dès la 5e séance), puis, à un record suivant, le don
    /// (dès la 10e). Une seule fois chacun.
    @MainActor
    private func askIfDue() async {
        guard let record else { return }
        // La séance vient d'être enregistrée : on compte celles d'avant, plus elle
        let sessions = history.filter { $0.start < record.start }.count + 1
        let beatRecord = recordSetIndex(record) != nil
            || earlier(record).map(\.totalReps).max().map { record.totalReps > $0 } == true
        guard let ask = Ask.next(sessions: sessions, beatRecord: beatRecord) else { return }
        // Laisser le temps de voir le record avant de demander
        try? await Task.sleep(for: .seconds(1.5))
        guard !Task.isCancelled else { return }
        ask.markAsked()
        switch ask {
        case .review: requestReview()
        case .tip: withAnimation { showsTipPrompt = true }
        }
    }

    /// « Effort ? » : à partir de la 4e séance, tant que les questions de ressenti sont actives.
    private func asksFeeling(_ record: SessionRecord) -> Bool {
        Feeling.asks(after: history.filter { $0.start < record.start }.count)
    }

    /// Le plan, s'il y a un objectif : prévu face au fait série par série, et la place de la
    /// séance dans la semaine ; jour de test, le résultat (mesuré, attendu, gain depuis le départ).
    @ViewBuilder
    private func planResult(_ record: SessionRecord) -> some View {
        let before = history.filter { $0.start < record.start }
        let plan = Goal.load(record.exercise) == nil && PlanAnchor.load(record.exercise) == nil ? nil
            : HistoryStats(sessions: before, exercise: record.exercise, now: record.start).plan(all: before)
        if let plan {
            let sets = record.orderedSets.map(\.reps)
            VStack(spacing: 6) {
                if plan.today == .test {
                    planRow("Test · bloc \(plan.block)", "\(record.bestSet) d'affilée", color: theme.ok)
                    if let expected = plan.expected(at: record.start) {
                        planRow("Attendu", "\(Int(expected.rounded()))", color: theme.text)
                    }
                    // Sans objectif, pas de départ : le gain depuis le test précédent
                    if let start = plan.goal?.start ?? plan.tests.last?.value {
                        planRow(plan.goal != nil ? "Depuis le départ" : "Depuis le test", Format.signed(record.bestSet - start), color: theme.text)
                    }
                } else if let planned = plan.todaySession {
                    // Séries espacées dans la journée : elles comptent toutes dans le fait du jour
                    let earlierToday = before.filter { $0.exercise == record.exercise && Calendar.current.isDate($0.start, inSameDayAs: record.start) }
                    let dayReps = earlierToday.reduce(record.totalReps) { $0 + $1.totalReps }
                    let done = dayReps >= planned.total
                    planRow("Prévu", "\(planned.label) = \(planned.total)", color: theme.text)
                    planRow(earlierToday.isEmpty ? "Fait" : "Fait · séries espacées",
                            sets.map(String.init).joined(separator: " · ") + (done ? " ✓" : ""),
                            color: done ? theme.ok : theme.text)
                    if let week = plan.currentWeek {
                        Text("séance \(week.done + (earlierToday.isEmpty ? 1 : 0)) / \(week.plannedSessions) de la semaine")
                            .font(theme.font(11))
                            .foregroundStyle(theme.dim)
                    }
                }
                nextSession(record)
            }
        }
    }

    /// La prochaine séance prévue, après celle-ci : « Prochaine · vendredi · 29 · 25 · 22 ».
    @ViewBuilder
    private func nextSession(_ record: SessionRecord) -> some View {
        let upTo = history.filter { $0.start <= record.start }
        if let plan = HistoryStats(sessions: upTo, exercise: record.exercise, now: record.end.addingTimeInterval(1)).plan(all: upTo),
           let next = plan.next {
            planRow("Prochaine · \(Format.weekdayOrDate(next))", plan.today.short, color: theme.dim)
        }
    }

    private func planRow(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            MonitorLabel(label)
            Spacer(minLength: 8)
            Text(symbols: value)
                .font(theme.font(13, .bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    /// La phase, seulement quand elle appelle une action : rebond (prêt pour un record) ou
    /// décharge conseillée.
    @ViewBuilder
    private func phaseLine(_ record: SessionRecord) -> some View {
        let phase = HistoryStats(sessions: history, exercise: record.exercise).phase(all: history)
        if record.exercise != .auto, phase.kind == .rebound || phase.kind == .deloadAdvised {
            HStack(spacing: 8) {
                Circle().fill(phase.color(theme)).frame(width: 8, height: 8)
                Text(symbols: phase.marked)
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
                Text(phase.action())
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Ouvre un ticket GitHub pré-rempli avec les séries corrigées.
    private func report(_ record: SessionRecord) {
        let sets = record.orderedSets.map { (counted: $0.countedReps, actual: $0.reps) }
        if let url = CountReport.url(exercise: record.exercise.title, sets: sets) { openURL(url) }
    }

    private var total: Int { record?.totalReps ?? model.totalReps }

    /// Score d'endurance, ou où l'on en est : il faut 3 séries.
    private func enduranceStat(_ record: SessionRecord) -> some View {
        if let index = record.performanceIndex {
            return summaryStat("Score endurance", "\(Int(index.rounded()))")
        }
        let sets = record.orderedSets.count
        return summaryStat("Score endurance", sets < SessionRecord.indexSets ? "\(sets) / \(SessionRecord.indexSets) séries" : "—",
                           pending: true)
    }

    /// Forme de la séance, par rapport aux précédentes du même exercice ; tant que la référence
    /// se construit, où l'on en est.
    private func formStat(_ record: SessionRecord) -> some View {
        let stats = HistoryStats(sessions: history, exercise: record.exercise)
        guard stats.countingIsReliable else {
            return summaryStat("Forme", "comptage à fiabiliser", pending: true)
        }
        if let form = stats.form(of: record) {
            return summaryStat("Forme", "\(Int(form.percent.rounded()))", unit: "%", color: formColor(form.zone, theme: theme))
        }
        guard record.formMeasure != nil else {
            return summaryStat("Forme", "séries courtes", pending: true)
        }
        let collected = min(earlier(record).filter { $0.formMeasure != nil }.count + 1, FormResult.baselineSessions)
        return summaryStat("Forme", "réf. \(collected) / \(FormResult.baselineSessions)", pending: true)
    }

    /// Séances précédentes du même exercice.
    private func earlier(_ record: SessionRecord) -> [SessionRecord] {
        history.filter { $0.exercise == record.exercise && $0.start < record.start }
    }

    /// Série qui bat le record de série de l'exercice (la meilleure de la séance), s'il y en a un.
    private func recordSetIndex(_ record: SessionRecord) -> Int? {
        let before = earlier(record)
        guard let previousBest = before.map(\.bestSet).max(), record.bestSet > previousBest else { return nil }
        return record.orderedSets.firstIndex { $0.reps == record.bestSet }
    }

    /// Pastilles : écart avec la séance précédente, record battu.
    @ViewBuilder
    private func highlights(_ record: SessionRecord) -> some View {
        let before = earlier(record)
        HStack(spacing: 10) {
            if let previous = before.first {
                let delta = record.totalReps - previous.totalReps
                pill(delta >= 0 ? "▲ +\(delta) vs \(Format.dayName(previous.start))" : "▼ \(delta) vs \(Format.dayName(previous.start))",
                     color: delta >= 0 ? theme.ok : theme.dim)
            } else {
                pill("Première séance", color: theme.primary)
            }
            if let best = before.map(\.totalReps).max(), record.totalReps > best {
                pill("Record de séance", color: theme.warn, star: true)
            } else if recordSetIndex(record) != nil {
                pill("Record de série", color: theme.warn, star: true)
            }
        }
    }

    private func pill(_ text: String, color: Color, star: Bool = false) -> some View {
        HStack(spacing: 5) {
            if star { Image(systemName: "star.fill").font(.system(size: 10, weight: .bold)) }
            Text(symbols: text)
        }
        .font(theme.font(12, .bold))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    /// Correction du compte d'une série, ou l'invitation à le faire.
    @ViewBuilder
    private func corrector(_ record: SessionRecord) -> some View {
        let sets = record.orderedSets
        if let editing, editing < sets.count {
            let set = sets[editing]
            HStack(spacing: 14) {
                MonitorLabel("Série \(String(format: "%02d", editing + 1))", color: theme.text)
                stepButton("minus") { set.reps = max(0, set.reps - 1) }
                Text("\(set.reps)")
                    .font(theme.font(22, .bold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 34)
                stepButton("plus") { set.reps += 1 }
                Text("compté : \(set.countedReps)")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96)))
        } else if SourceCode.isPublic, sets.contains(where: { $0.reps != $0.countedReps }) {
            // Un compte corrigé : proposer de le signaler, pour améliorer le compteur
            Button { report(record) } label: {
                Text("Le compte était faux ? **Signale-le**")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        } else if history.count <= 3 {
            // Montrée aux premières séances seulement : ensuite, on sait
            Text("Touche une série pour la corriger")
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .transition(.opacity)
        }
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            corrections += 1
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    /// Une mesure ; `pending` : un état « en cours » (plus petit, atténué) à la place d'une valeur.
    private func summaryStat(_ label: String, _ value: String, unit: String? = nil, color: Color? = nil,
                             pending: Bool = false) -> some View {
        VStack(spacing: 4) {
            MonitorLabel(label)
                .minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(theme.font(pending ? 13 : 18, .semibold))
                    .foregroundStyle(pending ? theme.dim : color ?? theme.text)
                    .monospacedDigit()
                if let unit {
                    Text(unit)
                        .font(theme.font(10))
                        .foregroundStyle(theme.dim)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Histogramme des séries : une barre par série, sans défilement (les libellés s'effacent
/// quand les séries sont trop nombreuses pour les lire). Une touche sur une barre la sélectionne.
struct SetBars: View {
    @Environment(\.theme) private var theme
    let sets: [Int]
    var recordIndex: Int? = nil
    var editing: Int? = nil
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        let most = max(sets.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: sets.count > 12 ? 4 : 10) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, reps in
                let selected = index == editing, record = index == recordIndex
                VStack(spacing: 6) {
                    if sets.count <= 12 {
                        HStack(spacing: 2) {
                            if record { Image(systemName: "star.fill").font(.system(size: 8, weight: .bold)) }
                            Text("\(reps)").contentTransition(.numericText())
                        }
                        .font(theme.font(13, .bold))
                        .foregroundStyle(record ? theme.warn : theme.text)
                    }
                    UnevenBar(radius: min(theme.radius, 4))
                        .fill(selected
                              ? AnyShapeStyle(theme.text)
                              : AnyShapeStyle(LinearGradient(colors: [theme.primary, theme.secondary.opacity(0.85)],
                                                             startPoint: .top, endPoint: .bottom)))
                        .frame(maxWidth: 38)
                        .frame(height: max(2, 64 * CGFloat(reps) / CGFloat(most)))
                        .shadow(color: theme.primary.opacity(0.3 * min(theme.glow, 1)), radius: 8)
                    if sets.count <= 10 {
                        Text(String(format: "S%02d", index + 1))
                            .font(theme.font(10))
                            .foregroundStyle(selected ? theme.text : theme.dim)
                    }
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { onSelect?(index) }
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// Barre arrondie en haut seulement.
struct UnevenBar: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(radius, rect.width / 2, rect.height)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Fin d'enregistrement

/// Fin d'un enregistrement : nombre de répétitions réellement faites, puis partage du fichier.
private struct RecordingSheet: View {
    @Environment(\.theme) private var theme
    let finished: FinishedRecording
    @Environment(\.dismiss) private var dismiss
    @State private var actualReps: Int
    @State private var savedURL: URL?

    init(finished: FinishedRecording) {
        self.finished = finished
        _actualReps = State(initialValue: finished.countedReps)
    }

    var body: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(theme.line)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            MonitorLabel("Enregistrement terminé", color: theme.alarm)
            Text("Compté par l'app : \(finished.countedReps)")
                .font(theme.font(14))
                .foregroundStyle(theme.dim)

            MonitorPanel("Répétitions réellement faites") {
                HStack(spacing: 24) {
                    stepButton("minus") { actualReps = max(0, actualReps - 1) }
                    Text("\(actualReps)")
                        .font(theme.font(56, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                        .frame(minWidth: 90)
                    stepButton("plus") { actualReps += 1 }
                }
                .frame(maxWidth: .infinity)
            }

            if let savedURL {
                ShareLink(item: savedURL) {
                    Label("Partager l'enregistrement", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(MonitorButtonStyle(color: theme.primary))
                Text("Aussi dans Fichiers › Sur mon iPhone › Reps › Recordings.")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
                Button("Fermer") { dismiss() }
                    .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false))
            } else {
                Button("Valider") {
                    finished.recorder.finish(countedReps: finished.countedReps, actualReps: actualReps)
                    savedURL = finished.recorder.url
                }
                .buttonStyle(MonitorButtonStyle(color: theme.primary))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.fraction(0.75), .large])
        .interactiveDismissDisabled(savedURL == nil)
        .preferredColorScheme(theme.colorScheme)
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 52, height: 52)
                .background(theme.panel, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.line, lineWidth: 1))
        }
    }
}
