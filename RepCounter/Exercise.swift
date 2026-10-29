import Foundation

/// Exercice choisi par l'utilisateur : où est le téléphone, quels capteurs écouter.
/// Mêmes profils que `PROFILES` dans Simulation/simulate_counter.py.
enum Exercise: String, CaseIterable, Identifiable {
    case pushups, crunches, squats, lunges, pullups, dips, curls, row, press, auto

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Autre exercice"
        case .pushups: return "Pompes"
        case .crunches: return "Abdos"
        case .squats: return "Squats"
        case .lunges: return "Fentes"
        case .pullups: return "Tractions"
        case .dips: return "Dips"
        case .curls: return "Biceps"
        case .row: return "Rowing haltère"
        case .press: return "Développé épaules"
        }
    }

    /// Exercice avec haltère : sa charge est demandée et entre dans l'indice de performance.
    var isWeighted: Bool { self == .curls || self == .press || self == .row }

    /// Équipement choisi pour cet exercice (1 haltère, 2 haltères ou une barre), mémorisé.
    var loadKind: LoadKind {
        get { UserDefaults.standard.string(forKey: "loadKind.\(rawValue)").flatMap(LoadKind.init) ?? (self == .row ? .one : .two) }
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
        case .row: return "Rowing"
        default: return title
        }
    }

    // MARK: Brassard

    /// Biceps, développé, rowing : le téléphone se porte sur l'avant-bras (brassard) ou se pose
    /// face à soi (caméra), selon que l'on a un brassard ou non (Réglages).
    var isArmExercise: Bool { isWeighted }

    /// « J'ai un brassard » (Réglages) : les exercices de bras se comptent au bras.
    static let armbandKey = "equipment.armband"
    static var hasArmband: Bool { UserDefaults.standard.bool(forKey: armbandKey) }

    /// Exercice de bras compté à la caméra (pas de brassard déclaré).
    var countsWithCamera: Bool { isArmExercise && !Self.hasArmband }

    /// Où mettre le téléphone : une étiquette de quelques mots (le détail est dans la fiche).
    var placement: String { placement(armband: Self.hasArmband) }

    func placement(armband: Bool) -> String {
        if isArmExercise, !armband {
            return self == .row ? "Posé à deux pas, de profil" : "Posé à deux pas, face à toi"
        }
        switch self {
        case .auto: return "Face à toi, ou sur toi"
        case .pushups: return "Au sol, sous ton visage"
        case .crunches: return "À plat sur ta poitrine"
        case .squats: return "En poche ou au bras"
        case .curls, .press, .row: return "Au brassard, sur l'avant-bras"
        case .lunges: return "En main ou contre toi"
        case .pullups, .dips: return "Dans ta poche"
        }
    }

    /// Capteurs, en abrégé (accueil).
    var sensorTag: String {
        if countsWithCamera { return "CAMÉRA" }
        switch self {
        case .auto: return "MULTI"
        case .pushups: return "CAM 3D"
        case .crunches: return "GYRO"
        case .squats: return "ACCÉL"
        case .curls, .row: return "INCL"
        case .press, .lunges, .pullups, .dips: return "ACCÉL"
        }
    }

    /// Capteurs écoutés, par ordre de préférence.
    var sources: [SignalSource] {
        // Exercice de bras sans brassard : la caméra voit le squelette (poignets, coudes) et
        // l'image ; les capteurs de mouvement restent à l'écoute si le téléphone est malgré tout
        // porté au bras. (La profondeur TrueDepth ne porte pas jusqu'à 2 m.)
        if countsWithCamera {
            return self == .press ? [.pose, .pixels, .vertical, .motion] : [.pose, .pixels, .motion, .rotation]
        }
        switch self {
        case .auto: return [.depth, .motion, .vertical, .pose, .face, .pixels]
        case .pushups: return [.depth, .face, .pixels]
        // Abdos dynamiques : le gyroscope voit un petit basculement rapide des épaules
        // ~7 fois plus fort qu'une respiration de même angle
        case .crunches: return [.rotation]
        case .squats: return [.vertical, .motion]
        case .curls: return [.motion, .rotation]
        case .press: return [.vertical, .motion]
        // Le corps monte et descend : le téléphone (en poche ou tenu) le suit
        case .lunges, .pullups, .dips: return [.vertical, .motion]
        // Comme les flexions : le téléphone pivote avec l'avant-bras qui tire
        case .row: return [.motion, .rotation]
        }
    }

    /// Téléphone posé pendant l'exercice : le manipuler remet l'analyse à zéro.
    var phoneAtRest: Bool { self == .pushups }

    /// Moment où une répétition compte : à la fin de l'effort. On part en haut et on compte en
    /// haut, au retour (pompes, squats, fentes, dips) ; ou on part bras tendus et on compte au
    /// bout de la traction ou de la poussée, à l'autre extrême (tractions, développé, biceps,
    /// rowing). Les abdos comptent au sommet par le gyroscope (début de la redescente), et
    /// l'accélération verticale toujours à son creux, au sommet du geste.
    var countsAtFarEnd: Bool { [.pullups, .press, .curls, .row].contains(self) }

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

// MARK: - Mes exercices

extension Exercise {
    /// Exercices du cadran, dans l'ordre où ils défilent (Réglages › Mes exercices). Les autres
    /// restent au catalogue, prêts à être ajoutés.
    static let mineKey = "myExercises"
    static let defaultMine: [Exercise] = [.pushups, .crunches, .squats, .lunges, .pullups]
    static let defaultMineValue = encode(defaultMine)

    static func decode(_ value: String) -> [Exercise] {
        var list: [Exercise] = []
        for raw in value.split(separator: ",") {
            if let exercise = Exercise(rawValue: String(raw)), !list.contains(exercise) { list.append(exercise) }
        }
        return list.isEmpty ? defaultMine : list
    }

    static func encode(_ list: [Exercise]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
