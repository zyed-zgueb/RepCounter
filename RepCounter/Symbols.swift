import SwiftUI

/// Les symboles de l'app en SF Symbols (skill reps-ux, § 9 et § 11). Les textes gardent leurs
/// glyphes courts (« ◆ test », « ! léger », « ★ 32 ») ; à l'affichage, chaque glyphe devient le
/// SF Symbol correspondant, en ligne dans le texte, et VoiceOver lit un mot à sa place. Aucun
/// caractère Unicode n'est donc montré comme icône ; Σ reste un caractère, faute d'équivalent.
enum Symbols {
    struct Entry {
        let name: String
        /// Ce que lit VoiceOver.
        let word: String
        /// Un symbole plus petit que le texte (• : un petit point), en style relatif.
        var small = false
    }

    static let table: [Character: Entry] = [
        "⌖": Entry(name: "scope", word: "objectif"),
        "◆": Entry(name: "diamond.fill", word: "test"),
        "✓": Entry(name: "checkmark", word: "atteint"),
        "●": Entry(name: "circle.fill", word: "fait"),
        "•": Entry(name: "circle.fill", word: "séance", small: true),
        "○": Entry(name: "circle", word: "prévu"),
        "!": Entry(name: "exclamationmark.circle", word: "alerte"),
        "★": Entry(name: "star.fill", word: "record"),
        "▲": Entry(name: "arrowtriangle.up.fill", word: "hausse"),
        "▼": Entry(name: "arrowtriangle.down.fill", word: "baisse"),
        "◷": Entry(name: "timer", word: "repos"),
        "✎": Entry(name: "pencil", word: "modifier"),
        "⋯": Entry(name: "ellipsis", word: "menu"),
        "⚑": Entry(name: "flag.fill", word: "objectif"),
        "‹": Entry(name: "chevron.left", word: "avant"),
        "›": Entry(name: "chevron.right", word: "après"),
        "←": Entry(name: "arrow.left", word: "en cours"),
        "✕": Entry(name: "xmark", word: "retirer"),
        "☝": Entry(name: "hand.point.up.left", word: ""),
        "■": Entry(name: "stop.fill", word: "arrêt"),
        "≡": Entry(name: "line.3.horizontal", word: "poignée"),
    ]

    /// « ! » n'est un symbole qu'en marque d'alerte : seul, en tête, ou après « · ».
    private static func isAlertMark(_ text: [Character], at index: Int) -> Bool {
        let before = index == 0 || (index >= 2 && text[index - 1] == " " && text[index - 2] == "·")
        let after = index == text.count - 1 || text[index + 1] == " "
        return before && after
    }

    /// Le texte, ses glyphes remplacés par leurs SF Symbols, et sa version lue par VoiceOver.
    static func text(_ string: String) -> Text {
        let characters = Array(string)
        var result = Text("")
        var spoken = ""
        var run = ""
        func flush() {
            if !run.isEmpty { result = result + Text(run) }
            run = ""
        }
        for (index, character) in characters.enumerated() {
            if let entry = table[character], character != "!" || isAlertMark(characters, at: index) {
                flush()
                var image = Text(Image(systemName: entry.name))
                // Un demi-caption2, mis à l'échelle Dynamic Type (pas de taille fixe)
                if entry.small { image = image.font(.system(size: UIFontMetrics(forTextStyle: .caption2).scaledValue(for: 5.5))) }
                result = result + image
                spoken += entry.word
            } else {
                run.append(character)
                spoken.append(character)
            }
        }
        flush()
        // Les glyphes sans symbole n'ont pas de place dans la lecture : « · » se tait
        return result.accessibilityLabel(spoken.replacingOccurrences(of: " · ", with: ", "))
    }
}

extension Text {
    /// Un texte dont les glyphes de l'app (◆ ★ ! ◷…) s'affichent en SF Symbols.
    init(symbols string: String) {
        self = Symbols.text(string)
    }
}
