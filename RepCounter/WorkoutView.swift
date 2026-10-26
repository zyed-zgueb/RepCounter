import SwiftUI

/// Séance : pas de vidéo. Le compteur, et en dessous une courbe de ce que capte l'app,
/// pour savoir qu'elle te suit sans avoir l'impression de s'entraîner devant un miroir.
struct WorkoutView: View {
    @StateObject private var model: WorkoutModel
    @Environment(\.dismiss) private var dismiss
    @State private var bump = false

    init(exercise: Exercise) {
        _model = StateObject(wrappedValue: WorkoutModel(exercise: exercise))
    }

    private var isCounting: Bool { model.count > 0 }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                topBar
                if model.isRecording {
                    recordingBanner
                        .padding(.top, 10)
                }
                if model.showsDiagnostics {
                    diagnosticsPanel
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                }
                Spacer(minLength: 12)
                CounterRing(live: model.live, count: model.count, isCounting: isCounting, bump: bump)
                Spacer(minLength: 12)
                presenceSection
                statusLabel
                    .padding(.top, 16)
                    .padding(.bottom, 28)
            }

            if model.cameraDenied { deniedView }
        }
        .contentShape(Rectangle())
        .onTapGesture { model.reset() }
        .onAppear { model.start() }
        .onDisappear { model.stop() }
        .onChange(of: model.repPulse) { _ in
            withAnimation(.spring(response: 0.12, dampingFraction: 0.5)) { bump = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { bump = false }
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isCounting)
        .animation(.easeInOut(duration: 0.3), value: model.presence)
        .sheet(item: $model.finishedRecording) { finished in
            RecordingSheet(finished: finished)
        }
        .toolbar(.hidden, for: .navigationBar)
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    /// Fond sombre ; un halo bleu apparaît quand le mouvement est capté.
    private var background: some View {
        ZStack {
            screenBackground
            RadialGradient(colors: [brandColor.opacity(model.presence == .clear ? 0.18 : 0.04), .clear],
                           center: .center, startRadius: 40, endRadius: 420)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            roundButton(systemImage: "xmark") { dismiss() }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.exercise.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
                Text(model.source.map { "Capteur : \($0.label)" } ?? " ")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            recordButton
            roundButton(systemImage: "waveform.path.ecg", highlighted: model.showsDiagnostics) {
                model.showsDiagnostics.toggle()
            }
            // Fréquence des annonces : 1, 5 ou 10
            Button { model.cycleAnnounceEvery() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                    Text("\(model.announceEvery)")
                        .monospacedDigit()
                }
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .background(cardBackground, in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    /// Enregistre les mesures de la séance, pour analyser un comptage raté.
    private var recordButton: some View {
        Button { model.toggleRecording() } label: {
            Image(systemName: model.isRecording ? "stop.fill" : "record.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(model.isRecording ? Color.white : Color.red)
                .frame(width: 40, height: 40)
                .background(model.isRecording ? Color.red : cardBackground, in: Circle())
        }
    }

    private var recordingBanner: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text("Enregistrement \(Int(model.recordingDuration) / 60):\(String(format: "%02d", Int(model.recordingDuration) % 60))")
                .monospacedDigit()
            Text("· ■ pour arrêter")
                .foregroundStyle(.white.opacity(0.5))
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.2), in: Capsule())
    }

    private func roundButton(systemImage: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(highlighted ? Color.black : Color.white)
                .frame(width: 40, height: 40)
                .background(highlighted ? brandColor : cardBackground, in: Circle())
        }
    }

    /// Pastille « Je te capte » et courbe en direct du signal suivi.
    private var presenceSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(presenceColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: presenceColor, radius: model.presence == .clear ? 6 : 0)
                Text(presenceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(model.presence == .absent ? 0.6 : 0.95))
            }
            SignalWave(live: model.live)
                .frame(height: 64)
                .padding(.horizontal, 28)
        }
    }

    private var presenceColor: Color {
        switch model.presence {
        case .absent: return Color.white.opacity(0.3)
        case .weak: return Color.orange
        case .clear: return brandColor
        }
    }

    private var presenceText: String {
        switch (model.presence, model.state) {
        case (_, .counting): return "Je te capte, je compte"
        case (.clear, _): return "Je te capte"
        case (.weak, _): return "Mouvement trop léger"
        case (.absent, _): return "J'attends ton mouvement"
        }
    }

    private var statusLabel: some View {
        VStack(spacing: 6) {
            Text(statusTitle)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text(statusHint)
                .font(.footnote)
                .opacity(0.6)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)
    }

    private var statusTitle: String {
        switch model.state {
        case .searching: return "Commence tes répétitions"
        case .counting: return " "
        case .resting: return "Pause"
        }
    }

    private var statusHint: String {
        switch model.state {
        case .searching:
            return "\(model.exercise.placement)\nLe compteur démarre à la 3e répétition."
        case .counting, .resting:
            return "Touche l'écran pour remettre à zéro"
        }
    }

    /// Ce que voit chaque capteur : amplitude du mouvement par rapport au seuil,
    /// cycles détectés, note de régularité (il faut ≥ 0,60 pour démarrer).
    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(model.framesPerSecond.rounded())) mesures/s")
                .font(.footnote.weight(.bold))
                .foregroundStyle(model.framesPerSecond < 20 ? Color.orange : Color.white)
            ForEach(model.diagnostics, id: \.source) { item in
                HStack(spacing: 8) {
                    Text(item.source.label)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("ampl. \(Int((100 * item.amplitude / item.source.minAmplitude).rounded())) %")
                        .foregroundStyle(item.amplitude >= item.source.minAmplitude ? brandColor : Color.white.opacity(0.5))
                    Text("\(item.cycles) cyc.")
                    Text(String(format: "rég. %.2f", item.regularity))
                        .foregroundStyle(item.regularity >= 0.6 ? brandColor : Color.white.opacity(0.5))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            }
            Text("ampl. : mouvement mesuré / seuil (≥ 100 % pour compter)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Text("Accès à la caméra refusé")
                .font(.title2.weight(.bold))
            Text("Cet exercice utilise la caméra pour te voir. Rien n'est enregistré.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor)
            .foregroundStyle(.black)
            Button("Retour") { dismiss() }
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(screenBackground.ignoresSafeArea())
    }
}

/// Anneau et grand chiffre, dans le style de l'icône. Observe le signal en direct :
/// c'est lui, et pas tout l'écran, qui se redessine 30 fois par seconde.
private struct CounterRing: View {
    @ObservedObject var live: LiveSignal
    let count: Int
    let isCounting: Bool
    let bump: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 18)
            Circle()
                .trim(from: 0, to: isCounting ? CGFloat(live.phase) : 0)
                .stroke(AngularGradient(colors: [ringStartColor, brandColor], center: .center,
                                        startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: brandColor.opacity(0.55), radius: 12)
                .animation(.linear(duration: 0.1), value: live.phase)
            VStack(spacing: 0) {
                Text("REPS")
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .tracking(3)
                    .foregroundStyle(.white.opacity(0.6))
                Text("\(count)")
                    .font(.system(size: 170, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCounting ? Color.white : Color.white.opacity(0.3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .contentTransition(.numericText())
                    .scaleEffect(bump ? 1.12 : 1)
            }
            .padding(40)
        }
        .frame(width: 310, height: 310)
    }
}

/// Courbe des 3 dernières secondes du signal suivi : plate sans mouvement,
/// ample quand le geste est net, atténuée quand il est trop léger.
private struct SignalWave: View {
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
            let gradient = Gradient(colors: [ringStartColor, brandColor])
            context.stroke(path,
                           with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
        .opacity(Double(min(max(live.strength, 0.25), 1)))
        .shadow(color: brandColor.opacity(live.strength >= 1 ? 0.6 : 0), radius: 6)
    }
}

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
        VStack(spacing: 22) {
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            Text("Enregistrement terminé")
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text("L'app a compté \(finished.countedReps) répétition\(finished.countedReps > 1 ? "s" : "").")
                .foregroundStyle(.white.opacity(0.7))

            VStack(spacing: 10) {
                Text("Combien en as-tu réellement fait ?")
                    .font(.headline)
                HStack(spacing: 24) {
                    stepButton("minus") { actualReps = max(0, actualReps - 1) }
                    Text("\(actualReps)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 90)
                    stepButton("plus") { actualReps += 1 }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let savedURL {
                ShareLink(item: savedURL) {
                    Label("Partager l'enregistrement", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(brandColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                Text("Aussi dans Fichiers › Sur mon iPhone › Reps › Recordings.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                Button("Fermer") { dismiss() }
                    .foregroundStyle(.white)
            } else {
                Button {
                    finished.recorder.finish(countedReps: finished.countedReps, actualReps: actualReps)
                    savedURL = finished.recorder.url
                } label: {
                    Text("Valider")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(brandColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(screenBackground.ignoresSafeArea())
        .presentationDetents([.fraction(0.75), .large])
        .interactiveDismissDisabled(savedURL == nil)
        .preferredColorScheme(.dark)
    }

    private func stepButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(0.1), in: Circle())
        }
    }
}
