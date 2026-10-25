import SwiftUI
import AVFoundation

private let brandColor = Color(red: 0.78, green: 1.0, blue: 0.25)

struct ContentView: View {
    @StateObject private var model = WorkoutModel()
    @State private var bump = false

    private var isCounting: Bool { model.count > 0 }

    var body: some View {
        ZStack {
            CameraPreview(session: model.sensors.session)
                .ignoresSafeArea()
            Color.black
                .opacity(isCounting ? 0.75 : 0.45)
                .ignoresSafeArea()

            VStack {
                HStack(alignment: .center) {
                    diagnosticsButton
                    sourceLabel
                    Spacer()
                    announceButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                if model.showsDiagnostics {
                    diagnosticsPanel
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                }
                Spacer()
                counter
                Spacer()
                statusLabel
                    .padding(.bottom, 24)
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
        .statusBarHidden()
        .preferredColorScheme(.dark)
    }

    /// Capteur suivi, en petit : utile pour comprendre ce que voit l'app.
    private var sourceLabel: some View {
        Text(model.source.map { "Capteur : \($0.label)" } ?? " ")
            .font(.footnote.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
    }

    private var diagnosticsButton: some View {
        Button { model.showsDiagnostics.toggle() } label: {
            Image(systemName: "waveform.path.ecg")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(model.showsDiagnostics ? Color.black : Color.white)
                .frame(width: 40, height: 40)
                .background(model.showsDiagnostics ? AnyShapeStyle(brandColor) : AnyShapeStyle(Material.ultraThinMaterial),
                            in: Circle())
        }
    }

    /// Ce que voit chaque capteur : amplitude du mouvement par rapport au seuil,
    /// cycles détectés, note de régularité (il faut ≥ 0,60 pour démarrer).
    private var diagnosticsPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(Int(model.framesPerSecond.rounded())) images/s")
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
                .opacity(item.source == model.source ? 1 : 0.85)
            }
            Text("ampl. : mouvement mesuré / seuil (≥ 100 % pour compter)")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(12)
        .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }

    /// Fréquence des annonces vocales ; un bip marque les autres répétitions.
    private var announceButton: some View {
        Button { model.cycleAnnounceEvery() } label: {
            Label(model.announceEvery == 1 ? "Chaque rep" : "Toutes les \(model.announceEvery)",
                  systemImage: "speaker.wave.2.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var counter: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 16)
            // Anneau de phase : suit le mouvement en direct
            Circle()
                .trim(from: 0, to: CGFloat(model.phase))
                .stroke(brandColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: model.phase)
            Text("\(model.count)")
                .font(.system(size: 220, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCounting ? Color.white : Color.white.opacity(0.35))
                .lineLimit(1)
                .minimumScaleFactor(0.3)
                .padding(36)
                .contentTransition(.numericText())
                .scaleEffect(bump ? 1.15 : 1)
        }
        .frame(width: 330, height: 330)
    }

    private var statusLabel: some View {
        VStack(spacing: 6) {
            Text(statusTitle)
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text(statusHint)
                .font(.footnote)
                .opacity(0.7)
        }
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
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
            return "Le compteur s'affiche à la 3e.\nPompes : téléphone au sol sous ta tête. Abdos : contre la poitrine."
        case .counting, .resting:
            return "Touche l'écran pour remettre à zéro"
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Text("Accès à la caméra refusé")
                .font(.title2.weight(.bold))
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(brandColor)
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}
