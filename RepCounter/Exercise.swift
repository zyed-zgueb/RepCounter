import Foundation

/// Exercice choisi par l'utilisateur : où est le téléphone, quels capteurs écouter.
/// Mêmes profils que `PROFILES` dans Simulation/simulate_counter.py.
enum Exercise: String, CaseIterable, Identifiable {
    case pushups, crunches, squats, curls, press, auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Autre exercice"
        case .pushups: return "Pompes"
        case .crunches: return "Abdos"
        case .squats: return "Squats"
        case .curls: return "Biceps"
        case .press: return "Développé épaules"
        }
    }

    /// Exercice avec haltère : sa charge est demandée et entre dans l'indice de performance.
    var isWeighted: Bool { self == .curls || self == .press }

    /// Équipement choisi pour cet exercice (1 haltère, 2 haltères ou une barre), mémorisé.
    var loadKind: LoadKind {
        get { UserDefaults.standard.string(forKey: "loadKind.\(rawValue)").flatMap(LoadKind.init) ?? .two }
        nonmutating set { UserDefaults.standard.set(newValue.rawValue, forKey: "loadKind.\(rawValue)") }
    }

    /// Poids choisi pour cet exercice (kg, par haltère, ou de la barre), mémorisé.
    var load: Double {
        get {
            let saved = UserDefaults.standard.double(forKey: "load.\(rawValue)")
            return saved > 0 ? saved : 5
        }
        nonmutating set { UserDefaults.standard.set(newValue, forKey: "load.\(rawValue)") }
    }

    /// Nom court, pour le cadran et les tuiles du choix d'exercice.
    var shortTitle: String {
        switch self {
        case .auto: return "Autre"
        case .press: return "Développé"
        default: return title
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "sparkles"
        case .pushups: return "figure.cross.training"   // non affiché : voir ExerciseIcon
        case .crunches: return "figure.core.training"
        case .squats: return "figure.strengthtraining.functional"
        case .curls: return "dumbbell.fill"
        case .press: return "figure.strengthtraining.traditional"   // non affiché : voir ExerciseIcon
        }
    }

    /// Où mettre le téléphone.
    var placement: String {
        switch self {
        case .auto: return "Téléphone posé face à toi ou porté sur toi ; l'app cherche le geste répété."
        case .pushups: return "Téléphone au sol, écran vers le haut, au niveau de ta tête."
        case .crunches: return "Téléphone tenu à plat contre la poitrine."
        case .squats: return "Téléphone tenu à la main ou contre la poitrine."
        case .curls: return "Téléphone dans un brassard sur l'avant-bras qui travaille, près du poignet."
        case .press: return "Téléphone dans un brassard sur l'avant-bras qui pousse."
        }
    }

    /// Capteurs, en abrégé (accueil).
    var sensorTag: String {
        switch self {
        case .auto: return "MULTI"
        case .pushups: return "CAM 3D"
        case .crunches: return "GYRO"
        case .squats: return "ACCÉL"
        case .curls: return "INCL"
        case .press: return "ACCÉL"
        }
    }

    /// Capteurs écoutés, par ordre de préférence.
    var sources: [SignalSource] {
        switch self {
        case .auto: return [.depth, .motion, .vertical, .pose, .face, .pixels]
        case .pushups: return [.depth, .face, .pixels]
        // Abdos dynamiques : le gyroscope voit un petit basculement rapide des épaules
        // ~7 fois plus fort qu'une respiration de même angle
        case .crunches: return [.rotation]
        case .squats: return [.vertical, .motion]
        case .curls: return [.motion, .rotation]
        case .press: return [.vertical, .motion]
        }
    }

    /// Téléphone posé pendant l'exercice : le manipuler remet l'analyse à zéro.
    var phoneAtRest: Bool { self == .pushups }

    /// La caméra n'est allumée que si l'exercice en a besoin.
    var usesCamera: Bool {
        !Set(sources).isDisjoint(with: [.depth, .pixels, .face, .pose])
    }

    /// Écart maximal entre deux répétitions (s).
    var maxPeriod: Double {
        switch self {
        case .crunches: return 3   // au-delà, ce serait la respiration
        default: return 6
        }
    }
}

/// Équipement d'un exercice avec charge. Le poids réglé est celui d'un haltère (ou de la barre) ;
/// la charge totale soulevée est ce poids multiplié par le nombre d'haltères.
enum LoadKind: String, CaseIterable {
    case one, two, bar

    var title: String {
        switch self {
        case .one: return "1 haltère"
        case .two: return "2 haltères"
        case .bar: return "Barre"
        }
    }

    /// Charges égales soulevées en même temps.
    var pieces: Int { self == .two ? 2 : 1 }

    var next: LoadKind {
        let all = LoadKind.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    /// « 2 × 5 kg », « 1 × 8 kg », « 20 kg » (barre).
    func describe(_ weight: Double) -> String {
        self == .bar ? Format.kilograms(weight) : "\(pieces) × \(Format.kilograms(weight))"
    }
}
