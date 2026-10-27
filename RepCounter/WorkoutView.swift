import SwiftData
import SwiftUI

/// L'écran unique de l'app : le cadran. En veille, on y glisse d'un exercice à l'autre ;
/// pendant l'effort, il n'affiche que le nombre ; en récupération, le chronomètre ; à la fin,
/// le total. Tout le reste est rangé dans les Réglages.
struct WorkoutView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var themeStore: ThemeStore
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model: WorkoutModel
    @AppStorage(SettingsView.analysisModeKey) private var analysisMode = false
    @AppStorage(Exercise.armbandKey) private var hasArmband = false
    @State private var bump = false
    @State private var showsHistory = false
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

    /// Délai sans geste avant d'adopter l'exercice affiché : passer vite de Pompes à Biceps
    /// n'allume pas et n'éteint pas la caméra à chaque étape.
    private static let selectionDelay = 0.4

    init(exercise: Exercise, exercises: [Exercise], startsSession: Bool = false,
         onOpenSettings: @escaping () -> Void, onRebuild: @escaping () -> Void,
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
        .onChange(of: load) { browsing.load = $0 }
        .onChange(of: loadKind) { browsing.loadKind = $0 }
        .onChange(of: browsing) { exercise in
            load = exercise.load
            loadKind = exercise.loadKind
            pendingSelection?.cancel()
            guard exercise != model.exercise else { return }
            let selection = DispatchWorkItem { onSelectExercise(exercise, false) }
            pendingSelection = selection
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.selectionDelay, execute: selection)
        }
        .onChange(of: model.repPulse) { _ in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bump = false }
            }
        }
        .animation(.easeInOut(duration: 0.35), value: model.phase)
        .animation(.easeInOut(duration: 0.35), value: model.isResting)
        .animation(.easeInOut(duration: 0.35), value: model.state)
        .sheet(item: $model.finishedRecording) { finished in
            RecordingSheet(finished: finished)
                .environment(\.theme, theme)
        }
        .onChange(of: model.phase) { phase in
            // Séance terminée : enregistrée aussitôt ; nouvelle séance : on repart de rien
            if phase == .finished {
                record = SessionRecord.save(model, load: model.exercise.load, loadKind: model.exercise.loadKind, in: modelContext)
            } else if phase == .ready {
                record = nil
                rebuildIfNeeded()
            }
        }
        .onChange(of: hasArmband) { _ in rebuildIfNeeded() }
        .sheet(isPresented: $showsHistory) {
            HistoryView(exercise: model.exercise)
                .environment(\.theme, themeStore.current)
                .preferredColorScheme(themeStore.current.colorScheme)
        }
    }

    /// Brassard déclaré ou retiré pour un exercice de bras : l'écran est recréé avec les bons
    /// capteurs, mais seulement en veille. Une séance en cours ou terminée (son résumé) reste
    /// affichée ; le changement s'applique à la nouvelle séance.
    private func rebuildIfNeeded() {
        guard model.exercise.isArmExercise, hasArmband != builtWithArmband, model.phase == .ready else { return }
        onRebuild()
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
                IconButton(systemImage: "gearshape", color: theme.dim) { onOpenSettings() }
            }
        }
        .frame(height: 44)
    }

    private var statusText: String {
        switch model.phase {
        case .ready: return ""
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
                Dial(face: LiveDialFace(live: model.live, palette: .idle)) { side in
                    ExerciseCarousel(selection: $browsing, exercises: exercises, side: side)
                }
                placementText(browsing)
                loadControl
            case .countdown(let remaining):
                let elapsed = Double(WorkoutModel.countdownSeconds - remaining) / Double(WorkoutModel.countdownSeconds)
                Dial(face: DialFace(lit: Int(elapsed * Double(DialFace.tickCount)), palette: .solid(theme.warn))) { side in
                    Text("\(remaining)")
                        .font(theme.font(side * 0.5, .bold))
                        .foregroundStyle(theme.warn)
                        .contentTransition(.numericText())
                }
                Text("Mets-toi en position")
                    .font(theme.font(13))
                    .foregroundStyle(theme.text)
                placementText(model.exercise)
            case .active where model.isResting:
                let seconds = Int(model.restDuration)
                Dial(face: DialFace(lit: seconds % 60 == 0 && seconds > 0 ? 60 : seconds % 60, palette: .solid(theme.warn))) { side in
                    VStack(spacing: side * 0.03) {
                        Text(Format.clock(model.restDuration))
                            .font(theme.font(side * 0.3, .bold))
                            .foregroundStyle(theme.warn)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        MonitorLabel("Série \(String(format: "%02d", model.sets.count)) · \(model.sets.last?.reps ?? 0) reps",
                                     color: theme.text)
                    }
                    .padding(side * 0.14)
                }
                Text("La série suivante démarre dès que tu reprends.")
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .multilineTextAlignment(.center)
                setsLog
            case .active:
                let counting = model.state == .counting
                Dial(face: LiveDialFace(live: model.live, palette: counting ? .gradient : .pale),
                     pulse: counting ? nil : model.tentativePulse) { side in
                    dialCount(side: side, counting: counting)
                }
                if counting || model.totalReps > 0 { statsLine }
            case .finished:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Charge (Biceps, Développé), réglée avant de démarrer : l'équipement (1 haltère,
    /// 2 haltères, barre ; une touche passe au suivant) et le poids d'un haltère ou de la barre
    /// (un appui long fait défiler). Sa place est réservée pour tous les exercices : le cadran
    /// ne bouge pas.
    private var loadControl: some View {
        HStack(spacing: 10) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
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
        .frame(height: 40)
        .opacity(browsing.isWeighted ? 1 : 0)
        .allowsHitTesting(browsing.isWeighted)
        .accessibilityHidden(!browsing.isWeighted)
        .animation(.easeInOut(duration: 0.2), value: browsing.isWeighted)
    }

    private func loadButton(_ systemImage: String, step: Double) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.snappy(duration: 0.15)) { load = min(max(load + step, 0.5), 100) }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                .contentShape(Rectangle())
        }
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(step < 0 ? "Alléger" : "Alourdir")
    }

    /// Nombre de la série ; avant la validation, répétitions détectées en pâle et témoins 1/3, 2/3…
    private func dialCount(side: CGFloat, counting: Bool) -> some View {
        VStack(spacing: 4) {
            Text(counting ? "\(model.setReps)" : (model.tentative > 0 ? "\(model.tentative)" : "–"))
                .font(theme.font(side * 0.48, .bold))
                .tracking(-side * 0.01)
                .foregroundStyle(counting ? theme.text : (model.tentative > 0 ? theme.primary.opacity(0.5) : theme.dim))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .scaleEffect(bump ? 1.08 : 1)
            if counting {
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
        .padding(side * 0.12)
    }

    /// Consigne de placement. Sa hauteur est toujours celle de la plus longue consigne : le
    /// cadran ne bouge pas d'un exercice à l'autre. Le changement de texte est un fondu sur place.
    private func placementText(_ exercise: Exercise) -> some View {
        ZStack(alignment: .top) {
            placementLine(Self.longestPlacement)
                .hidden()
            placementLine(exercise.placement(armband: hasArmband))
                .id(exercise)
                .transition(.opacity)
        }
        .frame(maxWidth: 300)
    }

    private func placementLine(_ text: String) -> some View {
        Text(text)
            .font(theme.font(12))
            .foregroundStyle(theme.dim)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
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
        case .countdown:
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

    /// Démarrer. Si l'exercice affiché n'est pas encore adopté (Démarrer touché juste après
    /// un glissement), il l'est tout de suite, et sa séance démarre dès son affichage.
    private func start() {
        if browsing != model.exercise {
            pendingSelection?.cancel()
            onSelectExercise(browsing, true)
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
            Text("\(model.exercise.title) utilise la caméra pour te voir ; rien n'est enregistré. "
                 + (model.exercise.isArmExercise
                    ? "Avec un brassard, active « J'ai un brassard » dans les Réglages."
                    : "Glisse sur le cadran pour un exercice sans caméra."))
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
    /// Veille : le cadran est allumé en pâle, le mouvement capté l'éclaire davantage.
    case idle
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
            case .idle: return theme.primary.opacity(on ? 0.6 : 0.2)
            case .pale: return on ? theme.primary.opacity(0.42) : theme.line
            case .gradient: return on ? theme.secondary.mixed(with: theme.primary, by: Double(i) / Double(Self.tickCount - 1)) : theme.line
            case .solid(let color): return on ? color : theme.line
            }
        }
    }

    private var glowColor: Color {
        switch palette {
        case .idle, .pale: return .clear
        case .gradient: return theme.primary
        case .solid(let color): return color
        }
    }
}

/// Le cadran qui suit le mouvement en direct (30 fois par seconde) : seul lui est redessiné.
struct LiveDialFace: View {
    @ObservedObject var live: LiveSignal
    let palette: DialPalette

    var body: some View {
        DialFace(lit: Int((Float(DialFace.tickCount) * live.phase).rounded()), palette: palette)
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
    let pulse: Int
    @State private var expanded = true

    var body: some View {
        Circle()
            .stroke(theme.primary, lineWidth: 2)
            .scaleEffect(expanded ? 1.0 : 0.55)
            .opacity(expanded ? 0 : 0.8)
            .onChange(of: pulse) { _ in
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
/// durée), et « Nouvelle séance ».
private struct SessionSummary: View {
    @Environment(\.theme) private var theme
    @ObservedObject var model: WorkoutModel
    /// La séance enregistrée (nil si aucune répétition).
    let record: SessionRecord?
    @Query(sort: \SessionRecord.start, order: .reverse) private var history: [SessionRecord]
    @State private var editing: Int?

    var body: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            Dial(face: DialFace(lit: DialFace.tickCount, palette: .gradient)) { side in
                VStack(spacing: 6) {
                    Text("\(total)")
                        .font(theme.font(side * 0.4, .bold))
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
                    UISelectionFeedbackGenerator().selectionChanged()
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
            }
            Spacer(minLength: 0)

            Button("Nouvelle séance") { model.newSession() }
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 58))
        }
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
            Text(text)
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
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            Text("Touche une série pour corriger son compte.")
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .transition(.opacity)
        }
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.text)
                .frame(width: 36, height: 36)
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
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
