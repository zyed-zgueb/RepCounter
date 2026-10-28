import SwiftData
import SwiftUI

/// Historique d'un exercice (ou de tous, Σ), en quatre blocs, une place pour chaque chose :
/// le conseil (s'il y en a un), le score d'endurance et la forme côte à côte, l'activité (la
/// semaine et la régularité), puis les records et la liste des séances. Le détail de chaque bloc
/// s'ouvre d'une touche.
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
                            if let exercise {
                                if let advice = Advice.make(stats: stats) { AdviceCard(advice: advice) }
                                HStack(spacing: 10) {
                                    NavigationLink(value: HistoryPage.endurance) {
                                        EnduranceTile(stats: stats, exercise: exercise)
                                    }
                                    if exercise != .auto {
                                        NavigationLink(value: HistoryPage.form) { FormTile(stats: stats) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            NavigationLink(value: HistoryPage.activity) { ActivityPanel(stats: stats) }
                                .buttonStyle(.plain)
                            if exercise != nil { RecordsPanel(stats: stats) }
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
        case .form:
            HistoryDetailView(title: "Forme") { FormPanel(stats: stats) }
        case .activity:
            HistoryDetailView(title: "Activité") { VolumePanel(stats: stats) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Dial(face: DialFace(lit: 0, palette: .pale)) { _ in
                MonitorLabel("Aucune séance")
            }
            .frame(width: 180, height: 180)
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
    case endurance, form, activity
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
private struct HistoryDetailView<Content: View>: View {
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

/// L'activité : la semaine en cours (cadran rempli selon la meilleure semaine, et les chiffres
/// clés), puis la régularité sur 16 semaines. Une touche ouvre le volume sur 12 semaines.
private struct ActivityPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        HistoryPanel(title: "Activité", accessory: {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.dim)
        }) {
            WeekSummary(stats: stats)
            Rectangle().fill(theme.line).frame(height: 1)
            RegularityCalendar(stats: stats)
        }
        .contentShape(Rectangle())
    }
}

/// Cette semaine : un cadran (rempli selon la meilleure semaine) et les chiffres clés.
private struct WeekSummary: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let volume = stats.weekVolume, previous = stats.previousWeekVolume
        let best = max(stats.bestWeek?.value ?? volume, 1)
        HStack(spacing: 18) {
            Dial(face: DialFace(lit: Int(Double(DialFace.tickCount) * min(Double(volume) / Double(best), 1)), palette: .gradient)) { side in
                VStack(spacing: 2) {
                    Text("\(volume)")
                        .font(theme.font(side * 0.26, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    MonitorLabel("reps")
                }
                .padding(side * 0.18)
            }
            .frame(width: 128, height: 128)

            VStack(alignment: .leading, spacing: 10) {
                MonitorLabel("Cette semaine", color: theme.text)
                VStack(alignment: .leading, spacing: 2) {
                    if previous > 0 {
                        let change = (Double(volume) - Double(previous)) / Double(previous) * 100
                        Text("\(change >= 0 ? "▲" : "▼") \(Format.percent(change)) %")
                            .font(theme.font(20, .bold))
                            .foregroundStyle(change >= 0 ? theme.ok : theme.dim)
                        Text("vs semaine dernière (\(previous))")
                            .font(theme.font(11))
                            .foregroundStyle(theme.dim)
                    } else {
                        Text(volume > 0 ? "Bonne reprise" : "Pas encore de séance")
                            .font(theme.font(14, .bold))
                            .foregroundStyle(volume > 0 ? theme.ok : theme.dim)
                    }
                }
                keyValue("Séances", "\(stats.weekSessions)")
                keyValue("Temps", Format.minutes(stats.weekDuration))
                keyValue("Régularité", stats.weekStreak > 1 ? "\(stats.weekStreak) sem. de suite" : "\(stats.weekStreak) sem.")
            }
        }
    }

    private func keyValue(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            MonitorLabel(key)
            Spacer(minLength: 6)
            Text(value)
                .font(theme.font(14, .bold))
                .foregroundStyle(theme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

/// Meilleure série, meilleure séance, meilleure semaine. Battus cette semaine : en orange.
private struct RecordsPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        HistoryPanel(title: "Records") {
            HStack(alignment: .top, spacing: 8) {
                tile("Série", stats.bestSet, week: false)
                tile("Séance", stats.bestSession, week: false)
                tile("Semaine", stats.bestWeek, week: true)
            }
        }
    }

    private func tile(_ name: String, _ record: HistoryStats.Record?, week: Bool) -> some View {
        let fresh = record.map { stats.weekStart($0.date) == stats.thisWeek } ?? false
        return VStack(alignment: .leading, spacing: 6) {
            MonitorLabel(name)
            HStack(spacing: 4) {
                Text(record.map { "\($0.value)" } ?? "—")
                    .font(theme.font(24, .bold))
                    .foregroundStyle(fresh ? theme.warn : theme.text)
                    .monospacedDigit()
                if fresh {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(theme.warn)
                }
            }
            Text(record.map { week ? (fresh ? "cette semaine" : "sem. du \(Format.shortDate($0.date))") : Format.shortDate($0.date) } ?? " ")
                .font(theme.font(10))
                .foregroundStyle(theme.dim)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fresh ? theme.warn.opacity(0.06) : .clear,
                    in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
            .stroke(fresh ? theme.warn.opacity(0.6) : theme.line, lineWidth: 1))
    }
}

/// Répétitions par semaine sur 12 semaines, la semaine en cours en dégradé, la moyenne en pointillés.
private struct VolumePanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    private let chartHeight: CGFloat = 78

    var body: some View {
        let weeks = stats.lastWeeks(12)
        let volumes = weeks.map { stats.volume(inWeek: $0) }
        let most = max(volumes.max() ?? 1, 1)
        let mean = Double(volumes.reduce(0, +)) / Double(volumes.count)
        HistoryPanel(title: "Volume · 12 semaines", accessory: { MonitorLabel("reps / semaine") }) {
            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(volumes.enumerated()), id: \.offset) { index, volume in
                        let current = index == volumes.count - 1
                        VStack(spacing: 5) {
                            if current {
                                Text("\(volume)")
                                    .font(theme.font(10, .bold))
                                    .foregroundStyle(theme.text)
                                    .fixedSize()
                            }
                            UnevenBar(radius: 2)
                                .fill(current
                                      ? AnyShapeStyle(LinearGradient(colors: [theme.primary, theme.secondary], startPoint: .top, endPoint: .bottom))
                                      : AnyShapeStyle(theme.primary.opacity(volume > 0 ? 0.35 : 0.15)))
                                .frame(maxWidth: 18)
                                .frame(height: max(2, chartHeight * CGFloat(volume) / CGFloat(most)))
                            Text(index % 3 == 2 ? "S\(stats.calendar.component(.weekOfYear, from: weeks[index]))" : " ")
                                .font(theme.font(9))
                                .foregroundStyle(theme.dim)
                                .fixedSize()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                // Moyenne des 12 semaines
                let y = 19 + chartHeight * CGFloat(mean) / CGFloat(most)
                HorizontalLine()
                    .stroke(theme.dim.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(height: 1)
                    .offset(y: -y)
                Text("moy. \(Int(mean.rounded()))")
                    .font(theme.font(9))
                    .foregroundStyle(theme.dim)
                    .padding(.trailing, 4)
                    .background(theme.panel)
                    .offset(y: -y - 4)
            }
            .frame(height: chartHeight + 34, alignment: .bottom)
        }
    }
}

private struct HorizontalLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
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

    private func row(_ session: SessionRecord, isRecord: Bool) -> some View {
        HStack(spacing: 12) {
            ExerciseIcon(exercise: session.exercise, size: 22)
                .foregroundStyle(theme.primary)
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.time(session.start))
                    .font(theme.font(15, .bold))
                    .foregroundStyle(theme.text)
                    .monospacedDigit()
                Text("\(session.orderedSets.count) série\(session.orderedSets.count > 1 ? "s" : "")")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
            Spacer(minLength: 6)
            if isRecord {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(theme.warn)
            }
            if let previous = stats.previous(of: session) {
                let delta = session.totalReps - previous.totalReps
                Text(Format.signed(delta))
                    .font(theme.font(11, .bold))
                    .foregroundStyle(delta > 0 ? theme.ok : theme.dim)
            }
            Text("\(session.totalReps)")
                .font(theme.font(22, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .frame(minWidth: 36, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.dim)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
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
                    HistoryPanel(title: "Séries") { setsTable(sets) }
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
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var overview: some View {
        HStack(spacing: 18) {
            Dial(face: DialFace(lit: DialFace.tickCount, palette: .gradient)) { side in
                VStack(spacing: 2) {
                    Text("\(session.totalReps)")
                        .font(theme.font(side * 0.3, .bold))
                        .foregroundStyle(theme.text)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    MonitorLabel("reps")
                }
                .padding(side * 0.18)
            }
            .frame(width: 130, height: 130)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    ExerciseIcon(exercise: session.exercise, size: 20)
                        .foregroundStyle(theme.primary)
                    Text(session.exercise.shortTitle.uppercased())
                        .font(theme.font(14, .bold))
                        .tracking(1.5)
                        .foregroundStyle(theme.text)
                }
                if let previous = stats.previous(of: session) {
                    let delta = session.totalReps - previous.totalReps
                    Text("\(delta >= 0 ? "▲" : "▼") \(Format.signed(delta)) vs \(Format.dayName(previous.start))")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(delta >= 0 ? theme.ok : theme.dim)
                }
                if stats.recordSessions.contains(session.persistentModelID) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill").font(.system(size: 10, weight: .bold))
                        Text("Record")
                    }
                    .font(theme.font(12, .bold))
                    .foregroundStyle(theme.warn)
                }
                if let index = session.performanceIndex {
                    Text("Score d'endurance \(Int(index.rounded()))" + (session.loadDescription.map { " · \($0)" } ?? ""))
                        .font(theme.font(12, .bold))
                        .foregroundStyle(theme.text)
                }
                if let form = stats.form(of: session) {
                    Text("Forme \(Int(form.percent.rounded())) % · \(form.zone.title.lowercased())")
                        .font(theme.font(12, .bold))
                        .foregroundStyle(formColor(form.zone, theme: theme))
                }
                Text("\(Format.clock(session.duration)) · \(session.orderedSets.count) série\(session.orderedSets.count > 1 ? "s" : "")")
                    .font(theme.font(12))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private func setsTable(_ sets: [SetRecord]) -> some View {
        let best = sets.map(\.reps).max() ?? 0
        return VStack(spacing: 0) {
            HStack {
                ForEach(Array(["Série", "Reps", "Durée", "Cadence", "Récup."].enumerated()), id: \.offset) { index, title in
                    MonitorLabel(title)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
                }
            }
            .padding(.bottom, 6)
            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                if index > 0 { Rectangle().fill(theme.line).frame(height: 1) }
                HStack {
                    Text(String(format: "S%02d", index + 1))
                        .foregroundStyle(theme.dim)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(set.reps)")
                        .foregroundStyle(set.reps == best && sets.count > 1 ? theme.warn : theme.text)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(Format.clock(set.duration))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(set.pace.map { "\(Format.decimal($0)) s" } ?? "—")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(session.rest(before: index).map(Format.clock) ?? "—")
                        .foregroundStyle(theme.dim)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(theme.font(14, .semibold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, 8)
            }
        }
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
