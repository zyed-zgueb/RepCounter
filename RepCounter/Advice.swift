import SwiftUI

// MARK: - Conseil

/// Un conseil d'entraînement, tiré de l'historique d'un exercice, affiché comme action de la
/// phase Construction (`PhaseCard`). Les signaux de fatigue et de pic de charge sont devenus des
/// phases (`Phase.swift`) ; le pic de charge, fondé sur le rapport charge aiguë / chronique,
/// est retiré (aucun effet causal démontré : Impellizzeri et al. 2020, IJSPP 15(6):907–913).
struct Advice {
    enum Kind { case plateau, recordInReach }

    let kind: Kind
    let title: String
    /// L'action, en quelques mots.
    let short: String

    static func make(stats: HistoryStats) -> Advice? {
        plateau(stats: stats) ?? recordInReach(stats: stats)
    }

    /// Plateau : au moins 3 séances notées en 3 semaines sans dépasser le meilleur score d'avant.
    private static func plateau(stats: HistoryStats) -> Advice? {
        let cutoff = stats.now.addingTimeInterval(-21 * 86_400)
        let recent = stats.sessions.filter { $0.start > cutoff }.compactMap(\.performanceIndex)
        let before = stats.sessions.filter { $0.start <= cutoff }.compactMap(\.performanceIndex)
        guard recent.count >= 3, let best = before.max(), let recentBest = recent.max(), recentBest <= best else { return nil }
        return Advice(kind: .plateau, title: "Plateau", short: "repos plus court ou une série de plus")
    }

    /// Record à portée : une série récente à 1 ou 2 répétitions du record de série.
    private static func recordInReach(stats: HistoryStats) -> Advice? {
        guard let record = stats.bestSet, let recent = stats.bestSet(lastDays: 14),
              record.value - recent >= 1, record.value - recent <= 2,
              stats.now.timeIntervalSince(record.date) > 14 * 86_400 else { return nil }
        let missing = record.value - recent
        return Advice(kind: .recordInReach, title: "Record à portée", short: "il t'en manque \(missing)")
    }
}

// MARK: - Forme

/// Le panneau Forme de l'historique : la forme de la dernière séance mesurable (en % de la
/// référence), et la courbe des 12 dernières sur la bande de variation normale.
struct FormPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let results = stats.formResults
        VStack(alignment: .leading, spacing: 12) {
            MonitorLabel("Forme")
            if let last = results.last {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(Int(last.result.percent.rounded())) %")
                        .font(theme.font(40, .bold))
                        .foregroundStyle(formColor(last.result.zone, theme: theme))
                        .monospacedDigit()
                    Text(last.result.zone.title.uppercased())
                        .font(theme.font(13, .bold))
                        .foregroundStyle(formColor(last.result.zone, theme: theme))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Text(Format.dayName(last.session.start))
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                }
                if results.count >= 2 {
                    FormChart(results: results.suffix(12).map(\.result))
                        .frame(height: 70)
                    HStack {
                        Text("\(min(results.count, 12)) dernières séances")
                        Spacer()
                        Text("bande : ta variation normale")
                    }
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
                }
            }
            Text(caption(hasResult: !results.isEmpty))
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }

    private func caption(hasResult: Bool) -> String {
        let rule = "Vitesse de tes répétitions et maintien de cette vitesse au fil des séries, comparés à tes séances habituelles."
        guard !hasResult else { return rule }
        let count = min(stats.measuredSessionCount, FormResult.baselineSessions)
        return "Référence en cours : \(count) séance\(count > 1 ? "s" : "") sur \(FormResult.baselineSessions) (une série d'au moins \(FormMeasure.minimumReps) répétitions). " + rule
    }
}

/// La tuile Forme de l'historique : la forme de la dernière séance mesurable, sa zone et la
/// courbe. Tant que la référence se construit, où l'on en est (« 2 / 3 séances »).
struct FormTile: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let results = stats.formResults
        HistoryTile(title: "Forme") {
            if let last = results.last {
                let color = formColor(last.result.zone, theme: theme)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(last.result.percent.rounded()))")
                        .font(theme.font(32, .bold))
                        .monospacedDigit()
                    Text("%")
                        .font(theme.font(14, .bold))
                }
                .foregroundStyle(color)
                Text(last.result.zone.title)
                    .font(theme.font(11, .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                if results.count >= 2 {
                    FormChart(results: results.suffix(12).map(\.result), dots: false)
                        .frame(height: 26)
                }
            } else {
                // En cours : la référence demande 3 séances mesurables ; la suivante a sa forme
                let count = min(stats.measuredSessionCount, FormResult.baselineSessions)
                Text("\(count) / \(FormResult.baselineSessions)")
                    .font(theme.font(32, .bold))
                    .foregroundStyle(theme.dim)
                    .monospacedDigit()
                Text(count < FormResult.baselineSessions ? "séances de référence" : "référence prête : forme à la prochaine séance")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Couleur d'une zone de forme.
func formColor(_ zone: FormZone, theme: AppTheme) -> Color {
    switch zone {
    case .tired: return theme.warn
    case .normal: return theme.primary
    case .fresh: return theme.ok
    }
}

/// Courbe de la forme (en % de la référence) sur la bande de variation normale autour de 100 %.
private struct FormChart: View {
    @Environment(\.theme) private var theme
    let results: [FormResult]
    /// Points colorés par zone (masqués dans la tuile, trop petite).
    var dots = true
    private static let low = 85.0, high = 115.0

    var body: some View {
        Canvas { context, size in
            let y = { (percent: Double) -> CGFloat in
                4 + (size.height - 8) * CGFloat(1 - (min(max(percent, Self.low), Self.high) - Self.low) / (Self.high - Self.low))
            }
            let band = results.last?.band ?? 3
            context.fill(Path(CGRect(x: 0, y: y(100 + band), width: size.width, height: y(100 - band) - y(100 + band))),
                         with: .color(theme.primary.opacity(0.08)))
            var reference = Path()
            reference.move(to: CGPoint(x: 0, y: y(100)))
            reference.addLine(to: CGPoint(x: size.width, y: y(100)))
            context.stroke(reference, with: .color(theme.dim.opacity(0.6)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            let points = results.enumerated().map { index, result in
                CGPoint(x: size.width * CGFloat(index) / CGFloat(max(results.count - 1, 1)), y: y(result.percent))
            }
            var line = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { line.move(to: point) } else { line.addLine(to: point) }
            }
            context.stroke(line, with: .color(theme.primary.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            for (index, point) in points.enumerated() where dots || index == points.count - 1 {
                let radius: CGFloat = index == points.count - 1 ? 4.5 : 2.5
                let zone = results[index].zone
                let color = zone == .tired ? theme.warn : (zone == .fresh ? theme.ok : theme.primary)
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(color))
            }
        }
    }
}
