import SwiftData
import SwiftUI

// MARK: - Réglage

/// La plage horaire du journal de l'historique (Réglages) : début et fin de journée, par pas de
/// 30 min, au moins 6 h d'écart. Par défaut 06:00 → 23:00.
enum JournalHours {
    static let startKey = "journal.start"
    static let endKey = "journal.end"
    static let defaultStart = 6 * 60
    static let defaultEnd = 23 * 60
    static let step = 30
    static let minSpan = 6 * 60

    static var start: Int { UserDefaults.standard.object(forKey: startKey) as? Int ?? defaultStart }
    static var end: Int { UserDefaults.standard.object(forKey: endKey) as? Int ?? defaultEnd }

    /// « 06:00 ».
    static func label(_ minutes: Int) -> String { String(format: "%02d:%02d", minutes / 60, minutes % 60) }

    /// Pour VoiceOver : « 6 heures », « 6 heures 30 ».
    static func spoken(_ minutes: Int) -> String {
        "\(minutes / 60) heures" + (minutes % 60 == 0 ? "" : " \(minutes % 60)")
    }
}

/// La carte des Réglages : début et fin réglables avec ‹ ›, et l'aperçu sur 24 h.
struct JournalHoursSettings: View {
    @Environment(\.theme) private var theme
    @AppStorage(JournalHours.startKey) private var start = JournalHours.defaultStart
    @AppStorage(JournalHours.endKey) private var end = JournalHours.defaultEnd

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            stepper("Début", value: start,
                    minus: { start = max(0, start - JournalHours.step) },
                    plus: { start = min(end - JournalHours.minSpan, start + JournalHours.step) })
            stepper("Fin", value: end,
                    minus: { end = max(start + JournalHours.minSpan, end - JournalHours.step) },
                    plus: { end = min(24 * 60, end + JournalHours.step) })
            DayRangeBar(start: start, end: end)
                .frame(height: 32)
                .accessibilityLabel("Journée affichée de \(JournalHours.spoken(start)) à \(JournalHours.spoken(end))")
            Text(symbols: "Hors de ces heures, une séance se place au bord, marquée ‹ ou ›.")
                .font(theme.font(13))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func stepper(_ label: String, value: Int, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack {
            Text(label.uppercased())
                .font(theme.font(13, .bold))
                .foregroundStyle(theme.text)
            Spacer()
            Button(action: minus) { Text(symbols: "‹").font(theme.font(17, .bold)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("\(label) plus tôt")
            Text(JournalHours.label(value))
                .font(theme.font(15, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .frame(width: 64)
            Button(action: plus) { Text(symbols: "›").font(theme.font(17, .bold)).frame(width: 44, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel("\(label) plus tard")
        }
        .buttonStyle(.plain)
        .foregroundStyle(theme.primary)
    }
}

/// Une barre de 24 h où la plage choisie est remplie.
private struct DayRangeBar: View {
    @Environment(\.theme) private var theme
    let start: Int
    let end: Int

    var body: some View {
        Canvas { context, size in
            let x = { (minutes: Int) -> CGFloat in 4 + (size.width - 8) * CGFloat(minutes) / CGFloat(24 * 60) }
            context.fill(Path(roundedRect: CGRect(x: 4, y: 6, width: size.width - 8, height: 6), cornerRadius: 3), with: .color(theme.grid))
            context.fill(Path(roundedRect: CGRect(x: x(start), y: 6, width: x(end) - x(start), height: 6), cornerRadius: 3),
                         with: .color(theme.primary))
            // Les libellés des bords rentrent vers l'intérieur : jamais rognés
            for hour in stride(from: 0, through: 24, by: 6) {
                let anchor: UnitPoint = hour == 0 ? .bottomLeading : (hour == 24 ? .bottomTrailing : .bottom)
                context.draw(Text("\(hour)h").font(theme.font(13)).foregroundStyle(theme.dim),
                             at: CGPoint(x: x(hour * 60), y: size.height), anchor: anchor)
            }
        }
    }
}

// MARK: - Le journal

/// Le journal de l'historique (skill reps-ux, § 9) : une ligne par jour, aujourd'hui en haut ;
/// en abscisse l'heure (plage des Réglages, graduée toutes les 3 h). Chaque séance est posée à son
/// heure en silhouette (une barre fine par série, verte si sa cible est atteinte), ★ si record ;
/// le total du jour à droite (Σ). Jour sans séance : pointillés (jamais « manqué » : pas de jours
/// prévus, METHODE-JOURS.md). Lignes alternées, aujourd'hui teinté, un filet sous chaque lundi.
/// Toucher une silhouette ouvre la séance.
struct JournalCard: View {
    @Environment(\.theme) private var theme
    @AppStorage(JournalHours.startKey) private var start = JournalHours.defaultStart
    @AppStorage(JournalHours.endKey) private var end = JournalHours.defaultEnd
    let stats: HistoryStats
    let onDelete: (SessionRecord) -> Void
    @State private var shownDays = 28
    /// La séance ouverte (poussée dans l'historique).
    @State private var opened: SessionRecord?

    /// Une ligne par jour, touchable en entier : 44 pt (HIG), plus avec un texte plus grand.
    @ScaledMetric(relativeTo: .footnote) private var rowHeight: CGFloat = 44
    /// Hauteur des silhouettes dans la ligne.
    private static let silhouetteHeight: CGFloat = 24
    /// Colonnes du jour et du total : elles suivent la taille du texte.
    @ScaledMetric(relativeTo: .footnote) private var labelWidth: CGFloat = 50
    @ScaledMetric(relativeTo: .footnote) private var totalWidth: CGFloat = 42
    /// Une séance posée au bord de la plage reste à l'intérieur : elle ne recouvre ni le jour ni
    /// le total.
    private static let edgeInset: CGFloat = 16
    /// La largeur d'une marque (★, ‹ ›, +n) au-dessus d'une silhouette, à l'échelle du texte.
    @ScaledMetric(relativeTo: .footnote) private var markWidth: CGFloat = 14

    var body: some View {
        let days = self.days
        let records = stats.recordSessions
        VStack(alignment: .leading, spacing: 6) {
            CardHeader(symbol: "calendar.day.timeline.left", title: "Journal") {
                MonitorLabel("\(JournalHours.label(start)) → \(JournalHours.label(end))")
                    .accessibilityLabel("de \(JournalHours.spoken(start)) à \(JournalHours.spoken(end))")
                MonitorLabel("reps")
                    .accessibilityLabel("répétitions du jour")
                    .frame(width: totalWidth, alignment: .trailing)
            }
            hourAxis
                .frame(height: 18)
                .accessibilityHidden(true)
            VStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    row(day, index: index, records: records)
                }
            }
            if let first = stats.sessions.last, let oldest = days.last, stats.calendar.startOfDay(for: first.start) < oldest {
                Button("+ 28 jours") { withAnimation { shownDays += 28 } }
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .padding(.top, 6)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay {
            if !theme.isSystem {
                RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Journal")
        .accessibilityChartDescriptor(descriptor)
        .navigationDestination(item: $opened) { session in
            SessionDetailView(session: session, stats: HistoryStats(sessions: stats.sessions, exercise: session.exercise))
        }
    }

    /// Le journal pour les Audio Graphs : le total de chaque jour, du plus ancien à aujourd'hui.
    private var descriptor: SeriesChartDescriptor {
        let points = days.reversed().map { day in
            (label: day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
             value: Double(stats.sessions.filter { stats.calendar.isDate($0.start, inSameDayAs: day) }.reduce(0) { $0 + $1.totalReps }))
        }
        return SeriesChartDescriptor(title: "Journal", summary: "Répétitions par jour, \(shownDays) derniers jours",
                                     xTitle: "Jour", yTitle: "Répétitions", points: points)
    }

    /// Les jours montrés, aujourd'hui d'abord.
    private var days: [Date] {
        let today = stats.calendar.startOfDay(for: stats.now)
        return (0..<shownDays).compactMap { stats.calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    /// La position d'une heure (minutes depuis minuit) dans la zone des silhouettes (0 … 1).
    private func share(_ minutes: Int) -> CGFloat {
        CGFloat(min(max(minutes - start, 0), end - start)) / CGFloat(max(end - start, 1))
    }

    private var hourAxis: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - labelWidth - totalWidth
            ForEach(Array(stride(from: (start + 179) / 180 * 180, through: end, by: 180)), id: \.self) { minutes in
                Text("\(minutes / 60)h")
                    .font(theme.font(13))
                    .foregroundStyle(theme.dim)
                    .fixedSize()
                    .position(x: labelWidth + width * share(minutes), y: 9)
            }
        }
    }

    /// Le jour, touchable en entier : une séance, on l'ouvre ; plusieurs, un menu (heure et total)
    /// les liste ; appui long, les supprimer une à une.
    @ViewBuilder
    private func row(_ day: Date, index: Int, records: Set<PersistentIdentifier>) -> some View {
        let sessions = Array(stats.sessions.filter { stats.calendar.isDate($0.start, inSameDayAs: day) }.reversed())
        let content = rowContent(day, index: index, sessions: sessions, records: records)
        Group {
            if sessions.count == 1, let session = sessions.first {
                Button { opened = session } label: { content }
                    .buttonStyle(.plain)
            } else if sessions.count > 1 {
                Menu {
                    ForEach(sessions, id: \.persistentModelID) { session in
                        Button("\(Format.time(session.start)) · \(session.totalReps) reps") { opened = session }
                    }
                } label: { content }
            } else {
                content
            }
        }
        .contextMenu {
            ForEach(sessions, id: \.persistentModelID) { session in
                Button(role: .destructive) { onDelete(session) } label: {
                    Label("Supprimer la séance de \(Format.time(session.start))", systemImage: "trash")
                }
            }
        }
    }

    private struct Placement {
        let session: SessionRecord
        let x: CGFloat
        let edge: String?
        let tick: Bool
    }

    /// Plus de 4 séances dans la journée : des traits (choix de l'app).
    private static let maxSilhouettes = 4

    /// Les séances du jour, de la plus tôt à la plus tard : chacune à son heure de début, décalée
    /// juste après la précédente si elles se chevauchent (largeur des marques comprise). Celles qui
    /// dépasseraient la fin de la plage s'y alignent par la droite, en repoussant les précédentes
    /// vers la gauche : rien ne déborde sur la colonne du total.
    private func placements(_ sessions: [SessionRecord], width: CGFloat) -> [Placement] {
        let tick = sessions.count > Self.maxSilhouettes
        let usable = max(width - 2 * Self.edgeInset, 0)
        let ordered = sessions.sorted { $0.start < $1.start }
        let records = stats.recordSessions
        var items: [(session: SessionRecord, x: CGFloat, footprint: CGFloat, edge: String?)] = []
        var nextFree: CGFloat = 0
        for session in ordered {
            let minutes = stats.calendar.component(.hour, from: session.start) * 60
                + stats.calendar.component(.minute, from: session.start)
            let edge = minutes < start ? "‹" : (minutes > end ? "›" : nil)
            let marks = JournalSilhouette.marks(sets: session.orderedSets.count, record: records.contains(session.persistentModelID),
                                                edge: edge, tick: tick, test: session.isTest)
            let footprint = max(JournalSilhouette.width(sets: session.orderedSets.count, tick: tick), CGFloat(marks) * markWidth)
            let x = max(labelWidth + Self.edgeInset + usable * share(minutes), nextFree)
            items.append((session, x, footprint, edge))
            nextFree = x + footprint + 2
        }
        // De droite à gauche : la dernière s'aligne sur la fin de la plage si elle la dépasse
        var limit = labelWidth + width - 2
        for index in items.indices.reversed() {
            items[index].x = max(min(items[index].x, limit - items[index].footprint), labelWidth)
            limit = items[index].x - 2
        }
        return items.map { Placement(session: $0.session, x: $0.x, edge: $0.edge, tick: tick) }
    }

    /// L'échelle commune des silhouettes sur la période affichée : la plus grande série, et le plus
    /// grand total d'une séance (pour les traits).
    private var scale: (set: Int, total: Int) {
        let oldest = days.last ?? stats.now
        let shown = stats.sessions.filter { $0.start >= oldest }
        return (shown.map(\.bestSet).max() ?? 1, shown.map(\.totalReps).max() ?? 1)
    }

    private func rowContent(_ day: Date, index: Int, sessions: [SessionRecord], records: Set<PersistentIdentifier>) -> some View {
        let isToday = stats.calendar.isDate(day, inSameDayAs: stats.now)
        let isMonday = Schedule.isoWeekday(day, calendar: stats.calendar) == 1
        let total = sessions.reduce(0) { $0 + $1.totalReps }
        return ZStack(alignment: .leading) {
            // Fond : aujourd'hui teinté, une ligne sur deux éclaircie
            Rectangle()
                .fill(isToday ? theme.primary.opacity(0.12)
                      : (index % 2 == 1 ? theme.text.opacity(theme.colorScheme == .light ? 0.07 : 0.05) : .clear))
            GeometryReader { geometry in
                let width = geometry.size.width - labelWidth - totalWidth
                // Graduations toutes les 3 h
                ForEach(Array(stride(from: (start + 179) / 180 * 180, through: end, by: 180)), id: \.self) { minutes in
                    Rectangle()
                        .fill(theme.grid)
                        .frame(width: 1, height: rowHeight)
                        .position(x: labelWidth + width * share(minutes), y: rowHeight / 2)
                }
                if sessions.isEmpty {
                    if day < stats.calendar.startOfDay(for: stats.now) {
                        Path { path in
                            path.move(to: CGPoint(x: labelWidth, y: rowHeight / 2))
                            path.addLine(to: CGPoint(x: labelWidth + width, y: rowHeight / 2))
                        }
                        .stroke(theme.line, style: StrokeStyle(lineWidth: 1, dash: [1, 4]))
                    }
                }
                // Posées à leur heure de début ; une séance qui en chevauche une autre se décale juste
                // après elle (pas d'empilement)
                ForEach(placements(sessions, width: width), id: \.session.persistentModelID) { placement in
                    JournalSilhouette(session: placement.session, record: records.contains(placement.session.persistentModelID),
                                      edge: placement.edge, height: Self.silhouetteHeight,
                                      top: placement.tick ? scale.total : scale.set, tick: placement.tick)
                        .offset(x: placement.x, y: (rowHeight - Self.silhouetteHeight) / 2 + 4)
                }
            }
            HStack {
                Text(dayLabel(day))
                    .font(theme.font(13, isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? theme.text : theme.dim)
                    .frame(width: labelWidth, alignment: .leading)
                    .padding(.leading, 2)
                Spacer()
                Text(total > 0 ? "\(total)" : "")
                    .font(theme.font(13, isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? theme.text : theme.dim)
                    .monospacedDigit()
                    .frame(width: totalWidth, alignment: .trailing)
                    .padding(.trailing, 2)
            }
        }
        .frame(height: rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(alignment: .bottom) {
            // Un filet plein sous chaque lundi : les semaines se séparent
            if isMonday { Rectangle().fill(theme.dim.opacity(0.6)).frame(height: 1) }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility(day, sessions: sessions, total: total))
    }

    private func dayLabel(_ day: Date) -> String {
        let text = day.formatted(.dateTime.weekday(.abbreviated))
        return text + " " + day.formatted(.dateTime.day())
    }

    private func accessibility(_ day: Date, sessions: [SessionRecord], total: Int) -> String {
        let name = Format.dayName(day)
        guard !sessions.isEmpty else { return "\(name) : repos" }
        let reached = sessions.filter { session in
            let sets = session.orderedSets.filter { $0.target != nil }
            return !sets.isEmpty && sets.allSatisfy { $0.reps >= ($0.target ?? .max) }
        }
        var text = "\(name) : \(sessions.count) séance\(sessions.count > 1 ? "s" : ""), \(total) répétitions"
        // Les tests et leurs échauffements sont dits comme tels
        for session in sessions where session.isTest {
            text += " ; test à \(Format.time(session.start))" + (session.testBest.map { " : \($0)" } ?? "")
            if session.orderedSets.contains(where: { $0.isWarmup }) { text += ", avec échauffement" }
        }
        if !reached.isEmpty { text += " ; cibles atteintes à " + reached.map { Format.time($0.start) }.joined(separator: ", ") }
        return text
    }
}

/// Une séance dans le journal, de largeur fixe et posée à son heure de début : une barre de 3 pt
/// par série (1 pt d'écart, 40 pt au plus : 10 séries, puis « +n »), à l'échelle commune du
/// journal ; verte si la cible de la série est atteinte, neutre sans cible. Au-dessus : ★ si
/// record, ‹ ou › hors de la plage. Au-delà de 4 séances dans la journée, un simple trait dont la
/// hauteur donne le total (choix de l'app).
private struct JournalSilhouette: View {
    @Environment(\.theme) private var theme
    let session: SessionRecord
    let record: Bool
    let edge: String?
    let height: CGFloat
    /// L'échelle commune : la plus grande série (barres) ou le plus grand total (traits) de la
    /// période affichée.
    let top: Int
    /// Un trait (plus de 4 séances ce jour-là) au lieu des barres.
    var tick = false
    /// Barres montrées au plus : la silhouette reste étroite sur sa ligne.
    static let maxBars = 10
    static let barWidth: CGFloat = 3
    /// Les marques au-dessus des barres : leur décalage suit la taille du texte.
    @ScaledMetric(relativeTo: .footnote) private var lift: CGFloat = 14
    static let gap: CGFloat = 1

    /// Le nombre de marques posées au-dessus (« +n » compte double).
    static func marks(sets: Int, record: Bool, edge: String?, tick: Bool, test: Bool = false) -> Int {
        (edge != nil ? 1 : 0) + (record ? 1 : 0) + (test ? 1 : 0) + (!tick && sets > maxBars ? 2 : 0)
    }

    /// La largeur des barres (sans les marques, posées au-dessus).
    static func width(sets: Int, tick: Bool) -> CGFloat {
        if tick { return 2 }
        let count = CGFloat(min(max(sets, 1), maxBars))
        return count * barWidth + (count - 1) * gap
    }

    var body: some View {
        let sets = session.orderedSets
        let scale = CGFloat(max(top, 1))
        HStack(alignment: .bottom, spacing: Self.gap) {
            if tick {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.primary)
                    .frame(width: 2, height: max(3, height * CGFloat(session.totalReps) / scale))
            } else {
                ForEach(Array(sets.prefix(Self.maxBars).enumerated()), id: \.offset) { _, set in
                    RoundedRectangle(cornerRadius: 0.8)
                        // Verte si la cible est atteinte ; sans cible, neutre ; l'échauffement en gris pâle
                        .fill(set.isWarmup ? theme.dim.opacity(0.4)
                              : (set.target.map { set.reps >= $0 ? theme.ok : theme.primary } ?? theme.dim))
                        .frame(width: Self.barWidth, height: max(3, height * min(CGFloat(set.reps) / scale, 1)))
                }
            }
        }
        .frame(height: height, alignment: .bottom)
        .overlay(alignment: .topLeading) {
            // Les marques au-dessus des barres : la largeur ne dépend que des séries
            HStack(spacing: 2) {
                if edge == "‹" { marker("‹") }
                // Une séance de test se reconnaît : ◆
                if session.isTest { marker("◆") }
                if !tick, sets.count > Self.maxBars { marker("+\(sets.count - Self.maxBars)") }
                if record { marker("★") }
                if edge == "›" { marker("›") }
            }
            .fixedSize()
            .offset(y: -lift)
        }
    }

    private func marker(_ symbol: String) -> some View {
        Text(symbols: symbol)
            .font(theme.font(13, .bold))
            .foregroundStyle(theme.text)
    }
}
