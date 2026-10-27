import SwiftData
import SwiftUI

// MARK: - Consigne

/// Avant le test : le pictogramme, trois étapes, et « Commencer ».
struct FormTestIntro: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            ExerciseIcon(exercise: exercise, size: 80)
                .foregroundStyle(theme.primary)
                .frame(width: 150, height: 150)
                .background(Circle().fill(RadialGradient(colors: [theme.primary.opacity(0.12), theme.primary.opacity(0.03)],
                                                         center: .center, startRadius: 0, endRadius: 75)))
                .overlay(Circle().stroke(theme.primary.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 14) {
                step(1, "Échauffe-toi : **5 \(exercise.testNoun) faciles**.")
                step(2, exercise.placement)
                step(3, "Fais **\(FormTest.reps) \(exercise.testNoun) aussi vite que possible**, en gardant toute l'amplitude"
                        + (exercise.isWeighted ? ", avec ta charge habituelle." : "."))
            }
            .padding(.horizontal, 6)
            Text("L'app s'arrête seule après la \(FormTest.reps)e. Fais-le si possible à la même heure, pour comparer ce qui est comparable.")
                .font(theme.font(12))
                .foregroundStyle(theme.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Commencer", action: onStart)
                .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 64))
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(theme.font(12, .bold))
                .foregroundStyle(theme.primary)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(theme.primary, lineWidth: 1))
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
            Text(LocalizedStringKey(text))
                .font(theme.font(14))
                .foregroundStyle(theme.text)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Arc de forme

/// Arc de 270° gradué de 80 à 115 % de la référence : zone fatiguée à gauche, normale autour de
/// 100 %, fraîche à droite. La zone du résultat est allumée, un point marque le résultat.
/// Sans résultat (référence en cours), l'arc reste éteint.
struct FormArc: View {
    @Environment(\.theme) private var theme
    let result: FormResult?

    private static let count = 51
    private static let low = 80.0, high = 115.0

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Canvas { context, size in draw(in: context, size: size) }
                    .shadow(color: result.map { color($0.zone) }?.opacity(0.4 * min(theme.glow, 1)) ?? .clear, radius: 8)
                if let result {
                    endLabel("FATIGUÉ", color: theme.warn, on: result.zone == .tired, angle: 135, side: side)
                    endLabel("FRAIS", color: theme.ok, on: result.zone == .fresh, angle: 45, side: side)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func color(_ zone: FormZone) -> Color {
        switch zone {
        case .tired: return theme.warn
        case .normal: return theme.primary
        case .fresh: return theme.ok
        }
    }

    private func zone(at percent: Double, band: Double) -> FormZone {
        percent < 100 - band ? .tired : (percent > 100 + band ? .fresh : .normal)
    }

    private func angle(_ index: Double) -> Double {
        (135 + 270 * index / Double(Self.count - 1)) * .pi / 180
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let outer = min(size.width, size.height) / 2 - 6
        for i in 0..<Self.count {
            let percent = Self.low + (Self.high - Self.low) * Double(i) / Double(Self.count - 1)
            let reference = abs(percent - 100) < 0.4
            let inner = outer * (reference ? 0.84 : 0.92)
            let a = angle(Double(i))
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + CGFloat(cos(a)) * inner, y: center.y + CGFloat(sin(a)) * inner))
            tick.addLine(to: CGPoint(x: center.x + CGFloat(cos(a)) * outer, y: center.y + CGFloat(sin(a)) * outer))
            let tickColor: Color
            if let result {
                let tickZone = zone(at: percent, band: result.band)
                tickColor = tickZone == result.zone ? color(tickZone) : color(tickZone).opacity(0.22)
            } else {
                tickColor = theme.line
            }
            context.stroke(tick, with: .color(tickColor), style: StrokeStyle(lineWidth: reference ? 3.6 : 2.4, lineCap: .round))
        }
        guard let result else { return }
        let position = (min(max(result.percent, Self.low), Self.high) - Self.low) / (Self.high - Self.low) * Double(Self.count - 1)
        let a = angle(position)
        let point = CGPoint(x: center.x + CGFloat(cos(a)) * (outer + 1), y: center.y + CGFloat(sin(a)) * (outer + 1))
        context.fill(Path(ellipseIn: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12)), with: .color(theme.text))
    }

    /// Libellé sous un bout de l'arc.
    private func endLabel(_ text: String, color: Color, on: Bool, angle degrees: Double, side: CGFloat) -> some View {
        let a = degrees * .pi / 180, outer = side / 2 - 6
        return Text(text)
            .font(theme.font(9, .bold))
            .tracking(1)
            .foregroundStyle(color.opacity(on ? 1 : 0.6))
            .fixedSize()
            .position(x: side / 2 + CGFloat(cos(a)) * outer, y: side / 2 + CGFloat(sin(a)) * outer + 20)
    }
}

// MARK: - Résultat

/// Résultat du test : la forme en % de la référence, sa zone et un conseil ; ou, pendant les
/// premiers tests, « Référence en cours ». En dessous, la durée de chaque répétition mesurée.
struct FormTestResultView: View {
    @Environment(\.theme) private var theme
    let exercise: Exercise
    let intervals: [Double]
    let result: FormResult?
    /// Tests déjà faits sur cet exercice, celui-ci compris (pendant la référence).
    let testCount: Int
    let onClose: () -> Void
    let onStartSession: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            ZStack {
                FormArc(result: result)
                center
            }
            .frame(maxWidth: 300)
            Text(result?.zone.advice ?? baselineText)
                .font(theme.font(13))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                ForEach(Array(intervals.enumerated()), id: \.offset) { index, interval in
                    VStack(spacing: 4) {
                        MonitorLabel("Rep \(index + 1)")
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(interval.formatted(.number.precision(.fractionLength(2))))
                                .font(theme.font(18, .semibold))
                                .foregroundStyle(theme.text)
                                .monospacedDigit()
                            Text("s")
                                .font(theme.font(10))
                                .foregroundStyle(theme.dim)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)
            .overlay(alignment: .top) { Rectangle().fill(theme.line).frame(height: 1) }
            Spacer(minLength: 0)
            if result == nil {
                Button("Terminer", action: onClose)
                    .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 58))
            } else {
                HStack(spacing: 10) {
                    Button("Terminer", action: onClose)
                        .buttonStyle(MonitorButtonStyle(color: theme.dim, filled: false, height: 58))
                    Button("Démarrer", action: onStartSession)
                        .buttonStyle(MonitorButtonStyle(color: theme.primary, height: 58))
                }
            }
        }
    }

    private var zoneColor: Color {
        switch result?.zone {
        case .tired?: return theme.warn
        case .fresh?: return theme.ok
        default: return theme.primary
        }
    }

    @ViewBuilder
    private var center: some View {
        if let result {
            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(result.percent.rounded()))")
                        .font(theme.font(84, .bold))
                    Text("%")
                        .font(theme.font(30, .bold))
                }
                .foregroundStyle(zoneColor)
                .monospacedDigit()
                MonitorLabel("de ta référence")
                Text(result.zone.title.uppercased())
                    .font(theme.font(15, .bold))
                    .tracking(2)
                    .foregroundStyle(zoneColor)
            }
        } else {
            VStack(spacing: 10) {
                Text("Référence\nen cours")
                    .font(theme.font(30, .bold))
                    .foregroundStyle(theme.text)
                    .multilineTextAlignment(.center)
                HStack(spacing: 6) {
                    ForEach(0..<FormTest.baselineTests, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index < testCount ? theme.primary : theme.line)
                            .frame(width: 22, height: 7)
                    }
                }
                MonitorLabel("test \(min(testCount, FormTest.baselineTests)) sur \(FormTest.baselineTests)")
            }
        }
    }

    private var baselineText: String {
        let left = FormTest.baselineTests - testCount
        guard left > 0 else {
            return "Référence établie. Dès ton prochain test, tu sauras si tu es frais ou fatigué."
        }
        return "Encore \(left) test\(left > 1 ? "s" : ""), à des jours différents, pour connaître ta variation normale. Ensuite, chaque test te dira si tu es frais ou fatigué."
    }
}
