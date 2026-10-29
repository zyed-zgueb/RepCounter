import SwiftData
import SwiftUI

/// Historique d'un exercice (ou de tous, Σ) : le passé seulement (skill reps-ux). Une place pour
/// chaque chose : le score d'endurance et sa tendance, l'activité (la semaine et la régularité),
/// puis les records et la liste des séances. Le détail de chaque bloc s'ouvre d'une touche. La
/// phase et la Forme sont dans la carte État du Coaching.
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
                HStack {
                    Text("HISTORIQUE")
                        .font(theme.font(16, .bold))
                        .tracking(3)
                        .foregroundStyle(theme.text)
                    Spacer()
                    IconButton(systemImage: "xmark") { dismiss() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                VerticalScroll {
                    VStack(spacing: 14) {
                        if !practiced.isEmpty {
                            ExerciseFilter(exercises: practiced, selection: $exercise)
                        }
                        if stats.isEmpty {
                            emptyState
                        } else {
                            // Le passé seulement : la phase et la Forme sont dans la carte État du Coaching
                            if let exercise {
                                NavigationLink(value: HistoryPage.endurance) {
                                    EnduranceTile(stats: stats, exercise: exercise)
                                }
                                .buttonStyle(.plain)
                            }
                            NavigationLink(value: HistoryPage.activity) { RepsWeekCard(stats: stats, all: sessions, planned: exercise != nil) }
                                .buttonStyle(.plain)
                            if exercise != nil { BestSetCard(stats: stats) }
                            SessionsPanel(stats: stats, showsExercise: exercise == nil) { session in
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
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: SessionRecord.self) { session in
                SessionDetailView(session: session, stats: HistoryStats(sessions: sessions, exercise: session.exercise))
            }
            .navigationDestination(for: HistoryPage.self) { page in
                detail(page, stats: stats)
            }
        }
        .tint(theme.primary)
        .onAppear { showAllIfAbsent(practiced) }
        .onChange(of: practiced) { showAllIfAbsent($0) }
    }

    /// Un exercice jamais pratiqué (ou dont on a supprimé les séances) n'est pas dans le filtre :
    /// on montre tous les exercices.
    private func showAllIfAbsent(_ practiced: [Exercise]) {
        if let exercise, !practiced.contains(exercise) { self.exercise = nil }
    }

    @ViewBuilder
    private func detail(_ page: HistoryPage, stats: HistoryStats) -> some View {
        switch page {
        case .endurance:
            HistoryDetailView(title: "Score d'endurance") {
                if let exercise { EndurancePanel(stats: stats, exercise: exercise) }
            }

        case .activity:
            HistoryDetailView(title: "Activité") {
                HistoryPanel(title: "Régularité") { RegularityCalendar(stats: stats) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            // Le cadran est réservé au comptage (skill reps-ux)
            Image(systemName: "chart.bar")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(theme.line)
            MonitorLabel("Aucune séance")
            Text("Tes séances s'afficheront ici.")
                .font(theme.font(12))
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
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonitorLabel(title)
                Spacer(minLength: 8)
                accessory()
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }
}

extension HistoryPanel where Accessory == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.init(title: title, accessory: { EmptyView() }, content: content)
    }
}

/// Détails de l'historique, ouverts d'une touche sur leur bloc.
enum HistoryPage: Hashable {
    case endurance, activity
}

/// Une tuile (moitié de largeur) : un titre, une valeur, une mini-courbe ; une touche ouvre son détail.
struct HistoryTile<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                MonitorLabel(title)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.dim)
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// Écran de détail de l'historique : retour, titre, contenu.
struct HistoryDetailView<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                IconButton(systemImage: "chevron.left") { dismiss() }
                Spacer()
                Text(title.uppercased())
                    .font(theme.font(13, .bold))
                    .tracking(2)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            VerticalScroll {
                VStack(spacing: 14) { content() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
                    Text("Σ").font(.system(size: 18, weight: .bold))
                }
                ForEach(exercises) { exercise in
                    item(exercise) { ExerciseIcon(exercise: exercise, size: 22) }
                }
            }
            MonitorLabel(selection?.title ?? "Tous les exercices", color: theme.text)
        }
    }

    private func item<Content: View>(_ exercise: Exercise?, @ViewBuilder content: () -> Content) -> some View {
        let on = exercise == selection
        let corner = max(theme.radius, 4) * 2
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
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

/// Répétitions par semaine (skill reps-ux, § 9 : un graphique) : l'histogramme des 12 dernières
/// semaines, la semaine en cours en couleur, la moyenne en pointillés ; en tête, la tendance ▲▼
/// par rapport à la semaine dernière ; dessous, la semaine en symboles (● faite, ○ prévue
/// restante) et le temps. Une touche ouvre la régularité.
private struct RepsWeekCard: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let all: [SessionRecord]
    /// Un exercice (son plan donne les séances prévues restantes) ; Σ : seulement les faites.
    let planned: Bool

    var body: some View {
        let weeks = stats.lastWeeks(12)
        let volumes = weeks.map { stats.volume(inWeek: $0) }
        let volume = stats.weekVolume, previous = stats.previousWeekVolume
        HistoryPanel(title: "Répétitions / semaine", accessory: {
            HStack(spacing: 6) {
                if previous > 0 {
                    let change = (Double(volume) - Double(previous)) / Double(previous) * 100
                    Text("\(change >= 0 ? "▲" : "▼") \(Format.percent(change)) %")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(change >= 0 ? theme.ok : theme.text)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(theme.dim)
            }
        }) {
            VolumeBars(volumes: volumes)
                .frame(height: 96)
                .accessibilityLabel("Répétitions par semaine : \(volume) cette semaine" + (previous > 0 ? ", \(previous) la semaine dernière" : ""))
            HStack {
                MonitorLabel("cette semaine")
                Spacer()
                Text(weekSymbols + " · " + Format.minutes(stats.weekDuration))
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
            }
        }
        .contentShape(Rectangle())
    }

    /// Un ● par séance faite cette semaine, un ○ par séance prévue restante (plan de l'exercice).
    private var weekSymbols: String {
        let done = stats.weekSessions
        let plan = planned ? stats.plan(all: all) : nil
        let remaining = plan.flatMap { plan in plan.currentWeek.map { max(plan.perWeek - $0.done, 0) } } ?? 0
        return String(repeating: "●", count: done) + (remaining > 0 ? " " + String(repeating: "○", count: remaining) : "")
            + (done == 0 && remaining == 0 ? "—" : "")
    }
}

/// L'histogramme du volume : la semaine en cours en couleur, la moyenne en pointillés.
private struct VolumeBars: View {
    @Environment(\.theme) private var theme
    let volumes: [Int]

    var body: some View {
        Canvas { context, size in
            guard !volumes.isEmpty else { return }
            let most = CGFloat(max(volumes.max() ?? 1, 1))
            let base = size.height - 14
            let slot = size.width / CGFloat(volumes.count)
            let width = min(slot * 0.62, 18)
            let height = { (value: Int) -> CGFloat in (base - 16) * CGFloat(value) / most }
            let mean = Double(volumes.dropLast().reduce(0, +)) / Double(max(volumes.count - 1, 1))
            var average = Path()
            average.move(to: CGPoint(x: 0, y: base - height(Int(mean.rounded()))))
            average.addLine(to: CGPoint(x: size.width, y: base - height(Int(mean.rounded()))))
            context.stroke(average, with: .color(theme.dim.opacity(0.7)), style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))
            for (index, value) in volumes.enumerated() {
                let current = index == volumes.count - 1
                let x = CGFloat(index) * slot + (slot - width) / 2
                let h = max(height(value), value > 0 ? 2 : 1)
                context.fill(Path(roundedRect: CGRect(x: x, y: base - h, width: width, height: h), cornerRadius: 1.5),
                             with: .color(current ? theme.primary : theme.line))
                if current {
                    context.draw(Text("\(value)").font(theme.font(9, .bold)).foregroundStyle(theme.text),
                                 at: CGPoint(x: x + width / 2, y: base - h - 7))
                }
            }
            context.draw(Text("S−11").font(theme.font(8)).foregroundStyle(theme.dim), at: CGPoint(x: 2, y: size.height - 4), anchor: .leading)
            context.draw(Text("cette sem.").font(theme.font(8)).foregroundStyle(theme.primary),
                         at: CGPoint(x: size.width - 2, y: size.height - 4), anchor: .trailing)
        }
    }
}

/// Meilleure série (un exercice) : la courbe des meilleures séries par semaine sur 12 semaines,
/// les records en ★ sur la courbe. Remplace les tuiles de records.
private struct BestSetCard: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let weeks = stats.lastWeeks(12)
        let points = bestByWeek(weeks)
        HistoryPanel(title: "Meilleure série", accessory: {
            if let record = stats.bestSet {
                Text("★ \(record.value)")
                    .font(theme.font(13, .bold))
                    .foregroundStyle(theme.text)
            }
        }) {
            BestCurve(points: points)
                .frame(height: 86)
                .accessibilityLabel("Meilleure série par semaine" + (stats.bestSet.map { ", record \($0.value)" } ?? ""))
        }
    }

    /// Par semaine : la meilleure série (nil sans séance) et si c'est un record à ce moment-là.
    private func bestByWeek(_ weeks: [Date]) -> [(value: Int?, record: Bool)] {
        var best = stats.sessions.filter { $0.start < (weeks.first ?? stats.now) }.map(\.bestSet).max() ?? 0
        return weeks.map { week in
            let value = stats.sessions(inWeek: week).map(\.bestSet).max()
            guard let value, value > 0 else { return (nil, false) }
            let record = value > best
            best = max(best, value)
            return (value, record)
        }
    }
}

private struct BestCurve: View {
    @Environment(\.theme) private var theme
    let points: [(value: Int?, record: Bool)]

    var body: some View {
        Canvas { context, size in
            let values = points.compactMap(\.value)
            guard let low = values.min(), let high = values.max() else { return }
            let span = Double(max(high - low, 4))
            let x = { (index: Int) -> CGFloat in 10 + (size.width - 20) * CGFloat(index) / CGFloat(max(points.count - 1, 1)) }
            let y = { (value: Int) -> CGFloat in size.height - 10 - (size.height - 24) * CGFloat(Double(value - low) / span) }
            var line = Path()
            var started = false
            for (index, point) in points.enumerated() {
                guard let value = point.value else { continue }
                let p = CGPoint(x: x(index), y: y(value))
                if started { line.addLine(to: p) } else { line.move(to: p); started = true }
            }
            context.stroke(line, with: .color(theme.primary), lineWidth: 1.5)
            for (index, point) in points.enumerated() {
                guard let value = point.value else { continue }
                let p = CGPoint(x: x(index), y: y(value))
                if point.record {
                    context.draw(Text("★").font(theme.font(11)).foregroundStyle(theme.text), at: p)
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(theme.primary))
                }
            }
            if let last = points.lastIndex(where: { $0.value != nil }), let value = points[last].value {
                context.draw(Text("\(value)").font(theme.font(9, .bold)).foregroundStyle(theme.text),
                             at: CGPoint(x: x(last), y: y(value) - 11))
            }
        }
    }
}


/// Courbe d'une valeur : x de 0 (à gauche) à `span` (à droite).
struct LineChart: View {
    @Environment(\.theme) private var theme
    let points: [(x: Double, value: Double)]
    let span: Double

    var body: some View {
        Canvas { context, size in
            let values = points.map(\.value)
            guard let low = values.min(), let high = values.max() else { return }
            let span = max(high - low, 0.5)
            let location = { (point: (x: Double, value: Double)) -> CGPoint in
                CGPoint(x: size.width * CGFloat(min(max(point.x / max(span, 0.001), 0), 1)),
                        y: 4 + (size.height - 8) * CGFloat(1 - (point.value - low) / span))
            }
            var path = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { path.move(to: location(point)) } else { path.addLine(to: location(point)) }
            }
            context.stroke(path, with: .color(theme.primary), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            for (index, point) in points.enumerated() {
                let radius: CGFloat = index == points.count - 1 ? 4 : 2
                let center = location(point)
                context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(theme.primary))
            }
        }
        .shadow(color: theme.primary.opacity(0.4 * min(theme.glow, 1)), radius: 4)
    }
}

/// Calendrier des 16 dernières semaines : un carré par jour, plus intense quand on a fait plus.
private struct RegularityCalendar: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    private static let weeks = 16

    var body: some View {
        let daily = stats.dailyVolume()
        let firstWeek = stats.lastWeeks(Self.weeks).first ?? stats.thisWeek
        let today = stats.calendar.startOfDay(for: stats.now)
        let most = max(daily.values.max() ?? 1, 1)
        let activeDays = daily.keys.filter { $0 >= firstWeek }.count
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 4) {
                ForEach(0..<7, id: \.self) { day in
                    HStack(spacing: 0) {
                        Text(dayLetter(day, from: firstWeek))
                            .font(theme.font(9))
                            .foregroundStyle(theme.dim)
                            .frame(width: 12, alignment: .leading)
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
            HStack {
                Text("\(activeDays) jour\(activeDays > 1 ? "s" : "") actif\(activeDays > 1 ? "s" : "") en \(Self.weeks) sem.")
                Spacer()
                Text("moins")
                ForEach(0..<4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(level == 0 ? theme.line : theme.primary.opacity([0, 0.35, 0.65, 1][level]))
                        .frame(width: 9, height: 9)
                }
                Text("plus")
            }
            .font(theme.font(11))
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

/// Liste des séances par jour, le plus récent d'abord : la date une seule fois, puis les séances
/// du jour à leurs heures. Aujourd'hui est mis en avant. Une touche ouvre le détail d'une séance,
/// un appui long propose de la supprimer.
private struct SessionsPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let showsExercise: Bool
    let onDelete: (SessionRecord) -> Void

    /// Séances regroupées par jour (les séances arrivent déjà de la plus récente à la plus ancienne).
    private var days: [(day: Date, sessions: [SessionRecord])] {
        var groups: [(day: Date, sessions: [SessionRecord])] = []
        for session in stats.sessions {
            let day = stats.calendar.startOfDay(for: session.start)
            if groups.last?.day == day {
                groups[groups.count - 1].sessions.append(session)
            } else {
                groups.append((day, [session]))
            }
        }
        return groups
    }

    var body: some View {
        let records = stats.recordSessions
        HistoryPanel(title: "Séances", accessory: { MonitorLabel("\(stats.sessions.count) au total") }) {
            VStack(spacing: 14) {
                ForEach(days, id: \.day) { group in
                    let today = stats.calendar.isDateInToday(group.day)
                    VStack(spacing: 0) {
                        header(group.day, sessions: group.sessions, today: today)
                        ForEach(Array(group.sessions.enumerated()), id: \.element.persistentModelID) { index, session in
                            if index > 0 { Rectangle().fill(theme.line).frame(height: 1) }
                            NavigationLink(value: session) {
                                row(session, isRecord: records.contains(session.persistentModelID))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) { onDelete(session) } label: {
                                    Label("Supprimer la séance", systemImage: "trash")
                                }
                            }
                        }
                    }
                    // Aujourd'hui : un fond léger, la journée qui compte le plus
                    .padding(.horizontal, today ? 10 : 0)
                    .padding(.top, today ? 10 : 0)
                    .background(today ? theme.primary.opacity(0.07) : .clear,
                                in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                        .stroke(today ? theme.primary.opacity(0.35) : .clear, lineWidth: 1))
                    .padding(.horizontal, today ? -10 : 0)
                }
            }
        }
    }

    /// La date du jour, et ce qu'on y a fait : le total (un exercice) ou le nombre de séances (Σ).
    private func header(_ day: Date, sessions: [SessionRecord], today: Bool) -> some View {
        let count = sessions.count
        let summary = showsExercise
            ? "\(count) séance\(count > 1 ? "s" : "")"
            : "\(sessions.reduce(0) { $0 + $1.totalReps }) reps" + (count > 1 ? " · \(count) séances" : "")
        return HStack(alignment: .firstTextBaseline) {
            Text(dayTitle(day).uppercased())
                .font(theme.font(12, .bold))
                .tracking(1.5)
                .foregroundStyle(today ? theme.primary : theme.text)
            Spacer(minLength: 8)
            MonitorLabel(summary)
        }
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func dayTitle(_ day: Date) -> String {
        if stats.calendar.isDateInToday(day) { return "Aujourd'hui" }
        if stats.calendar.isDateInYesterday(day) { return "Hier" }
        return Format.shortDay(day)
    }

    /// Une séance : l'heure, la silhouette des séries (une barre par série, verte si sa cible est
    /// atteinte), le total, ★ si record.
    private func row(_ session: SessionRecord, isRecord: Bool) -> some View {
        HStack(spacing: 12) {
            if showsExercise {
                ExerciseIcon(exercise: session.exercise, size: 20)
                    .foregroundStyle(theme.primary)
            }
            Text(Format.time(session.start))
                .font(theme.font(13, .bold))
                .foregroundStyle(theme.dim)
                .monospacedDigit()
                .frame(width: 48, alignment: .leading)
            SetSilhouette(sets: session.orderedSets)
                .frame(height: 22)
            Spacer(minLength: 6)
            Text((isRecord ? "★ " : "") + "\(session.totalReps)")
                .font(theme.font(20, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.dim)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Format.time(session.start)), \(session.orderedSets.count) séries, \(session.totalReps) répétitions\(isRecord ? ", record" : "")")
    }
}

/// La silhouette d'une séance : une barre par série, à l'échelle de la plus longue ; verte si la
/// série a atteint sa cible.
private struct SetSilhouette: View {
    @Environment(\.theme) private var theme
    let sets: [SetRecord]

    var body: some View {
        let top = max(sets.map(\.reps).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(sets.prefix(12).enumerated()), id: \.offset) { _, set in
                RoundedRectangle(cornerRadius: 1)
                    .fill(set.target.map { set.reps >= $0 } == true ? theme.ok : theme.primary.opacity(0.85))
                    .frame(width: 7, height: max(3, 22 * CGFloat(set.reps) / CGFloat(top)))
            }
        }
        .frame(height: 22, alignment: .bottom)
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
            HStack {
                IconButton(systemImage: "chevron.left") { dismiss() }
                Spacer()
                Text("\(Format.shortDay(session.start)) · \(Format.time(session.start))".uppercased())
                    .font(theme.font(13, .bold))
                    .tracking(2)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
                Color.clear.frame(width: 36, height: 36)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            VerticalScroll {
                VStack(spacing: 14) {
                    overview
                    HistoryPanel(title: "Séries", accessory: { seriesAccessory(sets) }) {
                        SetBarsChart(session: session)
                            .frame(height: 120)
                    }
                    if sets.contains(where: { $0.repDurations.count >= 2 }) {
                        HistoryPanel(title: "Rythme", accessory: { MonitorLabel("s / rep") }) {
                            RhythmChart(sets: sets)
                                .frame(height: 106)
                            Text("Durée de chaque répétition")
                                .font(theme.font(11))
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
        .toolbar(.hidden, for: .navigationBar)
    }

    /// « 2 / 3 ✓ » : séries qui ont atteint leur cible.
    @ViewBuilder
    private func seriesAccessory(_ sets: [SetRecord]) -> some View {
        let targeted = sets.filter { $0.target != nil }
        if !targeted.isEmpty {
            let reached = targeted.filter { $0.reps >= ($0.target ?? .max) }.count
            Text("\(reached) / \(targeted.count) ✓")
                .font(theme.font(12, .bold))
                .foregroundStyle(reached == targeted.count ? theme.ok : theme.text)
        }
    }

    /// Le total en grand, l'exercice et la durée.
    private var overview: some View {
        VStack(spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text((stats.recordSessions.contains(session.persistentModelID) ? "★ " : "") + "\(session.totalReps)")
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
        let form = stats.form(of: session)
        let previous = stats.previous(of: session)
        if form != nil || session.effort != nil || previous != nil || session.performanceIndex != nil {
            HistoryPanel(title: "Séance") {
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
                    line("vs \(Format.dayName(previous.start))",
                         delta == 0 ? "= \(previous.totalReps)" : "\(delta > 0 ? "▲" : "▼") \(Format.signed(delta))",
                         color: delta > 0 ? theme.ok : theme.text)
                }
            }
        }
    }

    private func line(_ label: String, _ value: String, color: Color) -> some View {
        HStack {
            MonitorLabel(label)
            Spacer()
            Text(value)
                .font(theme.font(13, .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
    }
}

/// Les séries en barres : contour pointillé = cible (s'il y en avait une), plein = fait, ✓ si
/// atteinte ; entre les barres, ◷ et le repos réel.
private struct SetBarsChart: View {
    @Environment(\.theme) private var theme
    let session: SessionRecord

    var body: some View {
        let sets = session.orderedSets
        Canvas { context, size in
            guard !sets.isEmpty else { return }
            let top = CGFloat(sets.map { max($0.reps, $0.target ?? 0) }.max() ?? 1)
            let base = size.height - 16
            let count = CGFloat(sets.count)
            let gap: CGFloat = sets.count > 1 ? min(42, size.width * 0.15) : 0
            let width = min((size.width - gap * (count - 1)) / count, 56)
            let total = width * count + gap * (count - 1)
            var x = (size.width - total) / 2
            let height = { (value: Int) -> CGFloat in (base - 18) * CGFloat(value) / max(top, 1) }
            for (index, set) in sets.enumerated() {
                let reached = set.target.map { set.reps >= $0 } ?? false
                if let target = set.target {
                    let h = height(target)
                    context.stroke(Path(roundedRect: CGRect(x: x, y: base - h, width: width, height: h), cornerRadius: 2),
                                   with: .color(theme.dim), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
                let h = max(height(set.reps), 2)
                context.fill(Path(roundedRect: CGRect(x: x + 4, y: base - h, width: width - 8, height: h), cornerRadius: 1.5),
                             with: .color((reached ? theme.ok : theme.primary).opacity(0.85)))
                let labelTop = base - max(h, set.target.map(height) ?? 0) - 8
                context.draw(Text("\(set.reps)\(reached ? " ✓" : "")").font(theme.font(10, .bold))
                                .foregroundStyle(reached ? theme.ok : theme.text),
                             at: CGPoint(x: x + width / 2, y: labelTop))
                context.draw(Text("S\(index + 1)").font(theme.font(9)).foregroundStyle(theme.dim),
                             at: CGPoint(x: x + width / 2, y: size.height - 5))
                if index < sets.count - 1, let rest = session.rest(before: index + 1) {
                    context.draw(Text("◷").font(theme.font(10)).foregroundStyle(theme.dim),
                                 at: CGPoint(x: x + width + gap / 2, y: base - 8))
                    context.draw(Text(Format.clock(rest)).font(theme.font(8)).foregroundStyle(theme.dim),
                                 at: CGPoint(x: x + width + gap / 2, y: size.height - 5))
                }
                x += width + gap
            }
        }
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let sets = session.orderedSets
        let reached = sets.filter { set in set.target.map { set.reps >= $0 } ?? false }.count
        let targets = sets.filter { $0.target != nil }.count
        return "Séries : " + sets.map { "\($0.reps)" }.joined(separator: ", ")
            + (targets > 0 ? ", \(reached) cibles atteintes sur \(targets)" : "")
    }
}

/// Une courbe par série : la durée de chacune de ses répétitions, côte à côte.
private struct RhythmChart: View {
    @Environment(\.theme) private var theme
    let sets: [SetRecord]

    var body: some View {
        let series = sets.map(\.repDurations)
        let all = series.flatMap { $0 }
        Canvas { context, size in
            guard let low = all.min(), let high = all.max() else { return }
            let span = max(high - low, 0.2)
            let chartHeight = size.height - 16
            let slots = series.reduce(0) { $0 + max($1.count, 1) } + max(series.count - 1, 0)
            let step = size.width / CGFloat(max(slots, 1))
            var x: CGFloat = 0
            for (index, durations) in series.enumerated() {
                let color = theme.secondary.mixed(with: theme.primary, by: Double(index) / Double(max(series.count - 1, 1)))
                var path = Path()
                for (i, duration) in durations.enumerated() {
                    let point = CGPoint(x: x + CGFloat(i) * step,
                                        y: 4 + (chartHeight - 8) * CGFloat(1 - (duration - low) / span))
                    if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                context.draw(Text(String(format: "S%02d", index + 1)).font(theme.font(9)).foregroundColor(theme.dim),
                             at: CGPoint(x: x, y: size.height - 5), anchor: .leading)
                x += CGFloat(max(durations.count, 1) + 1) * step
            }
        }
    }
}
