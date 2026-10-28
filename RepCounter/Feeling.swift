import SwiftUI

/// Le ressenti, en deux questions facultatives d'un toucher, croisé avec la mesure (Saw, Main et
/// Gastin 2016, Br J Sports Med 50(5):281–291 : le ressenti suit la charge d'entraînement mieux
/// que les mesures objectives courantes, et les deux concordent mal).
/// - Avant la séance : « Fatigue ? », 1 à 5, item fatigue du questionnaire de McLean et al. 2010
///   (Int J Sports Physiol Perform 5(3):367–383) : de « très frais » à « toujours fatigué ».
///   Pas de question « Force ? » : aucun item validé trouvé.
/// - En fin de séance : « Effort ? », 0 à 10, échelle CR-10 modifiée par Foster et al. 2001
///   (J Strength Cond Res 15(1):109–115) ; charge de séance = effort × durée (min).
/// Rien avant la 4e séance (le premier lancement reste sans questionnaire) ; plus rien après
/// 5 séances de suite sans réponse (réactivable dans les Réglages).
enum Feeling {
    static let enabledKey = "feeling.enabled"
    static let skippedKey = "feeling.skipped"
    /// Réponse « Fatigue ? » du jour : valeur et date.
    static let fatigueKey = "feeling.fatigue"
    static let fatigueDateKey = "feeling.fatigueDate"

    /// Séances terminées avant la première question.
    static let afterSessions = 3
    /// Séances de suite sans réponse avant de ne plus demander.
    static let maxSkipped = 5

    /// Fatigue à partir de laquelle on se dit fatigué (4 et 5 sur 5).
    static let tiredFrom = 4

    /// Extrémités de l'échelle de fatigue (McLean 2010).
    static let fatigueAnchors = (low: "Très frais", high: "Toujours fatigué")

    /// Échelle CR-10 modifiée de Foster (2001) : une étiquette pour 0, 1, 2, 3, 4, 5, 7 et 10.
    static func effortLabel(_ value: Int) -> String {
        switch value {
        case 0: return "Repos"
        case 1: return "Très, très facile"
        case 2: return "Facile"
        case 3: return "Modéré"
        case 4: return "Un peu difficile"
        case 5, 6: return "Difficile"
        case 7, 8, 9: return "Très difficile"
        default: return "Maximal"
        }
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// Les questions sont-elles posées, après `sessions` séances terminées ?
    static func asks(after sessions: Int) -> Bool {
        isEnabled && sessions >= afterSessions
    }

    /// La fatigue notée aujourd'hui, s'il y en a une.
    static func todayFatigue(now: Date = Date(), calendar: Calendar = .current) -> Int? {
        let defaults = UserDefaults.standard
        guard let date = defaults.object(forKey: fatigueDateKey) as? Date, calendar.isDate(date, inSameDayAs: now) else { return nil }
        let value = defaults.integer(forKey: fatigueKey)
        return (1...5).contains(value) ? value : nil
    }

    static func setTodayFatigue(_ value: Int?, now: Date = Date()) {
        let defaults = UserDefaults.standard
        if let value {
            defaults.set(value, forKey: fatigueKey)
            defaults.set(now, forKey: fatigueDateKey)
        } else {
            defaults.removeObject(forKey: fatigueDateKey)
        }
    }

    /// Une séance se termine : sans aucune réponse 5 fois de suite, on ne demande plus.
    static func sessionEnded(answered: Bool) {
        let defaults = UserDefaults.standard
        let skipped = answered ? 0 : defaults.integer(forKey: skippedKey) + 1
        defaults.set(skipped, forKey: skippedKey)
        if skipped >= maxSkipped {
            defaults.set(false, forKey: enabledKey)
            defaults.set(0, forKey: skippedKey)
        }
    }
}

// MARK: - Interface

/// Une échelle d'un toucher : une étiquette, la valeur choisie en mots, une case par valeur.
/// Toucher la valeur choisie l'efface.
struct FeelingScale: View {
    @Environment(\.theme) private var theme
    let title: String
    let values: ClosedRange<Int>
    let selection: Int?
    /// La valeur choisie en mots (ou les extrémités, avant de choisir).
    let caption: String
    let onSelect: (Int?) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                MonitorLabel(title)
                Spacer(minLength: 8)
                Text(caption)
                    .font(theme.font(11))
                    .foregroundStyle(selection == nil ? theme.dim : theme.text)
                    .lineLimit(1)
                    .contentTransition(.opacity)
            }
            HStack(spacing: 4) {
                ForEach(Array(values), id: \.self) { value in
                    let chosen = value == selection
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.snappy(duration: 0.15)) { onSelect(chosen ? nil : value) }
                    } label: {
                        Text("\(value)")
                            .font(theme.font(12, .bold))
                            .monospacedDigit()
                            .foregroundStyle(chosen ? theme.background : theme.text)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(chosen ? theme.primary : .clear, in: RoundedRectangle(cornerRadius: theme.radius / 2, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: theme.radius / 2, style: .continuous)
                                .stroke(chosen ? theme.primary : theme.line, lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title) \(value)")
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
        }
    }
}

/// « Effort ? » en fin de séance (CR-10 de Foster).
struct EffortQuestion: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var record: SessionRecord

    var body: some View {
        FeelingScale(title: "Effort ?", values: 0...10, selection: record.effort,
                     caption: record.effort.map(Feeling.effortLabel) ?? "0 repos · 10 maximal") { value in
            record.effort = value
            try? modelContext.save()
        }
    }
}

/// « Fatigue ? » avant la séance (item fatigue de McLean 2010), une fois par jour.
struct FatigueQuestion: View {
    @Binding var fatigue: Int?

    var body: some View {
        FeelingScale(title: "Fatigue ?", values: 1...5, selection: fatigue,
                     caption: caption) { value in
            fatigue = value
            Feeling.setTodayFatigue(value)
        }
    }

    private var caption: String {
        switch fatigue {
        case 1: return Feeling.fatigueAnchors.low
        case 5: return Feeling.fatigueAnchors.high
        case .some(let value): return "\(value) / 5"
        case nil: return "1 \(Feeling.fatigueAnchors.low.lowercased()) · 5 \(Feeling.fatigueAnchors.high.lowercased())"
        }
    }
}
