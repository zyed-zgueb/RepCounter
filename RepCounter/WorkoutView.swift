import SwiftUI

/// Séance en style moniteur : compteur de la série, cases de mesure, tracé du signal capté,
/// journal des séries et commandes Démarrer / Annuler la série / Terminer.
struct WorkoutView: View {
    @Environment(\.theme) private var theme
    @StateObject private var model: WorkoutModel
    @Environment(\.dismiss) private var dismiss
    @State private var bump = false
    @AppStorage(SettingsView.analysisModeKey) private var analysisMode = false

    init(exercise: Exercise) {
        _model = StateObject(wrappedValue: WorkoutModel(exercise: exercise))
    }

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: 10) {
                header
                if analysisMode, model.isRecording { recordingBanner }
                if analysisMode, model.showsDiagnostics { diagnosticsPanel }

                if model.phase == .finished {
                    SessionSummary(model: model) { dismiss() }
                } else {
                    mainReadout
                    if model.phase == .active { metrics }
                    signalPanel
                    if model.phase == .active, !model.sets.isEmpty { setsLog }
                    controls
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            if model.cameraDenied { deniedView }
        }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.repPulse) { _ in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bump = false }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.phase)
        .animation(.easeInOut(duration: 0.25), value: model.isResting)
        .sheet(item: $model.finishedRecording) { finished in
            RecordingSheet(finished: finished)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .preferredColorScheme(theme.colorScheme)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 8) {
            IconButton(systemImage: "xmark") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.exercise.title.uppercased())
                    .font(theme.font(14, .bold))
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    StatusLED(color: statusColor)
                    MonitorLabel(statusText, color: statusColor)
                }
            }
            Spacer(minLength: 4)
            if model.phase == .active || model.phase == .finished {
                Text("T+ \(Format.clock(model.sessionDuration))")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
            }
            // Outils d'analyse : visibles seulement si le mode analyse est activé dans les Réglages
            if analysisMode {
                IconButton(systemImage: model.isRecording ? "stop.fill" : "record.circle",
                           color: theme.alarm, highlighted: model.isRecording) { model.toggleRecording() }
                IconButton(systemImage: "waveform.path.ecg", color: theme.primary,
                           highlighted: model.showsDiagnostics) { model.showsDiagnostics.toggle() }
            }
        }
        .padding(.top, 8)
    }

    private var statusText: String {
        switch model.phase {
        case .ready: return "Veille"
        case .countdown: return "Mise en place"
        case .finished: return "Séance terminée"
        case .active:
            if model.isResting { return "Récupération" }
            return model.state == .counting ? "Comptage" : "Acquisition"
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

    // MARK: - Affichage principal

    @ViewBuilder
    private var mainReadout: some View {
        switch model.phase {
        case .ready:
            MonitorPanel("Veille") {
                VStack(spacing: 14) {
                    ExerciseIcon(exercise: model.exercise, size: 60)
                        .foregroundStyle(theme.primary)
                    Text(model.exercise.placement)
                        .font(theme.font(13))
                        .foregroundStyle(theme.text)
                        .multilineTextAlignment(.center)
                    Text("Vérifie le tracé ci-dessous, puis Démarrer : 5 s de mise en place, et rien ne compte avant.")
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .countdown(let remaining):
            MonitorPanel("Mise en place") {
                VStack(spacing: 6) {
                    Text("\(remaining)")
                        .font(theme.font(150, .bold))
                        .foregroundStyle(theme.warn)
                        .contentTransition(.numericText())
                    Text(model.exercise.placement)
                        .font(theme.font(12))
                        .foregroundStyle(theme.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .active:
            if model.isResting {
                MonitorPanel("Récupération", accessory: {
                    MonitorLabel("Série \(String(format: "%02d", model.sets.count)) · \(model.sets.last?.reps ?? 0) reps",
                                 color: theme.warn)
                }) {
                    VStack(spacing: 4) {
                        Text(Format.clock(model.restDuration))
                            .font(theme.font(96, .bold))
                            .foregroundStyle(theme.warn)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("La série suivante démarre dès que tu reprends.")
                            .font(theme.font(11))
                            .foregroundStyle(theme.dim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                MonitorPanel("Reps · série \(String(format: "%02d", model.setNumber))", accessory: {
                    if model.state == .counting {
                        MonitorLabel("Validé", color: theme.ok)
                    } else if model.tentative > 0 {
                        MonitorLabel("Détection \(model.tentative)/\(AutoCounter.cyclesToLock)", color: theme.primary)
                    } else {
                        MonitorLabel("En attente du mouvement")
                    }
                }) {
                    CounterDial(live: model.live, reps: model.setReps, tentative: model.tentative,
                                tentativePulse: model.tentativePulse, isCounting: model.state == .counting, bump: bump)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        case .finished:
            EmptyView()
        }
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            MetricTile(label: "Total", value: "\(model.totalReps)")
            MetricTile(label: "Séries", value: "\(model.sets.count)")
            MetricTile(label: "Cadence", value: model.cadence.map { String(format: "%.1f", $0) } ?? "—", unit: "s/rep")
            if analysisMode {
                MetricTile(label: "Régul.", value: model.regularity > 0 ? "\(Int((model.regularity * 100).rounded()))" : "—",
                           unit: "%", color: model.regularity >= 0.8 ? theme.ok : theme.text)
            }
        }
    }

    private var signalPanel: some View {
        MonitorPanel("Signal · \(model.source?.code ?? model.exercise.sensorTag)", accessory: {
            HStack(spacing: 5) {
                StatusLED(color: presenceColor)
                MonitorLabel(presenceText, color: presenceColor)
            }
        }) {
            ZStack {
                MonitorGrid()
                SignalTrace(live: model.live)
                    .padding(.vertical, 4)
            }
            .frame(height: 74)
        }
    }

    private var presenceColor: Color {
        switch model.presence {
        case .absent: return theme.dim
        case .weak: return theme.warn
        case .clear: return theme.ok
        }
    }

    private var presenceText: String {
        switch model.presence {
        case .absent: return "Pas de signal"
        case .weak: return "Signal faible"
        case .clear: return "Signal OK"
        }
    }

    /// Dernières séries sur une ligne fixe ; les plus anciennes sont résumées par « +N ».
    private var setsLog: some View {
        let shown = model.sets.suffix(Self.setsShown)
        let hidden = model.sets.count - shown.count
        return HStack(spacing: 6) {
            if hidden > 0 { setChip(label: "+\(hidden)", value: nil) }
            ForEach(shown) { set in
                setChip(label: String(format: "S%02d", set.number), value: "\(set.reps)")
            }
            Spacer(minLength: 0)
        }
    }

    private static let setsShown = 4

    private func setChip(label: String, value: String?) -> some View {
        HStack(spacing: 6) {
            Text(label).foregroundStyle(theme.dim)
            if let value { Text(value).foregroundStyle(theme.text) }
        }
        .font(theme.font(12, .bold))
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.line, lineWidth: 1))
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .ready:
            Button("Démarrer") { model.beginSession() }
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 64))
        case .countdown:
            Button("Annuler") { model.cancelCountdown() }
                .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false))
        case .active:
            HStack(spacing: 10) {
                Button("Annuler série") { model.cancelSet() }
                    .buttonStyle(MonitorButtonStyle(color: theme.warn, filled: false))
                    .disabled(model.setReps == 0 && model.sets.isEmpty)
                Button("Terminer") { model.finishSession() }
                    .buttonStyle(MonitorButtonStyle(color: theme.alarm))
            }
        case .finished:
            EmptyView()
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

    private var deniedView: some View {
        VStack(spacing: 16) {
            MonitorLabel("Accès caméra refusé", color: theme.alarm)
            Text("Cet exercice utilise la caméra pour te voir. Rien n'est enregistré.")
                .font(theme.font(13))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(MonitorButtonStyle(color: theme.primary))
            Button("Retour") { dismiss() }
                .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }
}

// MARK: - Cadran et tracé (observent le signal en direct, 30 fois par seconde)

/// Cadran gradué : 60 graduations qui suivent l'avancement de la répétition, et au centre
/// le nombre de répétitions de la série.
///
/// Avant la validation de la série, le cadran montre déjà que le mouvement est suivi :
/// graduations en pâle, répétitions détectées en chiffres pâles « à valider », trois témoins
/// de validation, et une onde à chaque répétition détectée. Une fois validé, tout passe en plein.
private struct CounterDial: View {
    @Environment(\.theme) private var theme
    @ObservedObject var live: LiveSignal
    let reps: Int
    let tentative: Int
    let tentativePulse: Int
    let isCounting: Bool
    let bump: Bool

    /// Onde : invisible au repos (déployée et transparente), relancée à chaque détection.
    @State private var ripple = true
    private let tickCount = 60

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outer = min(size.width, size.height) / 2 - 2
                    let lit = Int((Float(tickCount) * live.phase).rounded())
                    for i in 0..<tickCount {
                        let angle = Double(i) / Double(tickCount) * 2 * .pi - .pi / 2
                        let major = i % 5 == 0
                        let inner = outer - (major ? 16 : 9)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner,
                                              y: center.y + CGFloat(sin(angle)) * inner))
                        tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer,
                                                 y: center.y + CGFloat(sin(angle)) * outer))
                        let color: Color
                        if i >= lit {
                            color = theme.line
                        } else if isCounting {
                            color = Double(i) / Double(tickCount) < 0.5 ? theme.secondary : theme.primary
                        } else {
                            color = theme.primary.opacity(0.4)   // mouvement suivi, pas encore validé
                        }
                        context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: major ? 3 : 2, lineCap: .round))
                    }
                }
                .shadow(color: theme.primary.opacity(isCounting ? 0.35 * min(theme.glow, 1) : 0), radius: 8)

                // Onde à chaque répétition détectée (pas encore validée)
                Circle()
                    .stroke(theme.primary, lineWidth: 2)
                    .scaleEffect(ripple ? 1.0 : 0.55)
                    .opacity(ripple ? 0 : 0.8)
                    .padding(side * 0.08)

                VStack(spacing: 4) {
                    Text(centerText)
                        .font(theme.font(side * 0.36, .bold))
                        .foregroundStyle(isCounting ? theme.text : (tentative > 0 ? theme.primary.opacity(0.55) : theme.dim))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .scaleEffect(bump ? 1.1 : 1)
                    if isCounting {
                        MonitorLabel("reps")
                    } else {
                        HStack(spacing: 5) {
                            ForEach(0..<AutoCounter.cyclesToLock, id: \.self) { index in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(index < tentative ? theme.primary : theme.line)
                                    .frame(width: 14, height: 6)
                            }
                        }
                        MonitorLabel(tentative > 0 ? "à valider" : "en attente")
                    }
                }
                .padding(side * 0.2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: tentativePulse) { _ in
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) { ripple = false }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.7)) { ripple = true }
            }
        }
    }

    private var centerText: String {
        if isCounting { return "\(reps)" }
        return tentative > 0 ? "\(tentative)" : "–"
    }
}

/// Tracé des 3 dernières secondes du signal suivi, façon électrocardiogramme : plat sans
/// mouvement, ample et lumineux quand le geste est net, atténué quand il est trop léger.
private struct SignalTrace: View {
    @Environment(\.theme) private var theme
    @ObservedObject var live: LiveSignal

    var body: some View {
        Canvas { context, size in
            let samples = live.samples
            guard samples.count > 1 else { return }
            var path = Path()
            for (i, value) in samples.enumerated() {
                let x = size.width * CGFloat(i) / CGFloat(samples.count - 1)
                let y = size.height * (1 - CGFloat(value))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .color(theme.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // Point lumineux à la dernière mesure
            if let last = samples.last {
                let dot = CGRect(x: size.width - 4, y: size.height * (1 - CGFloat(last)) - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dot), with: .color(theme.primary))
            }
        }
        .opacity(Double(min(max(live.strength, 0.3), 1)))
        .shadow(color: theme.primary.opacity(live.strength >= 1 ? 0.7 : 0), radius: 5)
    }
}

// MARK: - Résumé de séance

private struct SessionSummary: View {
    @Environment(\.theme) private var theme
    @ObservedObject var model: WorkoutModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            MonitorPanel("Séance terminée", accessory: {
                HStack(spacing: 5) {
                    StatusLED(color: theme.ok)
                    MonitorLabel(model.exercise.title, color: theme.ok)
                }
            }) {
                VStack(spacing: 2) {
                    Text("\(model.totalReps)")
                        .font(theme.font(96, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                    MonitorLabel("répétitions au total")
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                MetricTile(label: "Durée", value: Format.clock(model.sessionDuration))
                MetricTile(label: "Séries", value: "\(model.sets.count)")
                MetricTile(label: "Moy./série", value: averagePerSet)
                MetricTile(label: "Cadence", value: averageCadence, unit: "s/rep")
            }
            MonitorPanel("Détail des séries") {
                if model.sets.isEmpty {
                    MonitorLabel("Aucune série comptée")
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            MonitorLabel("Série").frame(maxWidth: .infinity, alignment: .leading)
                            MonitorLabel("Reps").frame(maxWidth: .infinity, alignment: .trailing)
                            MonitorLabel("Durée").frame(maxWidth: .infinity, alignment: .trailing)
                            MonitorLabel("Cadence").frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(.bottom, 6)
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(model.sets) { set in
                                    HStack {
                                        Text(String(format: "S%02d", set.number))
                                            .foregroundStyle(theme.dim)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(set.reps)")
                                            .foregroundStyle(theme.text)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(Format.clock(set.duration))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(set.cadence.map { String(format: "%.1f s", $0) } ?? "—")
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .font(theme.font(14, .semibold))
                                    .foregroundStyle(theme.text)
                                    .padding(.vertical, 8)
                                    Rectangle().fill(theme.line).frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            HStack(spacing: 10) {
                Button("Nouvelle séance") { model.newSession() }
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: false))
                Button("Quitter") { onClose() }
                    .buttonStyle(MonitorButtonStyle(color: theme.primary))
            }
        }
    }

    private var averagePerSet: String {
        guard !model.sets.isEmpty else { return "—" }
        return String(format: "%.1f", Double(model.totalReps) / Double(model.sets.count))
    }

    private var averageCadence: String {
        let cadences = model.sets.compactMap(\.cadence)
        guard !cadences.isEmpty else { return "—" }
        return String(format: "%.1f", cadences.reduce(0, +) / Double(cadences.count))
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
