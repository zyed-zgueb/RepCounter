import Charts
import SwiftUI
import TipKit

// MARK: - Intensité et mots du plan

/// L'intensité (skill reps-ux, § 5) : calme (semaine allégée, séance légère) → soutenu
/// (progression) → maximal (jour de test).
enum Intensity {
    static let calm = 0.0
    static let work = AppTheme.workLevel
    static let max = 1.0

    static func word(_ level: Double) -> String {
        level < 0.3 ? "calme" : (level < 0.85 ? "soutenue" : "maximale")
    }

    /// L'effort demandé, en mot de tous les jours : facile, normal, maximal.
    static func effort(_ level: Double) -> String {
        level < 0.3 ? "facile" : (level < 0.85 ? "normal" : "maximal")
    }

    /// Crans de la jauge d'effort (1 à 3).
    static func notches(_ level: Double) -> Int {
        level < 0.3 ? 1 : (level < 0.85 ? 2 : 3)
    }
}

/// La jauge d'effort du jour : 3 crans (facile, normal, maximal) et le mot, « effort normal ».
/// Une jauge seule ne dirait pas à quoi elle se rapporte : le mot est toujours là.
struct EffortGauge: View {
    @Environment(\.theme) private var theme
    let level: Double
    let color: Color

    var body: some View {
        let on = Intensity.notches(level)
        HStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(index < on ? color : theme.line)
                        .frame(width: 5, height: CGFloat(7 + index * 4))
                }
            }
            Text("effort \(Intensity.effort(level))")
                .font(theme.font(15, .medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Effort \(Intensity.effort(level)), \(on) sur 3")
    }
}

extension TrainingPlan.Today {
    /// Le niveau d'intensité du jour.
    var intensity: Double {
        switch self {
        case .session: return Intensity.work
        case .light, .deload, .reprise, .comeback: return Intensity.calm
        case .test: return Intensity.max
        }
    }

    /// La couleur du jour, sur l'échelle d'intensité.
    func color(_ theme: AppTheme) -> Color { theme.intensity(intensity) }

    /// « 29 · 25 · 22 · repos 1:30 », « ! léger · 29 · 25 · repos 1:30 », « allégée · … »,
    /// « test · série max ». La séance légère est une alerte : « ! ».
    var label: String {
        switch self {
        case .session(let s): return "\(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .light(let s): return "! léger · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .deload(let s): return "allégée · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .reprise(let s): return "! reprise · \(s.label) · ◷ \(Format.clock(Double(s.rest)))"
        case .comeback: return "! reprise · une séance"
        case .test: return "◆ test · série max"
        }
    }

    /// Sans le repos : « 29 · 25 · 22 », « ◆ test · série max ».
    var short: String {
        switch self {
        case .session(let s): return s.label
        case .light(let s): return "! léger · \(s.label)"
        case .deload(let s): return "allégée · \(s.label)"
        case .reprise(let s): return "! reprise · \(s.label)"
        case .comeback: return "! reprise"
        case .test: return "◆ test · série max"
        }
    }
}

extension TrainingPlan.Week {
    /// « P1 », « P2 bis », « A ».
    var short: String {
        switch kind {
        case .progression(let index, let redo): return "P\(index + 1)\(redo ? " bis" : "")"
        case .deload: return "A"
        case .reprise: return "R"
        }
    }

    var name: String {
        switch kind {
        case .progression(let index, let redo): return "Progr. \(index + 1)\(redo ? " bis" : "")"
        case .deload: return "Allégée"
        case .reprise: return "Reprise"
        }
    }

    var intensity: Double { kind == .deload || kind == .reprise ? Intensity.calm : Intensity.work }

    /// Semaine refaite après un décrochage (alerte : « ! »).
    var isRedo: Bool {
        if case .progression(_, let redo) = kind { return redo }
        return false
    }
}

extension TrainingPlan {
    /// La suite, en une ligne : « test demain · prochaine lun. » un jour de repos (la raison du
    /// repos d'abord), « prochaine demain » une fois la séance faite.
    var weekLine: String? {
        if restReason == .beforeTest { return restReason?.short }
        let nextText = next.map { "prochaine séance \(Format.dayDate($0))" }
        return [restReason?.short, nextText].compactMap { $0 }.joined(separator: " · ")
    }

    /// L'intensité de la semaine en cours (jour de test : maximale).
    var weekIntensity: Double {
        if today == .test { return Intensity.max }
        return currentWeek?.intensity ?? Intensity.work
    }
}

/// La ligne du jour sous le cadran, en veille : « aujourd'hui · 29 · 25 · 22 · repos 1:30 »,
/// « fait ✓ · prochaine demain » (« fait · cible non atteinte » sous le total prévu), ou
/// « repos conseillé · test demain · prochaine lundi ».
/// Démarrer reste possible.
struct TodayLine: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        // En grandes tailles de texte : la version courte (sans le repos), puis sur deux lignes,
        // plutôt qu'un texte tronqué ou rétréci
        Group {
            if plan.status == .due {
                // Une ligne si elle tient ; sinon « aujourd'hui » au-dessus des cibles, jamais un
                // mot coupé
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 4) { dueLead; dueLabel(plan.today.label) }
                    HStack(spacing: 4) { dueLead; dueLabel(plan.today.short) }
                    VStack(spacing: 2) {
                        Text("aujourd'hui").foregroundStyle(theme.dim)
                        dueLabel(plan.today.short)
                    }
                }
            } else {
                // Fait ou repos : le statut, puis la suite sur sa propre ligne
                VStack(spacing: 4) {
                    lead(plan.today.label)
                    if let line = plan.weekLine { Text(symbols: line).foregroundStyle(theme.text) }
                }
            }
        }
        .font(theme.font(13))
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private var dueLead: some View { Text("aujourd'hui ·").foregroundStyle(theme.dim) }

    private func dueLabel(_ label: String) -> some View {
        Text(symbols: label).fontWeight(.bold).foregroundStyle(plan.today.color(theme))
    }

    /// « aujourd'hui · 29 · 25 · 22 », « fait ✓ », « fait · cible non atteinte » ou « repos conseillé ».
    @ViewBuilder
    private func lead(_ label: String) -> some View {
        switch plan.status {
        case .due:
            HStack(spacing: 4) {
                Text("aujourd'hui ·").foregroundStyle(theme.dim)
                Text(symbols: label).fontWeight(.bold).foregroundStyle(plan.today.color(theme))
            }
        case .done:
            if plan.targetMissed {
                // Pas de vert ni de ✓ : la cible n'est pas atteinte (skill reps-ux § 5)
                Text("fait · cible non atteinte").fontWeight(.bold).foregroundStyle(theme.text)
            } else {
                Text(symbols: "fait ✓").fontWeight(.bold).foregroundStyle(theme.ok)
            }
        case .rest:
            Text("repos conseillé").fontWeight(.bold).foregroundStyle(theme.dim)
        }
    }

}

/// La ligne sous le cadran un jour de test (le cadran reste neutre) : « ◆ jour de test · série max ·
/// dernier test 33 », « ◆ test 1 / 2 »
/// au bloc 1, « ! ◆ test à faire » en retard (skill reps-ux § 5 : l'alerte porte « ! »).
struct TestDayLine: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        Text(symbols: text)
            .font(theme.font(13, .bold))
            .foregroundStyle(plan.testOverdue ? theme.text : theme.max)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var text: String {
        if let step = plan.testStep { return "Test \(step.number) sur \(step.of) : ton niveau de départ" }
        let last = plan.tests.last.map { " · à battre : \($0.value)" } ?? ""
        return (plan.testOverdue ? "Test à faire" : "Jour de test") + last
    }
}

/// La séance en cours, sous le cadran : une case par série prévue (« 29 ✓ · 25 ← · 22 »).
/// Faites : le nombre réel, en vert si la cible est atteinte ; en cours : marquée ; à venir : la cible.
struct SetRow: View {
    @Environment(\.theme) private var theme
    let planDay: WorkoutModel.PlanDay
    /// Séries faites dans cette séance.
    let done: [Int]
    /// La cible affichée pour chaque série faite dans cette séance (réajustée).
    var doneTargets: [Int?] = []
    /// Répétitions de la série en cours (nil pendant la récupération).
    let current: Int?

    var body: some View {
        let all = planDay.earlierToday + done
        let next = Prescription.nextTarget(planDay.session, ratios: planDay.ratios, dayDone: all, sessionDone: done)
        HStack(spacing: 6) {
            ForEach(0..<max(planDay.session.sets, all.count), id: \.self) { index in
                if index > 0 { Text("·").foregroundStyle(theme.dim) }
                cell(index, all: all, next: next)
            }
        }
        .font(theme.font(15, .bold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func cell(_ index: Int, all: [Int], next: Int?) -> some View {
        let planned = index < planDay.session.sets ? planDay.session.targets[index] : nil
        if index < all.count {
            // Jugée sur la cible que le compteur affichait (réajustée) ; sans cible (série au-delà
            // du prévu) : ni ✓ ni vert
            let targets = planDay.earlierTargets + doneTargets
            let shownTarget = (index < targets.count ? targets[index] : nil) ?? planned
            let reached = shownTarget.map { all[index] >= $0 } ?? false
            Text(symbols: "\(all[index])\(reached ? " ✓" : "")").foregroundStyle(reached ? theme.ok : theme.text)
        } else if index == all.count {
            // La série en cours (ou la prochaine) : sa cible, réajustée
            Text(symbols: "\(current.map { "\($0)/" } ?? "")\(next ?? planned ?? 0) ←").foregroundStyle(theme.primary)
        } else {
            Text("\(planned ?? 0)").foregroundStyle(theme.dim)
        }
    }
}

// MARK: - Le plan, en mots

extension TrainingPlan.RestReason {
    /// La raison du repos conseillé, en une phrase (carte Aujourd'hui).
    var explanation: String {
        switch self {
        case .beforeTest: return "Test demain : arrive frais."
        case .persistentFatigue: return "Ta fatigue dure : récupère."
        case .hardYesterday: return "Séance d'hier très difficile : récupère."
        case .weeklyVolume: return "\(TrainingPlan.weeklySetCap) séries en 7 jours : récupère."
        }
    }

    /// La même raison, vue d'aujourd'hui pour demain (« Demain, repos conseillé : … »).
    var tomorrowExplanation: String {
        switch self {
        case .beforeTest: return "après-demain, c'est le test"
        case .persistentFatigue: return "ta fatigue dure"
        case .hardYesterday: return "ta séance d'aujourd'hui était très difficile"
        case .weeklyVolume: return "tu auras fait \(TrainingPlan.weeklySetCap) séries en 7 jours"
        }
    }
}

extension TrainingPlan {
    /// Le test de fin de bloc fait (le bloc suivant n'a pas encore commencé) ; nil sinon.
    var blockTestDone: Test? {
        tests.last.flatMap { $0.block == block && $0.date >= testDate ? $0 : nil }
    }

    /// Le lundi où commence le bloc suivant, une fois le test fait ; nil sinon.
    var nextBlockStart: Date? {
        guard let done = blockTestDone else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 7, to: Schedule.weekStart(done.date, calendar: calendar))
    }

    /// Bloc 1 : la première semaine sert à mesurer le niveau ; il reste 2 semaines de progression.
    var progressionWeeksShown: Int { block == 1 ? Prescription.progressionWeeks - 1 : Prescription.progressionWeeks }

    /// La semaine en cours est la première du bloc.
    private var firstWeekOfBlock: Bool { weeks.first?.isCurrent ?? false }

    /// La semaine refaite en cours : la raison, lue sur la semaine qu'elle refait.
    private var redoneBecause: String? {
        guard let current = currentWeek, current.isRedo,
              let index = weeks.firstIndex(where: { $0.isCurrent }), index > 0 else { return nil }
        return weeks[index - 1].redoReason
    }

    /// Les 2 tests de départ, en mots : « le 2e mercredi », « plus de place cette semaine ».
    private var startNext: String? { startTests?.next.map { Format.dayDate($0) } }

    /// Pourquoi l'app propose ce qu'elle propose aujourd'hui, et ce qui suit, en une ou deux
    /// phrases de tous les jours (CLAUDE.md, « L'expérience » : comprendre, sans surprise). Les
    /// changements du plan sont dits ici, le jour même.
    var todayReason: String? {
        if status == .rest, let restReason { return restReason.explanation }
        // Séance du jour faite : seulement ce qui change pour la suite
        if status == .done {
            if let step = testStep {
                if step.number == 1 {
                    return startNext.map { "Test 1 fait. Le 2e : \($0)." } ?? "Test 1 fait : il fixe tes cibles."
                }
                return "Tests faits : tes cibles en partent."
            }
            if let done = blockTestDone, let start = nextBlockStart {
                return "Test : \(done.value) d'affilée. Bloc \(block + 1) dès \(Format.dayDate(start))."
            }
            return nil
        }
        switch today {
        case .comeback:
            return nil
        case .test:
            if let step = testStep {
                if step.number == 1 {
                    let lastDay = startTests?.next.map { Schedule.isoWeekday($0, calendar: .current) == 5 } ?? false
                    return lastDay ? "Test 1 sur 2 : ton niveau de départ. Dernier jour cette semaine."
                        : "Test 1 sur 2 : ton niveau de départ."
                }
                return "Test 2 sur 2 : le meilleur compte."
            }
            if testOverdue {
                let limit = Calendar.current.date(byAdding: .day, value: Int(Self.repriseDays), to: testDate) ?? testDate
                return "Test à faire avant \(Format.dayDate(limit)) : le bloc suivant l'attend."
            }
            return "Fin du bloc : mesure ton progrès."
        case .light:
            return lightBecause ?? "Forme en baisse : séance légère."
        case .deload:
            return "Récupération : la moitié des séries avant le test."
        case .reprise:
            return "Reprise après une pause : séance allégée."
        case .session:
            if let done = blockTestDone, let start = nextBlockStart {
                return "Test : \(done.value) d'affilée. Bloc \(block + 1) dès \(Format.dayDate(start))."
            }
            if let because = redoneBecause {
                return "Semaine refaite : test décalé au \(Format.dayDate(testDate))."
            }
            guard case .progression(let index, _) = currentWeek?.kind else { return nil }
            if block == 1, index == 0 {
                if let start = startTests, start.done < 2 {
                    return start.done == 0 ? "Pas de test cette semaine : tes séances calent tes cibles."
                        : "1 test fait : tes cibles en partent."
                }
                return "Tes cibles partent de tes tests."
            }
            if block > 1, firstWeekOfBlock {
                if let previous = tests.last, previous.block == block - 1 {
                    return "Nouveau bloc : cibles depuis ton test (\(previous.value))."
                }
                if !missedTests.isEmpty, let level = currentMax {
                    return "Nouveau bloc sans test : cibles depuis ton niveau (\(level))."
                }
            }
            if let raise = maxRaise { return "Cibles relevées : tu as fait \(raise)." }
            return nil
        }
    }
}

extension TrainingPlan {
    /// En gros : « Semaine 2 sur 4 », « Test aujourd'hui », « Bloc 2 terminé ».
    var whereAmITitle: String {
        if nextBlockStart != nil { return "Bloc \(block) terminé" }
        if testOverdue { return "Test à faire" }
        if today == .test, testStep == nil { return "Test aujourd'hui" }
        if let index = weeks.firstIndex(where: { $0.isCurrent }) { return "Semaine \(index + 1) sur \(weeks.count)" }
        return "Bloc \(block)"
    }

    /// Dessous : « Bloc 2 · test de fin de bloc dans 16 jours », « Bloc 3 lundi 9 nov. ».
    var whereAmISubtitle: String {
        let calendar = Calendar.current
        if let start = nextBlockStart { return "Bloc \(block + 1) dès \(Format.dayDate(start))" }
        if testOverdue || (today == .test && testStep == nil) { return "Bloc \(block) · test de fin de bloc" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: testDate)).day ?? 0
        let when = days <= 1 ? Format.dayDate(testDate) : "dans \(days) jours"
        return "Bloc \(block) · test de fin de bloc \(when)"
    }

    /// « Bloc 2 · semaine 2 sur 4 · test dans 16 jours », « Bloc 2 · test aujourd'hui »,
    /// « Bloc 2 terminé · le bloc 3 commence lundi 9 nov. ».
    var whereAmI: String {
        let calendar = Calendar.current
        if let start = nextBlockStart {
            return "Bloc \(block) terminé · le bloc \(block + 1) commence \(Format.dayDate(start))"
        }
        if testOverdue { return "Bloc \(block) · test de fin de bloc à faire" }
        if today == .test, testStep == nil { return "Bloc \(block) · test de fin de bloc aujourd'hui" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: testDate)).day ?? 0
        let testText = days <= 0 ? "test de fin de bloc aujourd'hui"
            : (days == 1 ? "test de fin de bloc demain" : "test de fin de bloc dans \(days) jours")
        if let index = weeks.firstIndex(where: { $0.isCurrent }) {
            return "Bloc \(block) · semaine \(index + 1) sur \(weeks.count) · \(testText)"
        }
        return "Bloc \(block) · \(testText)"
    }
}

/// La frise du bloc : une case par semaine (sa couleur d'intensité, remplie jusqu'à aujourd'hui),
/// le test au bout, et sous chaque case son but en un mot ; la semaine en cours est marquée
/// « ▲ ». Se lit d'un coup d'œil : début ou fin de bloc, sans lire de date.
struct PlanTimeline: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            bars
            // En tailles d'accessibilité, les colonnes sont trop étroites pour un mot : seul le
            // but de la semaine en cours est écrit, sur toute la largeur
            if typeSize.isAccessibilitySize, let current = currentWord {
                Text("Cette semaine : \(current.lowercased())")
                    .font(theme.font(15, .semibold))
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(plan.whereAmI)
    }

    private var currentWord: String? {
        if plan.today == .test && plan.testStep == nil { return "Test" }
        guard let index = plan.weeks.firstIndex(where: \.isCurrent) else { return nil }
        return word(plan.weeks[index], index: index)
    }

    private var bars: some View {
        HStack(alignment: .top, spacing: 4) {
            ForEach(Array(plan.weeks.enumerated()), id: \.offset) { index, week in
                column(word(week, index: index), fill: fill(week), color: theme.intensity(week.intensity),
                       current: week.isCurrent)
            }
            // Le test, au bout
            VStack(spacing: 4) {
                Rectangle()
                    .fill(plan.blockTestDone != nil ? theme.max : .clear)
                    .overlay(Rectangle().stroke(theme.max, lineWidth: 1.5))
                    .frame(width: 10, height: 10)
                    .rotationEffect(.degrees(45))
                    .frame(height: 12)
                if !typeSize.isAccessibilitySize {
                    label("Test", current: plan.today == .test && plan.testStep == nil)
                }
            }
            .frame(width: 32)
        }
    }

    private func column(_ word: String, fill: Double, color: Color, current: Bool) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.22))
                    RoundedRectangle(cornerRadius: 3).fill(color).frame(width: geometry.size.width * fill)
                    if current {
                        RoundedRectangle(cornerRadius: 3).stroke(theme.text, lineWidth: 1.5)
                    }
                }
            }
            .frame(height: 14)
            if !typeSize.isAccessibilitySize { label(word, current: current) }
        }
        .frame(maxWidth: .infinity)
    }

    private func label(_ text: String, current: Bool) -> some View {
        Text(symbols: text)
            .font(theme.font(13, current ? .bold : .regular))
            .foregroundStyle(current ? theme.text : theme.dim)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    /// Le but de la semaine en un mot.
    private func word(_ week: TrainingPlan.Week, index: Int) -> String {
        switch week.kind {
        case .progression(let step, let redo):
            if plan.block == 1, step == 0, !redo { return "Mesure" }
            return redo ? "Refaite" : "Progrès"
        case .deload: return "Repos"
        case .reprise: return "Reprise"
        }
    }

    /// Passée : pleine ; en cours : jusqu'à aujourd'hui ; à venir : vide.
    private func fill(_ week: TrainingPlan.Week) -> Double {
        if week.isPast { return 1 }
        guard week.isCurrent else { return 0 }
        return min(max(Date().timeIntervalSince(week.start) / (7 * 86_400), 0.08), 1)
    }
}

/// « Ton plan », en tête du Coaching : où j'en suis en gros (« Semaine 2 sur 4 »), le test qui
/// vient, la frise, et le détail des semaines sur demande. Une idée, peu de texte (skill reps-ux,
/// « Typographie et espace »).
struct PlanCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(symbol: "calendar", title: "Ton plan", opens: true)
            VStack(alignment: .leading, spacing: 4) {
                Text(plan.whereAmITitle)
                    .font(theme.font(22, .bold))
                    .foregroundStyle(theme.text)
                Text(plan.whereAmISubtitle)
                    .font(theme.font(15))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            PlanTimeline(plan: plan)
        }
        .coachingCard(theme)
        .contentShape(Rectangle())
        .accessibilityHint("Ouvre les semaines du bloc")
    }
}

/// Le détail du plan (page poussée depuis « Ton plan ») : le but du bloc, chaque semaine avec son
/// but et ses dates, « tu es ici », le test et sa raison.
struct PlanWeeksList: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    let plan: TrainingPlan

    private enum Moment { case past, current, future }

    private struct Row: Identifiable {
        let id: Int
        let title: String
        let detail: String
        let when: String
        let moment: Moment
        let isTest: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(theme.font(17))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                ForEach(rows) { row in
                    rowView(row)
                }
            }
            if plan.nextBlockStart == nil {
                Text("Après le test, un nouveau bloc repart de ton nouveau niveau.")
                    .font(theme.font(15))
                    .foregroundStyle(theme.dim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .coachingCard(theme)
    }

    /// « Bloc 2 : 3 semaines pour progresser, 1 pour récupérer, puis un test… »
    private var headline: String {
        plan.block == 1
            ? "Bloc 1 : 1 semaine pour mesurer ton niveau, \(plan.progressionWeeksShown) pour progresser, 1 pour récupérer, puis un test qui mesure ton progrès."
            : "Bloc \(plan.block) : \(plan.progressionWeeksShown) semaines pour progresser, 1 pour récupérer, puis un test qui mesure ton progrès."
    }

    private var rows: [Row] {
        var list: [Row] = []
        for (index, week) in plan.weeks.enumerated() {
            let moment: Moment = week.isCurrent ? .current : (week.isPast ? .past : .future)
            let when = "sem. du \(week.start.formatted(.dateTime.day().month(.abbreviated)))"
            let doneText = week.done == 0 ? "aucune séance" : (week.done == 1 ? "1 séance" : "\(week.done) séances")
            let title: String
            var detail: String
            switch week.kind {
            case .progression(let step, let redo):
                if plan.block == 1, step == 0, !redo {
                    title = "Mesurer ton niveau"
                    detail = startDetail(week)
                } else {
                    title = redo ? "Progresser (semaine refaite)" : "Progresser"
                    detail = "cibles \(week.planned.label)"
                }
            case .deload:
                title = "Récupérer"
                detail = "la moitié des séries, pour arriver frais au test"
            case .reprise:
                title = "Reprendre après une pause"
                detail = "séances allégées avant le test"
            }
            if moment == .past {
                detail = week.redoReason.map { "refaite : \($0)" } ?? doneText
            }
            list.append(Row(id: index, title: title, detail: detail, when: when, moment: moment, isTest: false))
        }
        // Le test qui clôt le bloc
        let tested = plan.blockTestDone
        let testMoment: Moment = tested != nil ? .past : (plan.today == .test && plan.testStep == nil ? .current : .future)
        let testDetail: String
        if let tested {
            testDetail = "fait : \(tested.value) d'affilée"
        } else if plan.testOverdue {
            testDetail = "à faire : le bloc suivant l'attend"
        } else {
            testDetail = "une série max : elle mesure ton progrès, et les cibles du bloc suivant en partent"
        }
        list.append(Row(id: plan.weeks.count, title: "Test", detail: testDetail,
                        when: Format.dayDate(plan.testDate), moment: testMoment, isTest: true))
        // Test fait : le bloc suivant, daté
        if let start = plan.nextBlockStart {
            list.append(Row(id: plan.weeks.count + 1, title: "Bloc \(plan.block + 1)",
                            detail: "il part de ton test ; d'ici là, séances à tes nouvelles cibles",
                            when: Format.dayDate(start), moment: .current, isTest: false))
        }
        return list
    }

    /// La première semaine du bloc 1 : les 2 tests de départ, annoncés avec leur jour.
    private func startDetail(_ week: TrainingPlan.Week) -> String {
        guard let start = plan.startTests else { return "tes cibles partent de tes tests de départ" }
        switch (start.done, start.next) {
        case (0, let next?): return "2 tests max à 2 jours d'écart ; le 1er \(Format.dayDate(next))"
        case (0, nil): return "pas de test de départ (plus le temps cette semaine) : tes séances calent tes cibles"
        case (1, let next?): return "test 1 fait ; le 2e \(Format.dayDate(next))"
        case (1, nil): return "1 test fait ; plus de place pour le 2e : tes cibles partent de lui"
        default: return "2 tests faits : tes cibles partent du meilleur"
        }
    }

    private func rowView(_ row: Row) -> some View {
        let current = row.moment == .current
        // La semaine en cours se voit au fond teinté et à l'anneau ; la date sous le titre
        let titleView = Text(row.title)
            .font(theme.font(17, current ? .bold : .semibold))
            .foregroundStyle(row.moment == .past ? theme.dim : theme.text)
        let whenView = Text(row.when)
            .font(theme.font(15))
            .foregroundStyle(theme.dim)
        return HStack(alignment: .top, spacing: 10) {
            marker(row)
                .frame(width: 14, height: 14)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 2) {
                titleView
                whenView
                if !row.detail.isEmpty {
                    Text(row.detail)
                        .font(theme.font(15))
                        .foregroundStyle(row.moment == .past ? theme.dim : theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(current ? theme.primary.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityValue(current ? "en cours" : "")
    }

    /// Fait : disque plein ; en cours : anneau épais ; à venir : anneau fin ; test : losange.
    @ViewBuilder
    private func marker(_ row: Row) -> some View {
        if row.isTest {
            Rectangle()
                .fill(row.moment == .past ? theme.max : .clear)
                .overlay(Rectangle().stroke(theme.max, lineWidth: 1.5))
                .frame(width: 9, height: 9)
                .rotationEffect(.degrees(45))
        } else {
            switch row.moment {
            case .past: Circle().fill(theme.dim).frame(width: 10, height: 10)
            case .current: Circle().stroke(theme.primary, lineWidth: 3).frame(width: 12, height: 12)
            case .future: Circle().stroke(theme.line, lineWidth: 1.5).frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - Le chemin vers l'objectif

/// Le chemin, du départ à la date de l'objectif, pour ce qui est mesuré (« pompes d'affilée ») :
/// le départ ●, la meilleure série de chaque séance •, les tests ◆ (pleins et chiffrés une fois
/// faits, creux à venir), la ligne attendue en pointillés, l'objectif ⚑, aujourd'hui ▼. Les blocs
/// sont de simples repères (un filet à chaque début, B1…Bn sous l'axe) : l'intensité est dans la
/// carte du bloc. Une légende d'une ligne.
struct PathCard: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan
    let exercise: Exercise
    /// Les séances de l'exercice (la meilleure série de chacune est un point).
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CardHeader(symbol: "chart.line.uptrend.xyaxis", title: "Chemin")
            PathChart(plan: plan, exercise: exercise, sessions: sessions)
            // Une légende ne montre que ce qui est dessiné (skill reps-ux, § 9)
            let legend = self.legend
            Text(symbols: legend.map(\.symbol).joined(separator: " · "))
                .font(theme.font(13))
                .foregroundStyle(theme.dim)
                .accessibilityLabel("Légende : " + legend.map(\.spoken).joined(separator: " ; "))
            // Le prochain test est dans « Ton plan » : une carte, une idée
            if let verdict = settledVerdict {
                VStack(alignment: .leading, spacing: 4) {
                    Text(symbols: verdictSymbol(verdict))
                        .font(theme.font(17, .bold))
                        .foregroundStyle(theme.text)
                    if let projection = plan.projection, let goal = plan.goal {
                        Text("À ce rythme, \(goal.target) vers le \(Format.shortDate(projection)).")
                            .font(theme.font(15))
                            .foregroundStyle(theme.dim)
                    }
                }
            }
        }
        .coachingCard(theme)
    }

    /// Les entrées de la légende, seulement pour ce que le chemin dessine.
    private var legend: [(symbol: String, spoken: String)] {
        var items: [(symbol: String, spoken: String)] = []
        if plan.goal != nil { items.append(("● départ", "rond plein : départ")) }
        // Les points dessinés : les séances depuis le début, hors séances de test
        let start = plan.goal?.created ?? plan.anchor
        let tests = Set(plan.tests.map(\.date))
        if sessions.contains(where: { $0.start >= start && !tests.contains($0.start) && !$0.isTest && $0.bestSet > 0 }) {
            items.append(("• séances", "petits points : séances"))
        }
        if plan.tests.contains(where: { $0.date >= start }) || plan.hasTest { items.append(("◆ test", "losange : test")) }
        if plan.shiftedGoalDate != nil { items.append(("┄ attendu", "pointillés : attendu")) }
        return items
    }

    /// Le verdict, seulement une fois établi (3 tests).
    private var settledVerdict: TrainingPlan.Verdict? {
        guard let verdict = plan.verdict else { return nil }
        if case .pending = verdict { return nil }
        return verdict
    }

    private func verdictSymbol(_ verdict: TrainingPlan.Verdict) -> String {
        switch verdict {
        case .ahead: return "▲ en avance"
        case .onTrack: return "= dans le rythme"
        case .behind: return "▼ en retard"
        case .pending: return ""
        }
    }
}

/// Le chemin (Swift Charts), sur un axe de dates : les blocs en repères (un filet, B1…Bn), la
/// ligne d'arrivée ⚑, l'attendu en pointillés, la projection, la meilleure série de chaque séance,
/// les tests (◆ pleins et chiffrés, creux à venir), le départ ● et aujourd'hui ▼. Un doigt posé
/// donne la séance la plus proche.
private struct PathChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 170
    let plan: TrainingPlan
    let exercise: Exercise
    let sessions: [SessionRecord]
    @State private var selected: Date?

    private struct Point: Identifiable {
        let id: Int
        let date: Date
        let value: Int
    }

    /// Un sommet d'une ligne (attendu, projection) : identifiant propre, même si deux dates
    /// coïncident.
    private struct LinePoint: Identifiable {
        let id: Int
        let date: Date
        let value: Int
    }

    /// La meilleure série de chaque séance depuis le début du plan, hors séances de test.
    private var points: [Point] {
        let start = plan.goal?.created ?? plan.anchor
        let tests = Set(plan.tests.map(\.date))
        return sessions
            .filter { $0.start >= start && !tests.contains($0.start) && !$0.isTest && $0.bestSet > 0 }
            .enumerated()
            .map { Point(id: $0.offset, date: $0.element.start, value: $0.element.bestSet) }
    }

    var body: some View {
        let points = self.points
        let start = plan.goal?.created ?? plan.anchor
        // L'axe englobe aujourd'hui, les séances, les tests et la date de l'objectif (même dépassée)
        let now = Date()
        let latest = ([now, plan.testDate] + points.map(\.date) + plan.tests.map(\.date) + [plan.shiftedGoalDate].compactMap { $0 }).max() ?? now
        let end = max(latest.addingTimeInterval(7 * 86_400), start.addingTimeInterval(16 * 7 * 86_400))
        // Les blocs : ceux faits ou en cours, puis ceux à venir jusqu'à la fin de l'axe
        var starts = plan.blocks.map(\.start)
        var next = (plan.blocks.last?.test ?? start).addingTimeInterval(7 * 86_400)
        // Reprise après une longue absence : pas de bloc ni de test à venir sur le chemin
        while plan.hasTest, next < end {
            starts.append(next)
            next = next.addingTimeInterval(5 * 7 * 86_400)
        }
        // Rien avant le début de l'axe (blocs ou tests antérieurs au départ)
        let blockStarts = starts.filter { $0 >= start && $0 < end }
        // Tests pas encore faits : celui du bloc en cours (s'il n'est pas fait), puis ceux des
        // blocs à venir ; les tests manqués restent à leur date, marqués « ! »
        let currentTestDone = plan.tests.contains { $0.block == plan.block }
        let currentTest = plan.hasTest && !currentTestDone ? [plan.testDate] : []
        let upcoming = (currentTest + starts.dropFirst(plan.blocks.count).map { $0.addingTimeInterval(4 * 7 * 86_400) })
            .filter { $0 >= start && $0 <= end }
        let alerts = Set(plan.missedTests + (plan.testOverdue ? [plan.testDate] : []))
        let missed = plan.missedTests.filter { $0 >= start && $0 <= end }
        let lastMax = plan.tests.last?.value ?? points.last?.value ?? plan.goal?.start
        let fallback = Double(lastMax ?? 0)
        let upcomingLevels = (upcoming + missed).map { plan.expected(at: $0) ?? fallback }
        // L'échelle englobe le départ, l'objectif, les tests (faits et à venir) et les séances
        var values = plan.tests.map { Double($0.value) } + points.map { Double($0.value) } + upcomingLevels
        if let goal = plan.goal { values += [Double(goal.start), Double(goal.target)] }
        let low = (values.min() ?? 0) - 2, high = (values.max() ?? 10) + 2
        let chosen = selected.flatMap { date in points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) } }

        // De l'espace sous le titre : le ▼ d'aujourd'hui se pose au-dessus du graphique
        return VStack(alignment: .leading, spacing: 16) {
            MonitorLabel("\(exercise.shortTitle.lowercased()) d'affilée")
            Chart {
                blockMarks(blockStarts)
                goalMarks(end: end)
                sessionMarks(points, upcoming: upcoming + missed, alerts: alerts, level: { plan.expected(at: $0) ?? fallback })
                testMarks(from: start)
                todayMarks(chosen)
            }
            .chartXScale(domain: start...end)
            .chartYScale(domain: low...high)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: ChartKit.ticks(typeSize, regular: 3)))
            }
            .chartXSelection(value: $selected)
            .frame(height: height)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibility(points))
        }
    }

    @ChartContentBuilder
    private func blockMarks(_ starts: [Date]) -> some ChartContent {
        ForEach(Array(starts.enumerated()), id: \.offset) { index, blockStart in
            RuleMark(x: .value("Date", blockStart))
                .foregroundStyle(theme.grid)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(position: .bottom, alignment: .leading) {
                    Text("bloc \(index + 1)")
                        .font(theme.font(13, index == plan.blocks.count - 1 ? .bold : .regular))
                        .foregroundStyle(index == plan.blocks.count - 1 ? theme.text : theme.dim)
                }
        }
    }

    /// La ligne d'arrivée ⚑, l'attendu (départ → objectif à la date choisie), la projection.
    @ChartContentBuilder
    private func goalMarks(end: Date) -> some ChartContent {
        if let goal = plan.goal {
            RuleMark(y: .value("Répétitions", Double(goal.target)))
                .foregroundStyle(theme.ok)
                .annotation(position: .top, alignment: .trailing) {
                    Text(symbols: "⚑ \(goal.target)")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(theme.ok)
                }
            if let goalDate = plan.shiftedGoalDate {
                ForEach([LinePoint(id: 0, date: goal.created, value: goal.start),
                         LinePoint(id: 1, date: goalDate, value: goal.target)]) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)), series: .value("Ligne", "attendu"))
                        .foregroundStyle(theme.dim)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            if let projection = plan.projection, let last = plan.tests.last {
                ForEach([LinePoint(id: 0, date: last.date, value: last.value),
                         LinePoint(id: 1, date: min(projection, end), value: goal.target)]) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)), series: .value("Ligne", "projection"))
                        .foregroundStyle(theme.primary)
                        .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [2, 3]))
                }
            }
        }
    }

    /// La meilleure série de chaque séance, et les tests à venir (◆ creux).
    @ChartContentBuilder
    private func sessionMarks(_ points: [Point], upcoming: [Date], alerts: Set<Date>,
                              level: @escaping (Date) -> Double) -> some ChartContent {
        ForEach(points) { point in
            PointMark(x: .value("Date", point.date), y: .value("Répétitions", Double(point.value)))
                .foregroundStyle(theme.primary.opacity(0.8))
                .symbolSize(14)
        }
        ForEach(upcoming, id: \.self) { test in
            PointMark(x: .value("Date", test), y: .value("Répétitions", level(test)))
                .symbol {
                    Image(systemName: "diamond")
                        .font(theme.font(13))
                        .foregroundStyle(theme.dim)
                }
                .annotation(position: .top, spacing: 0) {
                    // Test pas fait (manqué, ou en retard) : « ! »
                    if alerts.contains(test) {
                        Text(symbols: "!")
                            .font(theme.font(13, .bold))
                            .foregroundStyle(theme.text)
                    }
                }
        }
    }

    /// Les tests faits depuis le début de l'axe (◆ pleins, chiffrés) et le départ ●.
    @ChartContentBuilder
    private func testMarks(from start: Date) -> some ChartContent {
        ForEach(plan.tests.filter { $0.date >= start }, id: \.date) { test in
            PointMark(x: .value("Date", test.date), y: .value("Répétitions", Double(test.value)))
                .symbol {
                    Image(systemName: "diamond.fill")
                        .font(theme.font(13))
                        .foregroundStyle(theme.text)
                }
                .annotation(position: .topTrailing, spacing: 0) {
                    Text("\(test.value)")
                        .font(theme.font(13, .bold))
                        .foregroundStyle(theme.text)
                }
        }
        if let goal = plan.goal {
            PointMark(x: .value("Date", goal.created), y: .value("Répétitions", Double(goal.start)))
                .foregroundStyle(theme.text)
                .symbolSize(60)
        }
    }

    /// Aujourd'hui ▼, et la séance choisie au doigt.
    @ChartContentBuilder
    private func todayMarks(_ chosen: Point?) -> some ChartContent {
        RuleMark(x: .value("Date", Date()))
            .foregroundStyle(theme.primary)
            .lineStyle(StrokeStyle(lineWidth: 1.2))
            .annotation(position: .top, spacing: 0) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(theme.font(13))
                    .foregroundStyle(theme.primary)
            }
        if let chosen {
            RuleMark(x: .value("Date", chosen.date))
                .foregroundStyle(theme.dim.opacity(0.5))
                .annotation(position: .top, spacing: 2, overflowResolution: ChartKit.overflow) {
                    SelectionLabel(title: "\(chosen.value)", detail: Format.shortDate(chosen.date))
                }
        }
    }

    /// « Pompes d'affilée : départ 30, meilleure séance récente 32, dernier test 33, objectif 40 le 12 févr. »
    private func accessibility(_ points: [Point]) -> String {
        var parts: [String] = []
        if let goal = plan.goal { parts.append("départ \(goal.start)") }
        if let recent = points.suffix(4).map(\.value).max() { parts.append("meilleure séance récente \(recent)") }
        if let last = plan.tests.last { parts.append("dernier test \(last.value)") }
        if let goal = plan.goal {
            parts.append("objectif \(goal.target)" + (plan.shiftedGoalDate.map { " le \(Format.shortDate($0))" } ?? ""))
        }
        return "\(exercise.shortTitle) d'affilée : " + parts.joined(separator: ", ")
    }
}

extension View {
    /// Le cadre commun des cartes du Coaching.
    func coachingCard(_ theme: AppTheme) -> some View {
        padding(20)
            .cardBackground(theme)
    }
}

// MARK: - (i)

/// (i) du plan : le bloc, ce qui est sourcé, ce qui est un choix de l'app, ce qui est provisoire.
struct PlanInfoView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VerticalScroll {
                VStack(alignment: .leading, spacing: 22) {
                    section("Le bloc",
                            "3 semaines de progression, 1 semaine allégée, puis un test : une série max, ton nouveau niveau. Le bloc suivant repart de là. Le rythme 3 + 1 est un choix de l'app : l'ACSM ne trouve pas une programmation par blocs supérieure à une autre, pourvu que la charge progresse.")
                    section("Avec ou sans objectif",
                            "Le plan démarre dès que ta séance habituelle se calcule, objectif ou non : la séance du jour, le bloc et l'état s'affichent. L'objectif ajoute le chemin, la ligne attendue et le verdict. La proposition d'objectif, environ 20 % au-dessus de ton niveau (ta meilleure série des 4 dernières semaines, ou la dernière connue), est un choix de l'app : un point de départ, à modifier. Objectif atteint : la même règle propose le suivant. « Autre exercice » mêle des mouvements : pas de plan ni d'objectif.")
                    section("La séance prévue",
                            "Au moins 2 séances par semaine et 3 séries par séance, enchaînées avec le repos indiqué (ACSM 2026 : « at least twice weekly », « 2–3 sets/session »). La règle de l'ACSM porte sur l'effort : chaque série s'arrête près de l'échec, à 2 ou 3 répétitions en réserve ; aller jusqu'à l'échec n'apporte rien de plus. La série 1 vise ton max moins 3. Avec la fatigue, le nombre baisse d'une série à l'autre : les séries 2 et 3 suivent ta baisse habituelle (mesurée sur tes séances des 4 dernières semaines faites avec un repos proche) ; sans elle, chaque série vise 80 % de la précédente. Une série sous sa cible réajuste aussitôt les suivantes, sans rattrapage. Ces règles, la formule « max − 3 » et les 80 % (une valeur prudente) sont des choix de l'app : l'ACSM précise que la cible exacte n'est pas établie. Le max est celui du dernier test ; au premier bloc, ta meilleure série des 4 dernières semaines.")
                    section("Le repos",
                            "Le tien : ton repos habituel pour l'exercice, arrondi à 15 s. La durée du repos ne change pas les gains de force (ACSM 2026). Des séries faites séparément dans la journée comptent dans la séance du jour, sans pénalité (« séries espacées ») ; la suivante repart de la cible de la série 1. L'ACSM ne les étudie pas : le plan ne les prévoit pas.")
                    section("Les jours",
                            "Pas de jours à choisir : une séance est courte et se glisse n'importe quand dans la journée. Chaque jour, l'app propose une séance, ou conseille un repos dans quatre cas : la veille du test ; en fatigue persistante (Meeusen et al. 2013) ; le lendemain d'une séance notée « Très difficile » (effort 7 ou plus) ; après 20 séries sur les 7 derniers jours (au-delà d'environ 18 à 20 séries par semaine, les gains décroissent, ACSM 2026, établi pour le volume musculaire). Un repos est une proposition : une séance faite ce jour-là compte. À volume égal, la fréquence change peu le résultat (Grgic et al. 2018, résumé). Moins de 2 séances en 7 jours : l'app rappelle le minimum (ACSM 2026 : « at least twice weekly »). La veille du test et les seuils de 7 et de 20 sont des choix de l'app.")
                    section("Le test",
                            "Sourcé : le test recale ton niveau, et les cibles du bloc suivant en partent (ACSM 2026, p. 863 : « regular strength testing »). Le reste est un choix de l'app. Le jour de test est le lundi qui suit la semaine allégée ; c'est toi qui le lances (« ◆ Lancer le test »), et seules les séries faites en mode test comptent. Un échauffement facile est conseillé, jamais compté : environ un tiers de ton dernier max, puis 2 minutes de repos. Le résultat est ta meilleure série en mode test ; une 2e tentative est possible après au moins 3 minutes, le meilleur des deux compte. La série s'arrête quand le compteur détecte la fin. Au bloc 1 (et à un nouveau bloc 1 après plus de 28 jours sans séance), la première semaine mesure ton niveau : 2 tests à 2 jours d'écart, le 1er au plus tard le vendredi pour laisser la place au 2e ; le meilleur sert de départ. Sans test cette semaine-là, tes séances calent tes cibles (choix de l'app). Un test lancé en semaine allégée compte et clôt le bloc ; lancé en semaine de progression, il ne clôt pas le bloc mais relève le max s'il le dépasse. Plusieurs tests : le meilleur, du premier test au début du bloc suivant. Lancé puis abandonné sans série : il reste à faire. Pas lancé : « à faire » les jours suivants, avec une séance allégée en attendant (elle compte comme séance, pas comme test) ; 7 jours après le jour prévu, le bloc suivant repart de ton dernier max, sans recalage. Plus de 7 jours sans séance : une semaine de reprise avant le test. Entre deux tests, un écart de moins d'environ 10 % se lit « dans la variation » (seuil provisoire ; principe : Hopkins). Entre deux tests, une série qui dépasse ton max le relève : le nouveau max est le nombre de répétitions faites (on ne suppose pas de réserve : on se trompe d'environ 1 répétition en l'estimant, Halperin et al. 2022 ; le test de fin de bloc mesure le reste), et les cibles suivent dès la séance suivante. Pas de mode test pour « Autre exercice ».")
                    section("Après une longue absence",
                            "Après plus de 28 jours sans séance, le plan ne propose qu'une séance de reprise, libre : elle ouvre un nouveau bloc 1, ancré sur elle. Ce bloc commence, comme le tout premier, par 2 tests dans la première semaine ; sans ces tests, la semaine 1 calibre (les cibles suivent chaque séance), puis les cibles restent fixes jusqu'au test, sauf si une série relève le max. Le seuil de 28 jours et ce calibrage sont des choix de l'app.")
                    section("La progression",
                            "Par le test : ton nouveau max recale la cible du bloc suivant (l'ACSM recommande des tests réguliers). Entre deux tests, la cible ne monte pas d'elle-même : aucune hausse d'une semaine à l'autre, l'article n'en chiffre aucune. Mais une série qui dépasse ton max le relève à ses répétitions, et les cibles suivent dès la séance suivante (choix de l'app).")
                    section("Ce que la science ne dit pas",
                            "L'entraînement améliore l'endurance musculaire, mais les études ne permettent pas de dire quel dosage l'améliore le mieux (ACSM 2026). Le plan applique donc les recommandations générales (fréquence, séries, effort près de l'échec) et vérifie le résultat, test après test.")
                    section("La semaine allégée",
                            "7 jours à volume réduit : la moitié des séries, arrondie au-dessus (part choisie par l'app). Réduire le volume fait consensus (Bell et al. 2023) ; les athlètes de force allègent en moyenne 6,4 jours (Rogerson et al. 2024). L'ACSM ne traite pas des décharges.")
                    section("Quand ça décroche",
                            "Une semaine de progression avec moins de 2 séances (une seule la semaine où le plan commence en cours de semaine), ou deux séances en Forme basse, est refaite (deux fois au plus par bloc). Le test recule d'autant, et la date de l'objectif aussi. Forme basse aujourd'hui : séance légère, la moitié des séries. Ces règles sont des choix de l'app ; deux mesures plutôt qu'une, pour ne pas confondre une baisse et le bruit (Hopkins 2000) ; au-delà de 2 semaines de baisse, une semaine allégée (Meeusen et al. 2013).")
                    section("Mesuré face à attendu",
                            "L'attendu est le rythme qu'il te faut pour aller de ton départ à ton objectif à la date choisie : ce n'est pas une prédiction, aucune courbe de progression au poids du corps n'est publiée. « En avance » ou « en retard » seulement après 3 tests, quand la pente de tes tests (Theil-Sen, intervalle à 99 %, Sen 1968) est sûrement au-dessus ou au-dessous du rythme nécessaire.")
                    section("Références",
                            "Currier et al. (2026). Resistance training prescription for muscle function, hypertrophy and physical performance in healthy adults: an overview of reviews. Med Sci Sports Exerc 58(4):851–872. Bell et al. (2023), Sports Med Open 9:87. Rogerson et al. (2024), Sports Med Open 10:26. Meeusen et al. (2013), Med Sci Sports Exerc 45(1):186–205. Hopkins (2000), Sports Med 30(1):1–15. Sen (1968), J Am Stat Assoc 63:1379–1389. Halperin et al. (2022), Sports Med 52:377–390 (résumé). Grgic et al. (2018), Sports Med 48(5):1207–1220 (résumé).")
                    section("Séance faite",
                            "Une séance terminée compte comme faite. Chaque série est jugée sur la cible que le compteur affichait, réajustée si la série d'avant était sous la sienne : « fait ✓ » si toutes sont atteintes, sinon « fait · cible non atteinte » (choix de l'app).")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .sheetNavigation("Le plan", display: .large)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(theme.font(17, .bold))
                .foregroundStyle(theme.text)
            Text(text)
                .font(theme.font(17))
                .foregroundStyle(theme.text)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// « En savoir plus » du jour de test : à quoi sert le test, comment le faire, ce qui suit.
/// Texte long permis ici : c'est une vue optionnelle (skill reps-ux, § 12). Sources :
/// `Science/METHODE-TEST.md`, règles 1, 4, 5 et 10.
struct TestInfoView: View {
    @Environment(\.theme) private var theme
    let plan: TrainingPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("À quoi il sert",
                        plan.testStep != nil
                        ? "Il mesure ton niveau de départ. Tes cibles des 3 prochaines semaines en partiront : ni trop faciles, ni hors de portée."
                        : "Il mesure ce que tu as gagné pendant le bloc. Tes cibles du bloc suivant en partiront : elles montent avec toi.")
                section("Comment le faire",
                        "Échauffe-toi avec une série facile, puis repose-toi 2 minutes ; l'app te le propose. Lance ensuite le test et fais le plus de répétitions possible, en une seule série, sans pause. Tu peux faire une 2e tentative après 3 minutes de repos : la meilleure compte.")
                section("Comment lire le résultat",
                        "D'un jour à l'autre, ton max varie naturellement d'environ 10 %. Un écart plus petit n'est ni un progrès ni un recul ; tes cibles suivent quand même ton résultat.")
                if plan.testStep == nil {
                    section("Si tu ne peux pas aujourd'hui",
                            "Le test reste à faire les jours suivants. En attendant, une séance allégée t'est proposée.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("Le test")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(theme.font(17, .semibold))
                .foregroundStyle(theme.text)
            Text(text)
                .font(theme.font(17))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
