import SwiftData
import SwiftUI

/// Historique : un exercice (ou tous, Σ), et de haut en bas la semaine en cours, les records,
/// le volume et la progression sur 12 semaines, la régularité sur 16, puis la liste des séances.
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

                ScrollView {
                    VStack(spacing: 14) {
                        ExerciseFilter(selection: $exercise)
                        if let exercise, !stats.isEmpty {
                            if let advice = Advice.make(stats: stats) { AdviceCard(advice: advice) }
                            if exercise != .auto { FormPanel(stats: stats) }
                        }
                        if stats.isEmpty {
                            emptyState
                        } else {
                            if let exercise { EndurancePanel(stats: stats, exercise: exercise) }
                            WeekPanel(stats: stats)
                            if exercise != nil { RecordsPanel(stats: stats) }
                            VolumePanel(stats: stats)
                            if exercise != nil { ProgressionPanel(stats: stats) }
                            RegularityPanel(stats: stats)
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
        }
        .tint(theme.primary)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Dial(face: DialFace(lit: 0, palette: .pale)) { _ in
                MonitorLabel("Aucune séance")
            }
            .frame(width: 180, height: 180)
            Text("Tes séances terminées s'enregistrent ici, avec leurs séries et leurs records.")
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

/// Σ et les six exercices, sur une ligne.
private struct ExerciseFilter: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Exercise?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                item(nil) {
                    Text("Σ").font(.system(size: 18, weight: .bold))
                }
                ForEach(Exercise.allCases) { exercise in
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

/// Cette semaine : un cadran (rempli selon la meilleure semaine) et les chiffres clés.
private struct WeekPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let volume = stats.weekVolume, previous = stats.previousWeekVolume
        let best = max(stats.bestWeek?.value ?? volume, 1)
        let week = stats.thisWeek
        let end = stats.calendar.date(byAdding: .day, value: 6, to: week) ?? week
        HistoryPanel(title: "Cette semaine", accessory: {
            MonitorLabel("\(Format.shortDate(week)) – \(Format.shortDate(end))")
        }) {
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
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
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

/// Moyenne par série semaine après semaine (courbe), et trois tendances sur 12 semaines.
private struct ProgressionPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats

    var body: some View {
        let perSet = stats.weekly { $0.averagePerSet }
        let cadence = stats.weekly { $0.cadence }
        let fatigue = stats.weekly { $0.fatigue }
        HistoryPanel(title: "Progression · 12 semaines") {
            if perSet.count >= 2 {
                LineChart(points: perSet.map { (x: Double($0.week), value: $0.value) }, span: 11)
                    .frame(height: 72)
            } else {
                Text("La courbe apparaît après deux semaines d'entraînement.")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
            HStack(alignment: .top) {
                trend("Moy. / série", perSet, format: Format.decimal, higherIsBetter: true)
                Spacer()
                trend("Cadence", cadence, format: { "\(Format.decimal($0)) s" }, higherIsBetter: nil)
                Spacer()
                trend("Fatigue", fatigue, format: { "\(Format.percent($0)) %" }, higherIsBetter: true)
            }
        }
    }

    /// Dernière valeur et écart avec la première de la période.
    private func trend(_ name: String, _ points: [(week: Int, value: Double)], format: (Double) -> String,
                       higherIsBetter: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            MonitorLabel(name)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(points.last.map { format($0.value) } ?? "—")
                    .font(theme.font(15, .bold))
                    .foregroundStyle(theme.text)
                if let first = points.first, let last = points.last, points.count >= 2 {
                    let change = last.value - first.value
                    let good = higherIsBetter.map { $0 == (change >= 0) }
                    Text((change >= 0 ? "+" : "−") + Format.decimal(abs(change)))
                        .font(theme.font(10, .semibold))
                        .foregroundStyle(good == true ? theme.ok : theme.dim)
                }
            }
        }
    }
}

/// Courbe d'une valeur par semaine (points aux semaines qui en ont).
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
private struct RegularityPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    private static let weeks = 16

    var body: some View {
        let daily = stats.dailyVolume()
        let firstWeek = stats.lastWeeks(Self.weeks).first ?? stats.thisWeek
        let today = stats.calendar.startOfDay(for: stats.now)
        let most = max(daily.values.max() ?? 1, 1)
        let activeDays = daily.keys.filter { $0 >= firstWeek }.count
        HistoryPanel(title: "Régularité", accessory: { MonitorLabel("\(Self.weeks) semaines") }) {
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
                Text("\(activeDays) jour\(activeDays > 1 ? "s" : "") actif\(activeDays > 1 ? "s" : "")")
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

/// Liste des séances, la plus récente d'abord ; une touche ouvre le détail, un appui long propose
/// de supprimer.
private struct SessionsPanel: View {
    @Environment(\.theme) private var theme
    let stats: HistoryStats
    let showsExercise: Bool
    let onDelete: (SessionRecord) -> Void

    var body: some View {
        let records = stats.recordSessions
        HistoryPanel(title: "Séances", accessory: { MonitorLabel("\(stats.sessions.count) au total") }) {
            VStack(spacing: 0) {
                ForEach(Array(stats.sessions.enumerated()), id: \.element.persistentModelID) { index, session in
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
        }
    }

    private func row(_ session: SessionRecord, isRecord: Bool) -> some View {
        HStack(spacing: 12) {
            if showsExercise {
                ExerciseIcon(exercise: session.exercise, size: 22)
                    .foregroundStyle(theme.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.shortDay(session.start))
                    .font(theme.font(14, .bold))
                    .foregroundStyle(theme.text)
                Text("\(Format.time(session.start)) · \(session.orderedSets.count) série\(session.orderedSets.count > 1 ? "s" : "")")
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

            ScrollView {
                VStack(spacing: 14) {
                    overview
                    HistoryPanel(title: "Séries") { setsTable(sets) }
                    if sets.contains(where: { $0.repDurations.count >= 2 }) {
                        HistoryPanel(title: "Rythme", accessory: { MonitorLabel("s / rep") }) {
                            RhythmChart(sets: sets)
                                .frame(height: 106)
                            Text("Durée de chaque répétition : elle s'allonge en fin de série quand la fatigue arrive.")
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
                Text([Format.clock(session.duration),
                      "\(session.orderedSets.count) série\(session.orderedSets.count > 1 ? "s" : "")",
                      session.fatigue.map { "fatigue \(Format.percent($0)) %" }]
                    .compactMap { $0 }.joined(separator: " · "))
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
