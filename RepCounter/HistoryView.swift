import Charts
import SwiftData
import SwiftUI

/// Historique d'un exercice (ou de tous, Σ) : le passé seulement (skill reps-ux), en deux
/// cartes. « 12 semaines » (verdict de progression, meilleure série, volume) ouvre la page
/// Progrès : score d'endurance, volume détaillé, régularité. « Journal » : les jours sur une
/// frise horaire. La phase et la Forme sont dans la carte État du Coaching.
struct HistoryView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionRecord.start, order: .reverse) private var sessions: [SessionRecord]
    /// nil : tous les exercices.
    @State private var exercise: Exercise?

    init(exercise: Exercise?) {
        _exercise = State(initialValue: exercise)
    }

    /// Exercices pratiqués, dans l'ordre du catalogue : le filtre ne montre qu'eux.
    private var practiced: [Exercise] {
        let done = Set(sessions.map(\.exercise))
        return Exercise.allCases.filter(done.contains)
    }

    var body: some View {
        let stats = HistoryStats(sessions: sessions, exercise: exercise)
        NavigationStack {
            VStack(spacing: 0) {
                VerticalScroll {
                    VStack(spacing: 20) {
                        if !practiced.isEmpty {
                            ExerciseFilter(exercises: practiced, selection: $exercise)
                        }
                        if stats.isEmpty {
                            emptyState
                        } else {
                            // Le passé seulement : la phase et la Forme sont dans la carte État du Coaching ;
                            // le score d'endurance, dans le détail de la carte 12 semaines (skill reps-ux)
                            // Deux cartes : 12 semaines, puis le journal
                            NavigationLink(value: HistoryPage.activity) {
                                WeeksCard(stats: stats, planned: exercise != nil)
                            }
                            .buttonStyle(.plain)
                            JournalCard(stats: stats) { session in
                                withAnimation { modelContext.delete(session) }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .animation(.easeInOut(duration: 0.25), value: exercise)
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { CloseButton() }
            }
            .navigationDestination(for: SessionRecord.self) { session in
                SessionDetailView(session: session, stats: HistoryStats(sessions: sessions, exercise: session.exercise))
            }
            .navigationDestination(for: HistoryPage.self) { page in
                detail(page, stats: stats)
            }
        }
        .tint(theme.primary)
        .onAppear { showAllIfAbsent(practiced) }
        .onChange(of: practiced) { _, new in showAllIfAbsent(new) }
    }

    /// Un exercice jamais pratiqué (ou dont on a supprimé les séances) n'est pas dans le filtre :
    /// on montre tous les exercices.
    private func showAllIfAbsent(_ practiced: [Exercise]) {
        if let exercise, !practiced.contains(exercise) { self.exercise = nil }
    }

    @ViewBuilder
    private func detail(_ page: HistoryPage, stats: HistoryStats) -> some View {
        switch page {
        case .activity:
            HistoryDetailView(title: "Progrès") {
                if let exercise { EndurancePanel(stats: stats, exercise: exercise) }
                HistoryPanel(title: "Reps par semaine", symbol: "chart.bar") {
                    VolumeBars(volumes: stats.lastWeeks(12).map { stats.volume(inWeek: $0) })
                }
                HistoryPanel(title: "Régularité", symbol: "calendar") { RegularityCalendar(stats: stats) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            // Le cadran est réservé au comptage (skill reps-ux)
            Image(systemName: "chart.bar")
                .font(theme.font(40, .light))
                .foregroundStyle(theme.line)
            MonitorLabel("Aucune séance")
            Text("Tes séances s'afficheront ici.")
                .font(theme.font(17))
                .foregroundStyle(theme.dim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
        }
        .padding(.top, 40)
    }
}

// MARK: - Composants

/// Panneau d'historique : titre, élément à droite, contenu.
private struct HistoryPanel<Accessory: View, Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    /// Le SF Symbol de l'en-tête, façon Santé (nil : une simple étiquette).
    var symbol: String? = nil
    /// La carte s'ouvre : un chevron.
    var opens = false
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let symbol {
                CardHeader(symbol: symbol, title: title, opens: opens, trailing: accessory)
            } else {
                HStack {
                    MonitorLabel(title)
                    Spacer(minLength: 8)
                    accessory()
                }
            }
            content()
        }
        .padding(20)
        .cardBackground(theme)
    }
}

extension HistoryPanel where Accessory == EmptyView {
    init(title: String, symbol: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, symbol: symbol, accessory: { EmptyView() }, content: content)
    }
}

/// Détails de l'historique, ouverts d'une touche sur leur bloc.
enum HistoryPage: Hashable {
    case activity
}

/// Écran de détail de l'historique (poussé) : grand titre natif, retour par glissement, contenu.
struct HistoryDetailView<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VerticalScroll {
                VStack(spacing: 20) { content() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Σ et les exercices pratiqués, en grille.
private struct ExerciseFilter: View {
    @Environment(\.theme) private var theme
    let exercises: [Exercise]
    @Binding var selection: Exercise?

    var body: some View {
        VStack(spacing: 8) {
            // Σ et les exercices : une grille de 6 colonnes, sans défilement
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                item(nil) {
                    Text("Tous").font(theme.font(15, .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                ForEach(exercises) { exercise in
                    item(exercise) { ExerciseIcon(exercise: exercise, size: 22) }
                }
            }
            MonitorLabel(selection?.title ?? "Tous les exercices", color: theme.text)
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item<Content: View>(_ exercise: Exercise?, @ViewBuilder content: () -> Content) -> some View {
        let on = exercise == selection
        let corner = max(theme.radius, 4) * 2
        return Button {
            selection = exercise
        } label: {
            content()
                .foregroundStyle(on ? theme.primary : theme.dim)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(on ? theme.primary.opacity(0.12) : theme.panel,
                            in: RoundedRectangle(cornerRadius: corner, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(on ? theme.primary : theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(exercise?.title ?? "Tous les exercices")
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// 12 semaines en un graphique, un axe des semaines commun : en haut la meilleure série par
/// semaine (★ les semaines de record, « ★ 32 » le record actuel), en bas le volume en barres (la
/// semaine en cours en couleur avec sa valeur, « · » sans séance). En tête, le verdict de
/// progression du score d'endurance (« ▲ en progrès », « = stable », « ▼ en recul », rien tant
/// qu'il n'est pas établi) ; la tendance du volume étiquette les barres (« reps / sem. · ▲ 4 % »).
/// La semaine en cours se lit dans le journal, le suivi du plan dans le Coaching. Une touche
/// ouvre la page Progrès (score d'endurance, volume détaillé, régularité).
private struct WeeksCard: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    /// Un exercice : le record actuel s'étiquette « ★ 32 » ; Σ : pas de record commun.
    let planned: Bool

    var body: some View {
        let weeks = stats.lastWeeks(12)
        let volumes = weeks.map { stats.volume(inWeek: $0) }
        HistoryPanel(title: "12 semaines", symbol: "chart.bar.fill", opens: true, accessory: {
            if let verdict {
                Text(symbols: verdict)
                    .font(theme.font(15, .bold))
                    // Une tendance n'est pas une atteinte (§ 5) : couleur de texte, ▲ = ▼ portent le sens
                    .foregroundStyle(theme.text)
            }
        }) {
            WeeksChart(volumes: volumes, best: bestByWeek(weeks), record: planned ? stats.bestSet?.value : nil,
                       trend: Self.trend(volumes))
                .accessibilityElement(children: .contain)
                .accessibilityLabel(accessibility(volume: volumes.last ?? 0, trend: Self.trend(volumes)))
        }
        .contentShape(Rectangle())
    }

    /// Le verdict de progression du score d'endurance (un exercice), seulement s'il est établi.
    /// Sans score (séances de moins de 3 séries enchaînées), le verdict sur la série max, dit
    /// comme tel.
    private var verdict: String? {
        guard planned else { return nil }
        let onScore = stats.performanceIndex() != nil
        let suffix = onScore ? "" : " sur la série max"
        switch (onScore ? stats.progressVerdict : stats.bestSetVerdict).kind {
        case .up: return "▲ en progrès" + suffix
        case .stable: return "= stable" + suffix
        case .down: return "▼ en recul" + suffix
        case .pending, .unreliable: return nil
        }
    }

    /// Semaines précédentes actives nécessaires pour une moyenne (choix de l'app).
    static let trendWeeks = 2

    /// Volume de la semaine en cours face à la moyenne des semaines précédentes affichées qui ont
    /// au moins une séance, en %. Rien sans séance cette semaine ou avec moins de 2 semaines actives.
    static func trend(_ volumes: [Int]) -> Double? {
        guard let current = volumes.last, current > 0 else { return nil }
        let previous = volumes.dropLast().filter { $0 > 0 }
        guard previous.count >= trendWeeks else { return nil }
        let mean = Double(previous.reduce(0, +)) / Double(previous.count)
        return (Double(current) - mean) / mean * 100
    }

    /// Par semaine : la meilleure série (nil sans séance), si c'est un record à ce moment-là, et
    /// si la semaine a un test (◆ sur la courbe).
    private func bestByWeek(_ weeks: [Date]) -> [(value: Int?, record: Bool, test: Bool)] {
        var best = stats.sessions.filter { $0.start < (weeks.first ?? stats.now) }.map(\.bestSet).max() ?? 0
        return weeks.map { week in
            let sessions = stats.sessions(inWeek: week)
            let value = sessions.map(\.bestSet).max()
            guard let value, value > 0 else { return (nil, false, false) }
            let record = value > best
            best = max(best, value)
            return (value, record, sessions.contains { $0.isTest })
        }
    }

    private func accessibility(volume: Int, trend: Double?) -> String {
        var parts = ["12 semaines"]
        if planned, let record = stats.bestSet { parts.append("meilleure série \(record.value)") }
        parts.append("\(volume) répétitions cette semaine")
        if let verdict { parts.append(verdict.dropFirst(2).description) }
        if let trend { parts.append("\(trend >= 0 ? "plus" : "moins") \(Int(abs(trend).rounded())) % que la moyenne") }
        return parts.joined(separator: " : ")
    }
}

/// Le graphique des 12 semaines (Swift Charts) : la courbe de la meilleure série au-dessus, le
/// volume en barres dessous, sur le même axe des semaines (skill reps-ux, § 3). Un doigt posé
/// choisit une semaine : sa règle traverse les deux graphiques, ses valeurs s'affichent en haut.
private struct WeeksChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var lineHeight: CGFloat = 72
    @ScaledMetric(relativeTo: .body) private var barHeight: CGFloat = 64
    let volumes: [Int]
    let best: [(value: Int?, record: Bool, test: Bool)]
    /// Le record de toujours (un exercice), écrit « record : 32 » au-dessus de la courbe.
    let record: Int?
    /// Le volume de la semaine face à la moyenne des précédentes, en % (nil : pas assez d'historique).
    let trend: Double?

    private struct Point: Identifiable {
        let id: Int
        let value: Int
        let record: Bool
        let test: Bool
    }

    private var points: [Point] {
        best.enumerated().compactMap { index, item in
            item.value.map { Point(id: index, value: $0, record: item.record, test: item.test) }
        }
    }

    private var current: Int { volumes.count - 1 }
    private var domain: ClosedRange<Double> { -0.5...(Double(volumes.count) - 0.5) }

    var body: some View {
        let points = self.points
        VStack(alignment: .leading, spacing: 6) {
            MonitorLabel("série max")
            if points.count < 2 {
                // Une courbe demande deux semaines : en attendant, un état en cours
                Text("La courbe apparaît après 2 semaines.")
                    .font(theme.font(15))
                    .foregroundStyle(theme.dim)
                    .frame(maxWidth: .infinity)
                    .frame(height: lineHeight)
            } else {
                Chart {
                    ForEach(points) { point in
                        LineMark(x: .value("Semaine", Double(point.id)), y: .value("Série max", Double(point.value)))
                            .foregroundStyle(theme.primary)
                        PointMark(x: .value("Semaine", Double(point.id)), y: .value("Série max", Double(point.value)))
                            .foregroundStyle(theme.primary)
                            .symbolSize(24)
                            // Plus de losange sur les semaines de test : peu compréhensible et trop
                            // gros (avis de Vincent) ; la courbe suffit
                    }
                    // Le record de toujours : une ligne fine, son chiffre en petit au-dessus (avis de Vincent)
                    if let record {
                        RuleMark(y: .value("Record", Double(record)))
                            .foregroundStyle(theme.dim)
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(position: .top, alignment: .leading, spacing: 2) {
                                Text("record \(record)")
                                    .font(theme.font(13))
                                    .foregroundStyle(theme.dim)
                            }
                            .accessibilityLabel("Record de toujours")
                            .accessibilityValue("\(record)")
                    }
                }
                .chartXScale(domain: domain)
                .chartXAxis(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartYAxis {
                    AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
                }
                .frame(height: lineHeight)
            }
            MonitorLabel(trend.map { "reps par semaine · " + Format.trend($0, unit: " %") } ?? "reps par semaine")
            Chart {
                ForEach(Array(volumes.enumerated()), id: \.offset) { index, value in
                    BarMark(x: .value("Semaine", Double(index)), y: .value("Répétitions", Double(value)), width: .fixed(12))
                        .foregroundStyle(index == current ? theme.primary : theme.line)
                        .cornerRadius(2)
                        .annotation(position: .top) {
                            if index == current, value > 0 {
                                Text("\(value)")
                                    .font(theme.font(13, .bold))
                                    .foregroundStyle(theme.text)
                            }
                        }
                }
            }
            .chartXScale(domain: domain)
            .chartXAxis {
                AxisMarks(values: [0.0, Double(current)]) { value in
                    // Les libellés des bords rentrent vers l'intérieur : jamais coupés
                    let last = Int((value.as(Double.self) ?? 0).rounded()) == current
                    AxisValueLabel(anchor: last ? .topTrailing : .topLeading) {
                        Text(last ? "cette semaine" : "il y a \(current) semaines")
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 2)))
            }
            .frame(height: barHeight)
        }
    }
}

/// L'histogramme du volume (Swift Charts) : la semaine en cours en couleur, la moyenne des
/// précédentes en pointillés ; un doigt posé donne la valeur d'une semaine.
private struct VolumeBars: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 110
    let volumes: [Int]
    @State private var selected: Int?

    /// L'axe est continu (Double) : la sélection revient à la semaine la plus proche.
    private var selection: Binding<Double?> {
        Binding(get: { selected.map(Double.init) }, set: { selected = $0.map { Int($0.rounded()) } })
    }

    var body: some View {
        let current = volumes.count - 1
        // La moyenne des semaines précédentes qui ont une séance, comme la tendance de la carte ;
        // aucune ligne sous 2 semaines actives
        let previous = volumes.dropLast().filter { $0 > 0 }
        let mean: Double? = previous.count >= WeeksCard.trendWeeks
            ? Double(previous.reduce(0, +)) / Double(previous.count) : nil
        Chart {
            ForEach(Array(volumes.enumerated()), id: \.offset) { index, value in
                BarMark(x: .value("Semaine", Double(index)), y: .value("Répétitions", Double(value)), width: .fixed(14))
                    .foregroundStyle(index == current ? theme.primary : theme.line)
                    .cornerRadius(2)
            }
            if let mean {
                RuleMark(y: .value("Moyenne", mean))
                    .foregroundStyle(theme.dim.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("moyenne \(Int(mean.rounded()))")
                            .font(theme.font(13))
                            .foregroundStyle(theme.dim)
                    }
            }
            if let selected, volumes.indices.contains(selected) {
                RuleMark(x: .value("Semaine", Double(selected)))
                    .foregroundStyle(theme.dim.opacity(0.5))
                    .annotation(position: .top, spacing: 2, overflowResolution: ChartKit.overflow) {
                        SelectionLabel(title: "\(volumes[selected]) reps",
                                       detail: selected == current ? "cette semaine" : "il y a \(current - selected) semaines")
                    }
            }
        }
        .chartXScale(domain: -0.5...(Double(volumes.count) - 0.5))
        .chartXAxis {
            AxisMarks(values: [0.0, Double(current)]) { value in
                let last = Int((value.as(Double.self) ?? 0).rounded()) == current
                AxisValueLabel(anchor: last ? .topTrailing : .topLeading) {
                    Text(last ? "cette semaine" : "il y a \(current) semaines")
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
        }
        .chartXSelection(value: selection)
        .frame(height: height)
    }
}

/// Courbe d'une valeur (Swift Charts) : x de 0 (à gauche) à `span` (à droite) ; un doigt posé
/// donne la valeur la plus proche.
struct LineChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 90
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 44
    let points: [(x: Double, value: Double)]
    let span: Double
    /// Une courbe d'appoint dans une carte : sans graduations, plus basse.
    var compact = false
    @State private var selected: Double?

    private struct Point: Identifiable {
        let id: Int
        let x: Double
        let value: Double
    }

    var body: some View {
        let points = self.points.enumerated().map { Point(id: $0.offset, x: $0.element.x, value: $0.element.value) }
        let chosen = selected.flatMap { x in points.min { abs($0.x - x) < abs($1.x - x) } }
        Chart {
            ForEach(points) { point in
                LineMark(x: .value("Jour", point.x), y: .value("Score", Double(point.value)))
                    .foregroundStyle(theme.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                PointMark(x: .value("Jour", point.x), y: .value("Score", Double(point.value)))
                    .foregroundStyle(theme.primary)
                    .symbolSize(point.id == points.count - 1 ? 50 : 16)
            }
            if let chosen {
                RuleMark(x: .value("Jour", chosen.x))
                    .foregroundStyle(theme.dim.opacity(0.5))
                    .annotation(position: .top, spacing: 2, overflowResolution: ChartKit.overflow) {
                        SelectionLabel(title: "\(Int(chosen.value.rounded()))")
                    }
            }
        }
        .chartXScale(domain: 0...Swift.max(span, 0.001))
        .chartXAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            if !compact {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
            }
        }
        .chartXSelection(value: $selected)
        .frame(height: compact ? compactHeight : height)
    }
}

/// Calendrier des 16 dernières semaines : un carré par jour, plus intense quand on a fait plus.
private struct RegularityCalendar: View {
    @Environment(\.theme) private var theme
    /// La colonne des lettres du jour suit la taille du texte.
    @ScaledMetric(relativeTo: .caption2) private var letterWidth: CGFloat = 12
    let stats: HistoryStats
    private static let weeks = 16

    var body: some View {
        let daily = stats.dailyVolume()
        let firstWeek = stats.lastWeeks(Self.weeks).first ?? stats.thisWeek
        let today = stats.calendar.startOfDay(for: stats.now)
        let most = max(daily.values.max() ?? 1, 1)
        let activeDays = daily.keys.filter { $0 >= firstWeek }.count
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    HStack(spacing: 0) {
                        Text(dayLetter(day, from: firstWeek))
                            .font(theme.font(13))
                            .foregroundStyle(theme.dim)
                            .frame(width: letterWidth, alignment: .leading)
                        ForEach(0..<Self.weeks, id: \.self) { week in
                            let date = stats.calendar.date(byAdding: .day, value: week * 7 + day, to: firstWeek) ?? firstWeek
                            Spacer(minLength: 2)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(cellColor(date > today ? nil : daily[date] ?? 0, most: most))
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            // Le compte sur sa ligne, la légende dessous : rien ne se coupe
            Text("\(activeDays) jour\(activeDays > 1 ? "s" : "") actif\(activeDays > 1 ? "s" : "") en \(Self.weeks) semaines")
                .font(theme.font(15))
                .foregroundStyle(theme.dim)
            HStack(spacing: 6) {
                Text("moins")
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? theme.line : theme.primary.opacity([0, 0.35, 0.65, 1][level]))
                        .frame(width: 9, height: 9)
                }
                Text("plus")
            }
            .font(theme.font(13))
            .foregroundStyle(theme.dim)
        }
    }

    /// Couleur d'un jour : vide (à venir), sans séance, ou trois intensités.
    private func cellColor(_ volume: Int?, most: Int) -> Color {
        guard let volume else { return .clear }
        guard volume > 0 else { return theme.line.opacity(0.9) }
        let level = Double(volume) / Double(most)
        return theme.primary.opacity(level > 0.66 ? 1 : (level > 0.33 ? 0.65 : 0.35))
    }

    private func dayLetter(_ day: Int, from week: Date) -> String {
        let date = stats.calendar.date(byAdding: .day, value: day, to: week) ?? week
        return String(date.formatted(.dateTime.weekday(.narrow)).prefix(1)).uppercased()
    }
}

// MARK: - Détail d'une séance

/// Une séance : total, écart et record, tableau des séries (avec les récupérations), et le
/// rythme rep par rep, qui montre la fatigue arriver en fin de série.
struct SessionDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let session: SessionRecord
    let stats: HistoryStats

    var body: some View {
        let sets = session.orderedSets
        VStack(spacing: 0) {
            VerticalScroll {
                VStack(spacing: 20) {
                    overview
                    HistoryPanel(title: "Séries", symbol: "chart.bar.xaxis", accessory: { seriesAccessory(sets) }) {
                        SetBarsChart(session: session)
                    }
                    if sets.contains(where: { $0.repDurations.count >= 2 }) {
                        HistoryPanel(title: "Rythme", symbol: "metronome", accessory: { MonitorLabel("secondes par rep") }) {
                            RhythmChart(sets: sets)
                            Text("Durée de chaque répétition")
                                .font(theme.font(15))
                                .foregroundStyle(theme.dim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    footnotes
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("\(Format.shortDay(session.start)) · \(Format.time(session.start))")
        .navigationBarTitleDisplayMode(.large)
    }

    /// « 2 / 3 ✓ » : séries qui ont atteint leur cible.
    @ViewBuilder
    private func seriesAccessory(_ sets: [SetRecord]) -> some View {
        let targeted = sets.filter { $0.target != nil }
        if !targeted.isEmpty {
            let reached = targeted.filter { $0.reps >= ($0.target ?? .max) }.count
            Text("\(reached) cible\(reached > 1 ? "s" : "") sur \(targeted.count)")
                .font(theme.font(15, .bold))
                .foregroundStyle(reached == targeted.count ? theme.ok : theme.text)
        }
    }

    /// Le total en grand, l'exercice et la durée.
    private var overview: some View {
        VStack(spacing: 4) {
            if let best = session.testBest {
                // Une séance de test se reconnaît en tête : « ◆ test » et son résultat
                Text(symbols: "◆ test · \(best) d'affilée")
                    .font(theme.font(15, .bold))
                    .foregroundStyle(theme.max)
            }
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(symbols: (stats.recordSessions.contains(session.persistentModelID) ? "★ " : "") + "\(session.totalReps)")
                    .font(theme.font(46, .bold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                MonitorLabel("\(session.exercise.shortTitle.lowercased()) · \(Format.clock(session.duration))")
            }
            if let load = session.loadDescription {
                MonitorLabel(load)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Forme, effort, et comparaison avec la séance précédente : trois lignes courtes.
    @ViewBuilder
    private var footnotes: some View {
        // Pas de Forme sur un comptage juste à moins de 90 % (comme la carte État)
        let form = stats.countingIsReliable ? stats.form(of: session) : nil
        let previous = stats.previous(of: session)
        if form != nil || session.effort != nil || previous != nil || session.performanceIndex != nil {
            HistoryPanel(title: "Séance", symbol: "figure.strengthtraining.traditional") {
                if let form {
                    line("Forme", "\(Int(form.percent.rounded())) %", color: formColor(form.zone, theme: theme))
                }
                if let effort = session.effort {
                    line("Effort", "\(effort) / 10", color: theme.text)
                }
                if let index = session.performanceIndex {
                    line("Score d'endurance", "\(Int(index.rounded()))", color: theme.text)
                }
                if let previous {
                    let delta = session.totalReps - previous.totalReps
                    line("Depuis \(Format.dayName(previous.start))",
                         delta == 0 ? "= \(previous.totalReps)" : Format.trend(Double(delta)),
                         color: theme.text)
                }
            }
        }
    }

    private func line(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            MonitorLabel(label)
            Spacer()
            Text(symbols: value)
                .font(theme.font(15, .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

/// Les séries en barres (Swift Charts) : barre pâle = cible (s'il y en avait une), pleine = fait,
/// verte et ✓ si atteinte ; sous chaque série, ◷ et le repos réel qui l'a précédée.
private struct SetBarsChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 130
    let session: SessionRecord

    private struct Bar: Identifiable {
        let id: Int
        /// La catégorie, telle que VoiceOver et les Audio Graphs la lisent (« test, série 2 »).
        let name: String
        /// Le libellé affiché sous la barre (« ◆ S2 », « échauf. »).
        let label: String
        let reps: Int
        let target: Int?
        let rest: TimeInterval?
        var role: SetRole?
        var reached: Bool { target.map { reps >= $0 } ?? false }
    }

    var body: some View {
        let bars = session.orderedSets.enumerated().map { index, set in
            Bar(id: index,
                name: set.isWarmup ? "échauffement" : (set.isTest ? "test, série \(index + 1)" : "série \(index + 1)"),
                label: set.isWarmup ? "échauf." : (set.isTest ? "◆ série \(index + 1)" : "série \(index + 1)"),
                reps: set.reps, target: set.target, rest: index > 0 ? session.rest(before: index) : nil,
                role: set.role.flatMap(SetRole.init))
        }
        Chart {
            ForEach(bars) { bar in
                if let target = bar.target {
                    BarMark(x: .value("Série", bar.name), yStart: .value("Cible", 0.0), yEnd: .value("Cible", Double(target)),
                            width: .ratio(0.8))
                        .foregroundStyle(theme.line.opacity(0.6))
                        .cornerRadius(3)
                }
                BarMark(x: .value("Série", bar.name), yStart: .value("Répétitions", 0.0), yEnd: .value("Répétitions", Double(bar.reps)),
                        width: .ratio(0.5))
                    // Sans cible : couleur neutre, ni ✓ ni vert ; échauffement en gris pâle, test en rouge
                    .foregroundStyle(bar.role == .warmup ? theme.dim.opacity(0.4)
                                     : (bar.role == .test ? theme.max
                                        : (bar.reached ? theme.ok : (bar.target == nil ? theme.dim : theme.primary))))
                    .cornerRadius(2)
                    .annotation(position: .top) {
                        Text(symbols: "\(bar.reps)\(bar.reached ? " ✓" : "")")
                            .font(theme.font(13, .bold))
                            .foregroundStyle(bar.reached ? theme.ok : theme.text)
                    }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let name = value.as(String.self), let bar = bars.first(where: { $0.name == name }) {
                        VStack(spacing: 1) {
                            Text(symbols: bar.label)
                            if let rest = bar.rest {
                                Text(symbols: "◷ \(Format.clock(rest))")
                            }
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
        }
        .frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let sets = session.orderedSets
        let reached = sets.filter { set in set.target.map { set.reps >= $0 } ?? false }.count
        let targets = sets.filter { $0.target != nil }.count
        // L'échauffement et les séries de test sont dits comme tels
        return "Séries : " + sets.map { set in
            set.isWarmup ? "échauffement \(set.reps)" : (set.isTest ? "test \(set.reps)" : "\(set.reps)")
        }.joined(separator: ", ")
            + (targets > 0 ? ", \(reached) cibles atteintes sur \(targets)" : "")
    }
}

/// Une courbe par série (Swift Charts) : la durée de chacune de ses répétitions, côte à côte.
private struct RhythmChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 110
    let sets: [SetRecord]

    private struct Point: Identifiable {
        let id: Int
        let position: Int
        let duration: Double
        let series: String
    }

    var body: some View {
        // Les séries se suivent sur l'axe, une case vide entre deux
        var position = 0
        var points: [Point] = []
        for (index, set) in sets.enumerated() {
            for duration in set.repDurations {
                points.append(Point(id: points.count, position: position, duration: duration,
                                    series: "série \(index + 1)"))
                position += 1
            }
            position += 1
        }
        let names = (0..<sets.count).map { "série \($0 + 1)" }
        let colors = (0..<sets.count).map { index in
            theme.secondary.mixed(with: theme.primary, by: Double(index) / Double(max(sets.count - 1, 1)))
        }
        return Chart(points) { point in
            LineMark(x: .value("Répétition", point.position), y: .value("Durée (s)", point.duration),
                     series: .value("Série", point.series))
                .foregroundStyle(by: .value("Série", point.series))
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartForegroundStyleScale(domain: names, range: colors)
        .chartLegend(position: .bottom, alignment: .leading)
        .chartXAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
        }
        .frame(height: height)
    }
}
