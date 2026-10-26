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

    var symbol: String {
        switch self {
        case .auto: return "sparkles"
        case .pushups: return "figure.cross.training"
        case .crunches: return "figure.core.training"
        case .squats: return "figure.strengthtraining.functional"
        case .curls: return "dumbbell.fill"
        case .press: return "figure.strengthtraining.traditional"
        }
    }

    /// Où mettre le téléphone.
    var placement: String {
        switch self {
        case .auto: return "Téléphone posé face à toi ou porté sur toi ; l'app cherche le geste répété."
        case .pushups: return "Téléphone au sol, écran vers le haut, sous ta tête."
        case .crunches: return "Téléphone tenu à plat contre la poitrine."
        case .squats: return "Téléphone tenu à la main ou contre la poitrine."
        case .curls: return "Téléphone dans la main qui travaille."
        case .press: return "Téléphone dans un brassard sur l'avant-bras qui pousse."
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
