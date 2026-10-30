import SwiftUI
import TipKit

/// Les explications du premier affichage (skill reps-ux, § 6), en TipKit : chacune s'affiche une
/// fois, au moment utile ; TipKit retient qu'elle a été vue.
enum RepsTips {
    /// À l'ouverture de l'app. Les explications déjà vues avant TipKit (clés UserDefaults) ne
    /// reviennent pas.
    static func configure() {
        try? Tips.configure([.displayFrequency(.immediate)])
        // Le test annoncé entre dans l'app : les séances d'avant gardent l'ancienne règle du test
        _ = TrainingPlan.announcedTestSince
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "coaching.dotExplained") { StateTip().invalidate(reason: .actionPerformed) }
        if defaults.bool(forKey: "coaching.blockExplained") { BlockTip().invalidate(reason: .actionPerformed) }
    }
}

/// Le point d'état sur la cible du Coaching : l'échelle d'intensité. Il n'est proposé que si le
/// point est affiché (en veille, avec une couleur) : la vue ne le passe qu'à cette condition.
struct StateTip: Tip {
    var title: Text { Text("Ton plan, en un point") }
    var message: Text? {
        Text("Calme : semaine allégée ou séance légère. Soutenu : la séance prévue. Maximal : jour de test. Touche la cible : ton plan.")
    }
    var image: Image? { Image(systemName: "scope") }
}

/// Le bloc, à la première ouverture du Coaching avec un plan.
struct BlockTip: Tip {
    var title: Text { Text("Un bloc = 4 semaines") }
    var message: Text? {
        Text("3 semaines de progression, 1 semaine allégée, puis le test : une série max, ton nouveau niveau. Le bloc suivant repart de là.")
    }
    var image: Image? { Image(systemName: "square.stack.3d.up.fill") }
}

/// Le premier jour de test : le principe, une seule fois.
struct TestTip: Tip {
    var title: Text { Text("Jour de test") }
    var message: Text? { Text("Une série max. Échauffe-toi d'abord ; une 2e tentative est possible.") }
    var image: Image? { Image(systemName: "diamond.fill") }
}
