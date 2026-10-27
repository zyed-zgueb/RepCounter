import SwiftUI

// MARK: - Conseil

/// Un conseil d'entraînement, tiré de l'historique d'un exercice. Au plus un à la fois, le plus
/// important d'abord, toujours avec une action proposée ; aucun quand rien ne le justifie.
struct Advice {
    enum Kind { case fatigue, loadSpike, plateau, recordInReach }

    let kind: Kind
    let title: String
    let text: String

    static func make(stats: HistoryStats) -> Advice? {
        fatigue(stats: stats) ?? loadSpike(stats: stats) ?? plateau(stats: stats) ?? recordInReach(stats: stats)
    }

    /// Signal de fatigue : une séance récente avec une forme dans la zone fatiguée, ou le score
    /// d'endurance en baisse deux séances de suite alors que le volume ne baisse pas
    /// (signe de surmenage, qui précède le surentraînement).
    private static func fatigue(stats: HistoryStats) -> Advice? {
        if let last = stats.formResults.last, last.result.zone == .tired,
           stats.now.timeIntervalSince(last.session.start) < 3 * 86_400 {
            return Advice(kind: .fatigue, title: "Signal de fatigue",
                          text: "Forme à \(Int(last.result.percent.rounded())) % \(Format.dayName(last.session.start)) : répétitions plus lentes ou vitesse moins bien tenue que d'habitude. Une séance légère ou un jour de repos ?")
        }
        let scores = stats.sessions.compactMap(\.performanceIndex)   // les plus récents d'abord
        if scores.count >= 3, scores[0] < scores[1], scores[1] < scores[2],
           stats.weekVolume >= stats.previousWeekVolume, stats.weekVolume > 0 {
            return Advice(kind: .fatigue, title: "Signal de fatigue",
                          text: "Score d'endurance en baisse sur 2 séances alors que ton volume ne baisse pas. Une séance légère ou un jour de repos ?")
        }
        return nil
    }

    /// Pic de charge : le volume de la semaine dépasse de plus de 50 % la moyenne des 4 semaines
    /// précédentes (rapport charge aiguë / chronique au-delà de 1,5).
    private static func loadSpike(stats: HistoryStats) -> Advice? {
        let weeks = stats.lastWeeks(5).dropLast()
        let volumes = weeks.map { stats.volume(inWeek: $0) }
        guard volumes.filter({ $0 > 0 }).count >= 2 else { return nil }
        let chronic = Double(volumes.reduce(0, +)) / Double(volumes.count)
        guard chronic > 0, Double(stats.weekVolume) > 1.5 * chronic else { return nil }
        let rise = Int((Double(stats.weekVolume) / chronic * 100 - 100).rounded())
        return Advice(kind: .loadSpike, title: "Pic de charge",
                      text: "+\(rise) % de volume par rapport à tes 4 dernières semaines. Garde ce niveau la semaine prochaine plutôt que d'augmenter encore.")
    }

    /// Plateau : au moins 3 séances notées en 3 semaines sans dépasser le meilleur score d'avant.
    private static func plateau(stats: HistoryStats) -> Advice? {
        let cutoff = stats.now.addingTimeInterval(-21 * 86_400)
        let recent = stats.sessions.filter { $0.start > cutoff }.compactMap(\.performanceIndex)
        let before = stats.sessions.filter { $0.start <= cutoff }.compactMap(\.performanceIndex)
        guard recent.count >= 3, let best = before.max(), let recentBest = recent.max(), recentBest <= best else { return nil }
        return Advice(kind: .plateau, title: "Plateau",
                      text: "Pas de progrès du score d'endurance depuis 3 semaines. Varie : repos plus court entre les séries, ou une série de plus.")
    }

    /// Record à portée : une série récente à 1 ou 2 répétitions du record de série.
    private static func recordInReach(stats: HistoryStats) -> Advice? {
        guard let record = stats.bestSet, let recent = stats.bestSet(lastDays: 14),
              record.value - recent >= 1, record.value - recent <= 2,
              stats.now.timeIntervalSince(record.date) > 14 * 86_400 else { return nil }
        let missing = record.value - recent
        return Advice(kind: .recordInReach, title: "Record à portée",
                      text: "Ton record de série est \(record.value). Tu en as fait \(recent) récemment : il t'en manque \(missing).")
    }
}

/// La carte Conseil, en tête de l'historique d'un exercice.
struct AdviceCard: View {
    @Environment(\.theme) private var theme
    let advice: Advice

    private var color: Color {
        switch advice.kind {
        case .fatigue, .loadSpike: return theme.warn
        case .plateau: return theme.primary
        case .recordInReach: return theme.ok
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonitorLabel("Conseil")
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                VStack(alignment: .leading, spacing: 3) {
                    Text(advice.title)
                        .font(theme.font(14, .bold))
                        .foregroundStyle(theme.text)
                    Text(advice.text)
                        .font(theme.font(12))
                        .foregroundStyle(theme.dim)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
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
            for (index, point) in points.enumerated() {
                let radius: CGFloat = index == points.count - 1 ? 4.5 : 2.5
                let zone = results[index].zone
                let color = zone == .tired ? theme.warn : (zone == .fresh ? theme.ok : theme.primary)
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(color))
            }
        }
    }
}
