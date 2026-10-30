import SwiftUI
import TipKit

/// Les explications du premier affichage (skill reps-ux, § 6), en TipKit : chacune s'affiche une
/// fois, au moment utile ; TipKit retient qu'elle a été vue. Une seule à la fois : l'astuce des
/// jours attend que celle du bloc soit fermée.
enum RepsTips {
    /// À l'ouverture de l'app. Les explications déjà vues avant TipKit (clés UserDefaults) ne
    /// reviennent pas.
    static func configure() {
        try? Tips.configure([.displayFrequency(.immediate)])
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "coaching.dotExplained") { StateTip().invalidate(reason: .actionPerformed) }
        if defaults.bool(forKey: "coaching.blockExplained") { BlockTip().invalidate(reason: .actionPerformed) }
        if defaults.bool(forKey: "coaching.daysHintSeen") { DaysTip().invalidate(reason: .actionPerformed) }
    }
}

/// Le point d'état sur la cible du Coaching : l'échelle d'intensité.
struct StateTip: Tip {
    /// Le point est affiché (en veille, avec une couleur) : l'astuce n'a de sens qu'avec lui.
    @Parameter static var dotShown = false

    var title: Text { Text("Ton plan, en un point") }
    var message: Text? {
        Text("Calme : semaine allégée ou séance légère. Soutenu : la séance prévue. Maximal : jour de test. Touche la cible : ton plan.")
    }
    var image: Image? { Image(systemName: "scope") }
    var rules: [Rule] {
        #Rule(Self.$dotShown) { $0 == true }
    }
}

/// Le bloc, à la première ouverture du Coaching avec un plan.
struct BlockTip: Tip {
    var title: Text { Text("Un bloc = 4 semaines") }
    var message: Text? {
        Text("3 semaines de progression, 1 semaine allégée, puis le test : une série max, ton nouveau niveau. Le bloc suivant repart de là.")
    }
    var image: Image? { Image(systemName: "square.stack.3d.up.fill") }
}

/// Les jours de séance se déplacent d'une touche.
struct DaysTip: Tip {
    var title: Text { Text("Tes jours de séance") }
    var message: Text? { Text("Touche un jour pour l'ajouter ou le retirer.") }
    var image: Image? { Image(systemName: "hand.tap") }
}
