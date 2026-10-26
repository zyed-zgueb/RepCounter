import SwiftUI

/// Séance en style moniteur : compteur de la série, cases de mesure, tracé du signal capté,
/// journal des séries et commandes Démarrer / Annuler la série / Terminer.
struct WorkoutView: View {
    @StateObject private var model: WorkoutModel
    @Environment(\.dismiss) private var dismiss
    @State private var bump = false

    init(exercise: Exercise) {
        _model = StateObject(wrappedValue: WorkoutModel(exercise: exercise))
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 10) {
                header
                if model.isRecording { recordingBanner }
                if model.showsDiagnostics { diagnosticsPanel }

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
        .preferredColorScheme(.dark)
    }

    // MARK: - En-tête

    private var header: some View {
        HStack(spacing: 8) {
            IconButton(systemImage: "xmark") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.exercise.title.uppercased())
                    .font(Theme.mono(14, .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 5) {
                    StatusLED(color: statusColor)
                    MonitorLabel(statusText, color: statusColor)
                }
            }
            Spacer(minLength: 4)
            if model.phase == .active || model.phase == .finished {
                Text("T+ \(Theme.clock(model.sessionDuration))")
                    .font(Theme.mono(13, .semibold))
                    .foregroundStyle(Theme.text)
                    .monospacedDigit()
            }
            IconButton(systemImage: model.isRecording ? "stop.fill" : "record.circle",
                       color: Theme.alarm, highlighted: model.isRecording) { model.toggleRecording() }
            IconButton(systemImage: "waveform.path.ecg", color: Theme.trace,
                       highlighted: model.showsDiagnostics) { model.showsDiagnostics.toggle() }
            Button { model.cycleAnnounceEvery() } label: {
                HStack(spacing: 3) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(model.announceEvery)")
                        .font(Theme.mono(12, .bold))
                }
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 36)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.line, lineWidth: 1))
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
        case .ready: return Theme.dim
        case .countdown: return Theme.warn
        case .finished: return Theme.ok
        case .active:
            if model.isResting { return Theme.warn }
            return model.state == .counting ? Theme.ok : Theme.trace
        }
    }

    // MARK: - Affichage principal

    @ViewBuilder
    private var mainReadout: some View {
        switch model.phase {
        case .ready:
            MonitorPanel("Veille") {
                VStack(spacing: 14) {
                    Image(systemName: model.exercise.symbol)
                        .font(.system(size: 54, weight: .light))
                        .foregroundStyle(Theme.trace)
                    Text(model.exercise.placement)
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                    Text("Vérifie le tracé ci-dessous, puis Démarrer : 5 s de mise en place, et rien ne compte avant.")
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .countdown(let remaining):
            MonitorPanel("Mise en place") {
                VStack(spacing: 6) {
                    Text("\(remaining)")
                        .font(Theme.mono(150, .bold))
                        .foregroundStyle(Theme.warn)
                        .contentTransition(.numericText())
                    Text(model.exercise.placement)
                        .font(Theme.mono(12))
                        .foregroundStyle(Theme.dim)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .active:
            if model.isResting {
                MonitorPanel("Récupération", accessory: {
                    MonitorLabel("Série \(String(format: "%02d", model.sets.count)) · \(model.sets.last?.reps ?? 0) reps",
                                 color: Theme.warn)
                }) {
                    VStack(spacing: 4) {
                        Text(Theme.clock(model.restDuration))
                            .font(Theme.mono(96, .bold))
                            .foregroundStyle(Theme.warn)
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("La série suivante démarre dès que tu reprends.")
                            .font(Theme.mono(11))
                            .foregroundStyle(Theme.dim)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                MonitorPanel("Reps · série \(String(format: "%02d", model.setNumber))", accessory: {
                    MonitorLabel(model.state == .counting ? "Verrouillé" : "3e rep → affichage",
                                 color: model.state == .counting ? Theme.ok : Theme.dim)
                }) {
                    CounterDial(live: model.live, reps: model.setReps, isCounting: model.state == .counting, bump: bump)
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
            MetricTile(label: "Régul.", value: model.regularity > 0 ? "\(Int((model.regularity * 100).rounded()))" : "—",
                       unit: "%", color: model.regularity >= 0.8 ? Theme.ok : Theme.text)
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
        case .absent: return Theme.dim
        case .weak: return Theme.warn
        case .clear: return Theme.ok
        }
    }

    private var presenceText: String {
        switch model.presence {
        case .absent: return "Pas de signal"
        case .weak: return "Signal faible"
        case .clear: return "Signal OK"
        }
    }

    private var setsLog: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.sets) { set in
                    HStack(spacing: 6) {
                        Text(String(format: "S%02d", set.number))
                            .foregroundStyle(Theme.dim)
                        Text("\(set.reps)")
                            .foregroundStyle(Theme.text)
                    }
                    .font(Theme.mono(12, .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.panel, in: RoundedRectangle(cornerRadius: 3))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.line, lineWidth: 1))
                }
            }
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .ready:
            Button("Démarrer") { model.beginSession() }
                .buttonStyle(MonitorButtonStyle(color: Theme.trace, height: 64))
        case .countdown:
            Button("Annuler") { model.cancelCountdown() }
                .buttonStyle(MonitorButtonStyle(color: Theme.dim, filled: false))
        case .active:
            HStack(spacing: 10) {
                Button("Annuler série") { model.cancelSet() }
                    .buttonStyle(MonitorButtonStyle(color: Theme.warn, filled: false))
                    .disabled(model.setReps == 0 && model.sets.isEmpty)
                Button("Terminer") { model.finishSession() }
                    .buttonStyle(MonitorButtonStyle(color: Theme.alarm))
            }
        case .finished:
            EmptyView()
        }
    }

    // MARK: - Enregistrement et diagnostic

    private var recordingBanner: some View {
        HStack(spacing: 8) {
            StatusLED(color: Theme.alarm)
            MonitorLabel("Enregistrement \(Theme.clock(model.recordingDuration))", color: Theme.alarm)
            Spacer()
            MonitorLabel("■ pour arrêter")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.alarm.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.alarm.opacity(0.5), lineWidth: 1))
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
                            .foregroundStyle(item.amplitude >= item.source.minAmplitude ? Theme.ok : Theme.dim)
                        Text("\(item.cycles) cyc")
                        Text(String(format: "rég %.2f", item.regularity))
                            .foregroundStyle(item.regularity >= 0.6 ? Theme.ok : Theme.dim)
                    }
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.text)
                }
                if model.diagnostics.isEmpty {
                    MonitorLabel("En attente de mesures")
                }
            }
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            MonitorLabel("Accès caméra refusé", color: Theme.alarm)
            Text("Cet exercice utilise la caméra pour te voir. Rien n'est enregistré.")
                .font(Theme.mono(13))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.center)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(MonitorButtonStyle(color: Theme.trace))
            Button("Retour") { dismiss() }
                .buttonStyle(MonitorButtonStyle(color: Theme.dim, filled: false))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}

// MARK: - Cadran et tracé (observent le signal en direct, 30 fois par seconde)

/// Cadran gradué : 60 graduations qui s'allument avec l'avancement de la répétition,
/// et le nombre de répétitions de la série au centre.
private struct CounterDial: View {
    @ObservedObject var live: LiveSignal
    let reps: Int
    let isCounting: Bool
    let bump: Bool

    private let tickCount = 60

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let outer = min(size.width, size.height) / 2 - 2
                    let lit = isCounting ? Int((Float(tickCount) * live.phase).rounded()) : 0
                    for i in 0..<tickCount {
                        let angle = Double(i) / Double(tickCount) * 2 * .pi - .pi / 2
                        let major = i % 5 == 0
                        let inner = outer - (major ? 16 : 9)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner,
                                              y: center.y + CGFloat(sin(angle)) * inner))
                        tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer,
                                                 y: center.y + CGFloat(sin(angle)) * outer))
                        let fraction = Double(i) / Double(tickCount)
                        let color = i < lit
                            ? (fraction < 0.5 ? Theme.violet : Theme.trace)
                            : Theme.line
                        context.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: major ? 3 : 2, lineCap: .round))
                    }
                }
                .shadow(color: Theme.trace.opacity(isCounting ? 0.35 : 0), radius: 8)

                VStack(spacing: 0) {
                    Text("\(reps)")
                        .font(Theme.mono(side * 0.36, .bold))
                        .foregroundStyle(isCounting ? Theme.text : Theme.dim)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .scaleEffect(bump ? 1.1 : 1)
                    MonitorLabel("reps")
                }
                .padding(side * 0.2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Tracé des 3 dernières secondes du signal suivi, façon électrocardiogramme : plat sans
/// mouvement, ample et lumineux quand le geste est net, atténué quand il est trop léger.
private struct SignalTrace: View {
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
            context.stroke(path, with: .color(Theme.trace), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            // Point lumineux à la dernière mesure
            if let last = samples.last {
                let dot = CGRect(x: size.width - 4, y: size.height * (1 - CGFloat(last)) - 4, width: 8, height: 8)
                context.fill(Path(ellipseIn: dot), with: .color(Theme.trace))
            }
        }
        .opacity(Double(min(max(live.strength, 0.3), 1)))
        .shadow(color: Theme.trace.opacity(live.strength >= 1 ? 0.7 : 0), radius: 5)
    }
}

// MARK: - Résumé de séance

private struct SessionSummary: View {
    @ObservedObject var model: WorkoutModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            MonitorPanel("Séance terminée", accessory: {
                HStack(spacing: 5) {
                    StatusLED(color: Theme.ok)
                    MonitorLabel(model.exercise.title, color: Theme.ok)
                }
            }) {
                VStack(spacing: 2) {
                    Text("\(model.totalReps)")
                        .font(Theme.mono(96, .bold))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                    MonitorLabel("répétitions au total")
                }
                .frame(maxWidth: .infinity)
            }
            HStack(spacing: 8) {
                MetricTile(label: "Durée", value: Theme.clock(model.sessionDuration))
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
                                            .foregroundStyle(Theme.dim)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(set.reps)")
                                            .foregroundStyle(Theme.text)
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(Theme.clock(set.duration))
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                        Text(set.cadence.map { String(format: "%.1f s", $0) } ?? "—")
                                            .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .font(Theme.mono(14, .semibold))
                                    .foregroundStyle(Theme.text)
                                    .padding(.vertical, 8)
                                    Rectangle().fill(Theme.line).frame(height: 1)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            HStack(spacing: 10) {
                Button("Nouvelle séance") { model.newSession() }
                    .buttonStyle(MonitorButtonStyle(color: Theme.trace, filled: false))
                Button("Quitter") { onClose() }
                    .buttonStyle(MonitorButtonStyle(color: Theme.trace))
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
                .fill(Theme.line)
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            MonitorLabel("Enregistrement terminé", color: Theme.alarm)
            Text("Compté par l'app : \(finished.countedReps)")
                .font(Theme.mono(14))
                .foregroundStyle(Theme.dim)

            MonitorPanel("Répétitions réellement faites") {
                HStack(spacing: 24) {
                    stepButton("minus") { actualReps = max(0, actualReps - 1) }
                    Text("\(actualReps)")
                        .font(Theme.mono(56, .bold))
                        .foregroundStyle(Theme.text)
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
                .buttonStyle(MonitorButtonStyle(color: Theme.trace))
                Text("Aussi dans Fichiers › Sur mon iPhone › Reps › Recordings.")
                    .font(Theme.mono(11))
                    .foregroundStyle(Theme.dim)
                Button("Fermer") { dismiss() }
                    .buttonStyle(MonitorButtonStyle(color: Theme.dim, filled: false))
            } else {
                Button("Valider") {
                    finished.recorder.finish(countedReps: finished.countedReps, actualReps: actualReps)
                    savedURL = finished.recorder.url
                }
                .buttonStyle(MonitorButtonStyle(color: Theme.trace))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.fraction(0.75), .large])
        .interactiveDismissDisabled(savedURL == nil)
        .preferredColorScheme(.dark)
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 52, height: 52)
                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.line, lineWidth: 1))
        }
    }
}
