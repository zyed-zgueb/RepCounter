import SwiftUI

// MARK: - Thèmes

/// Un thème d'affichage, décrit dans `Themes.json` : couleurs, police, arrondis, lueur.
/// Ajouter un thème ne demande aucun changement d'écran. Tous les thèmes sont gratuits.
struct AppTheme: Decodable, Identifiable, Equatable {
    struct Palette: Decodable, Equatable {
        let background, panel, line, grid, text, dim: String
        /// Tracé principal et action principale ; secondaire pour les dégradés.
        let primary, secondary: String
        let ok, warn, alarm: String
        /// L'intensité, une seule échelle (skill reps-ux, § 5) : calme (semaine allégée, séance
        /// légère), soutenu (progression), maximal (jour de test), en dégradé.
        let calm, work, max: String
        /// Texte sur un bouton plein.
        let onPrimary: String
    }

    let id: String
    let name: String
    /// "dark" ou "light".
    let scheme: String
    /// "monospaced", "rounded" ou "default".
    let font: String
    let radius: CGFloat
    /// Intensité de la lueur des tracés (0 : aucune).
    let glow: Double
    let colors: Palette

    /// Le thème « système » (skill reps-ux, § 11) : hors compteur, les écrans suivent le mode
    /// clair ou sombre de l'iPhone, avec les couleurs sémantiques d'Apple, façon Santé.
    var isSystem: Bool { id == Self.systemID }

    var background: Color { isSystem ? Color(uiColor: .systemGroupedBackground) : Color(hex: colors.background) }
    var panel: Color { isSystem ? Color(uiColor: .secondarySystemGroupedBackground) : Color(hex: colors.panel) }
    var line: Color { isSystem ? Color(uiColor: .separator) : Color(hex: colors.line) }
    var grid: Color { isSystem ? Color(uiColor: .quaternaryLabel) : Color(hex: colors.grid) }
    var text: Color { isSystem ? Color(uiColor: .label) : Color(hex: colors.text) }
    var dim: Color { isSystem ? Color(uiColor: .secondaryLabel) : Color(hex: colors.dim) }
    var primary: Color { isSystem ? Color(uiColor: .systemBlue) : Color(hex: colors.primary) }
    var secondary: Color { isSystem ? Color(uiColor: .systemPurple) : Color(hex: colors.secondary) }
    var ok: Color { isSystem ? SystemPalette.ok : Color(hex: colors.ok) }
    var warn: Color { isSystem ? Color(uiColor: .systemOrange) : Color(hex: colors.warn) }
    var alarm: Color { isSystem ? SystemPalette.alarm : Color(hex: colors.alarm) }
    var calm: Color { isSystem ? SystemPalette.calm : Color(hex: colors.calm) }
    var work: Color { isSystem ? SystemPalette.work : Color(hex: colors.work) }
    var max: Color { isSystem ? SystemPalette.max : Color(hex: colors.max) }

    /// L'intensité sur l'échelle continue, de 0 (calme) à 1 (maximal) ; soutenu à 0,6.
    func intensity(_ level: Double) -> Color {
        let level = Swift.min(Swift.max(level, 0), 1)
        return level <= Self.workLevel
            ? calm.mixed(with: work, by: level / Self.workLevel)
            : work.mixed(with: max, by: (level - Self.workLevel) / (1 - Self.workLevel))
    }

    /// Le dégradé de l'intensité, de calme à maximal.
    var intensityGradient: Gradient {
        Gradient(stops: [.init(color: calm, location: 0), .init(color: work, location: Self.workLevel),
                         .init(color: max, location: 1)])
    }

    static let workLevel = 0.6
    var onPrimary: Color { isSystem ? .white : Color(hex: colors.onPrimary) }

    /// Le mode du thème ; le thème système suit celui de l'iPhone (l'écran, pas la fenêtre, que
    /// le compteur habille de son thème).
    var colorScheme: ColorScheme {
        if isSystem { return SystemPalette.deviceScheme }
        return scheme == "light" ? .light : .dark
    }

    /// Une taille de la maquette. Thème système : le style Dynamic Type le plus proche, en SF
    /// Rounded (aucune taille fixe) ; au-delà du grand titre, la taille suit l'échelle du grand titre.
    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if isSystem {
            if size > 34 {
                return .system(size: UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: size), weight: weight, design: .rounded)
            }
            return .system(Self.textStyle(size), design: .rounded, weight: weight)
        }
        let design: Font.Design
        switch font {
        case "rounded": design = .rounded
        case "default": design = .default
        default: design = .monospaced
        }
        // Compteur : les libellés suivent Dynamic Type dans la police du thème ; les grands chiffres
        // (le nombre du cadran, calculé sur sa taille) gardent leur taille
        if size > 34 { return .system(size: size, weight: weight, design: design) }
        return .system(Self.textStyle(size), design: design, weight: weight)
    }

    /// Une taille calculée sur celle du cadran (le nombre compté) : elle suit le cadran, pas
    /// Dynamic Type.
    func dialFont(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let design: Font.Design = font == "rounded" ? .rounded : (font == "default" ? .default : .monospaced)
        return .system(size: size, weight: weight, design: isSystem ? .rounded : design)
    }

    /// Le style Dynamic Type d'une taille de maquette.
    /// L'échelle typographique de l'app : 5 tailles, pas une de plus, et jamais sous 13 pt
    /// (skill reps-ux, « Typographie et espace »). Une taille demandée est rangée dans l'une des
    /// 5 : chiffre clé (34), titre (22), texte (17), secondaire (15), note (13). Toutes suivent
    /// Dynamic Type.
    static func textStyle(_ size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...: return .largeTitle
        case 20..<30: return .title2
        case 16..<20: return .body
        case 13.5..<16: return .subheadline
        default: return .footnote
        }
    }

    static let systemID = "system"

    /// Hors compteur : couleurs sémantiques, cartes à 12 pt d'arrondi, sans lueur.
    static let system = AppTheme(
        id: systemID, name: "Système", scheme: "light", font: "rounded", radius: 12, glow: 0,
        colors: Palette(background: "#F2F2F7", panel: "#FFFFFF", line: "#C6C6C8", grid: "#E5E5EA",
                        text: "#000000", dim: "#6C6C70", primary: "#007AFF", secondary: "#AF52DE",
                        ok: "#248A3D", warn: "#C93400", alarm: "#D70015", calm: "#0062CC", work: "#B35500", max: "#D70015",
                        onPrimary: "#FFFFFF"))

    /// Thème de secours si `Themes.json` est absent ou illisible.
    static let fallback = AppTheme(
        id: "monitor", name: "Moniteur", scheme: "dark", font: "monospaced", radius: 4, glow: 1,
        colors: Palette(background: "#05080A", panel: "#0D1217", line: "#212E38", grid: "#121C24",
                        text: "#DEEDF5", dim: "#738794", primary: "#3DC2FF", secondary: "#AB64FA",
                        ok: "#2EE69E", warn: "#FFB021", alarm: "#FF4F4F", calm: "#3DC2FF", work: "#FF8A3D", max: "#FF4F4F",
                        onPrimary: "#000000"))
}

/// Thèmes disponibles et thème choisi (mémorisé).
final class ThemeStore: ObservableObject {
    private static let selectedKey = "theme"

    let themes: [AppTheme]
    @Published var selectedID: String {
        didSet { UserDefaults.standard.set(selectedID, forKey: Self.selectedKey) }
    }
    var current: AppTheme { themes.first { $0.id == selectedID } ?? themes[0] }

    init(bundle: Bundle = .main) {
        struct File: Decodable { let themes: [AppTheme] }
        let loaded = bundle.url(forResource: "Themes", withExtension: "json")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? JSONDecoder().decode(File.self, from: $0).themes } ?? []
        themes = loaded.isEmpty ? [.fallback] : loaded
        selectedID = UserDefaults.standard.string(forKey: Self.selectedKey) ?? themes[0].id
    }
}

/// L'échelle d'intensité (§ 5), le vert « atteint » et l'alerte, en clair et en sombre, pour le
/// thème système. Contraste mesuré sur le fond des cartes (secondarySystemGroupedBackground :
/// #FFFFFF en clair, #1C1C1E en sombre) : 4,5:1 au moins pour tous, donc lisibles en texte.
enum SystemPalette {
    static let calm = adaptive(light: "#0062CC", dark: "#64B5FF")
    static let work = adaptive(light: "#B35500", dark: "#FF9F0A")
    static let max = adaptive(light: "#D70015", dark: "#FF6961")
    static let ok = adaptive(light: "#1E7B34", dark: "#30D158")
    static let alarm = adaptive(light: "#D70015", dark: "#FF6961")

    private static func adaptive(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    /// Le mode clair ou sombre de l'iPhone, lu sur l'écran : la fenêtre porte le mode du thème
    /// du compteur, les feuilles hors compteur reprennent celui de l'iPhone.
    static var deviceScheme: ColorScheme {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        return screen?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.fallback
}

extension EnvironmentValues {
    /// Thème courant, injecté à la racine de l'app.
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension Color {
    /// « #RRGGBB ».
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }
}

extension Color {
    /// Mélange de deux couleurs (0 : self, 1 : other), pour les dégradés graduation par graduation.
    func mixed(with other: Color, by amount: Double) -> Color {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let k = CGFloat(min(max(amount, 0), 1))
        return Color(red: Double(r1 + (r2 - r1) * k), green: Double(g1 + (g2 - g1) * k),
                     blue: Double(b1 + (b2 - b1) * k), opacity: Double(a1 + (a2 - a1) * k))
    }
}

enum Format {
    /// Une évolution en symbole et en valeur sans signe : « ▲ 4 % », « ▼ 5 % », « = » sous la
    /// moitié de l'unité (le symbole porte le sens, pas de double signe).
    static func trend(_ value: Double, unit: String = "") -> String {
        let magnitude = Int(abs(value).rounded())
        guard magnitude > 0 else { return "=" }
        return "\(value > 0 ? "▲" : "▼") \(magnitude)\(unit)"
    }

    /// « 1,6 » (une décimale, à la française).
    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    /// « −29 », « +12 » : écart en %, arrondi.
    static func percent(_ value: Double) -> String {
        signed(Int(value.rounded()))
    }

    /// « jeu. » : le jour de la semaine, abrégé.
    static func shortWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated))
    }

    /// « demain », « vendredi » (dans la semaine qui vient), sinon « 12 nov. ».
    static func weekdayOrDate(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: date)).day ?? 0
        if days == 0 { return "aujourd'hui" }
        if days == 1 { return "demain" }
        if days > 1, days < 7 { return date.formatted(.dateTime.weekday(.wide)) }
        return shortDate(date)
    }

    /// « +1,2 », « −0,4 », « 0,0 » : une décimale, signée.
    static func signedDecimal(_ value: Double) -> String {
        let text = decimal(abs(value))
        return value >= 0.05 ? "+\(text)" : (value <= -0.05 ? "−\(text)" : text)
    }

    /// « +6 », « −4 », « 0 ».
    static func signed(_ value: Int) -> String {
        value > 0 ? "+\(value)" : (value < 0 ? "−\(-value)" : "0")
    }

    /// « jeudi 22 », ou « aujourd'hui ».
    static func dayName(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "aujourd'hui" : date.formatted(.dateTime.weekday(.wide).day())
    }

    /// « aujourd'hui », « demain », sinon « lundi 30 nov. ».
    static func dayDate(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(date) { return "aujourd'hui" }
        if calendar.isDateInTomorrow(date) { return "demain" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    /// « Lun. 26 oct. », première lettre en capitale.
    static func shortDay(_ date: Date) -> String {
        let text = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// « 12 oct. », ou « aujourd'hui ».
    static func shortDate(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "aujourd'hui" : date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// « 12 kg », « 7,5 kg ».
    static func kilograms(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) kg"
    }

    /// « 19:40 ».
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    /// « 38 min », « 1 h 05 ».
    static func minutes(_ seconds: TimeInterval) -> String {
        let total = Int(seconds / 60)
        return total < 60 ? "\(total) min" : String(format: "%d h %02d", total / 60, total % 60)
    }

    /// « 4:05 » ou « 1:02:07 ».
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600, minutes = (total % 3600) / 60, secs = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Composants (style moniteur, couleurs du thème courant)

/// Libellé de panneau : capitales espacées.
struct MonitorLabel: View {
    @Environment(\.theme) private var theme
    let text: String
    var color: Color?

    init(_ text: String, color: Color? = nil) {
        self.text = text
        self.color = color
    }

    var body: some View {
        if theme.isSystem {
            // Hors compteur : une étiquette en casse normale, comme Santé
            Text(symbols: text)
                .font(theme.font(15, .medium))
                .foregroundStyle(color ?? theme.dim)
                .lineLimit(1)
        } else {
            Text(symbols: text.uppercased())
                .font(theme.font(10, .semibold))
                .tracking(1.5)
                .foregroundStyle(color ?? theme.dim)
                .lineLimit(1)
        }
    }
}

/// Voyant d'état lumineux.
struct StatusLED: View {
    @Environment(\.theme) private var theme
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.9 * min(theme.glow, 1)), radius: 4 * theme.glow)
    }
}

/// Panneau à liseré fin, avec un titre et un élément optionnel à droite du titre.
struct MonitorPanel<Content: View, Accessory: View>: View {
    @Environment(\.theme) private var theme
    let title: String?
    let accessory: Accessory
    let content: Content

    init(_ title: String? = nil, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if title != nil || !(accessory is EmptyView) {
                HStack(spacing: 8) {
                    if let title { MonitorLabel(title) }
                    Spacer(minLength: 0)
                    accessory
                }
            }
            content
        }
        .padding(12)
        .cardBackground(theme)
    }
}

extension MonitorPanel where Accessory == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, accessory: { EmptyView() }, content: content)
    }
}

/// Valeur chiffrée avec son libellé (case de tableau de bord).
struct MetricTile: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    var unit: String? = nil
    var color: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonitorLabel(label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(theme.font(20, .semibold))
                    .foregroundStyle(color ?? theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(theme.font(10))
                        .foregroundStyle(theme.dim)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .cardBackground(theme)
    }
}

/// Grille de fond d'un tracé.
struct MonitorGrid: View {
    @Environment(\.theme) private var theme
    var columns = 12
    var rows = 4

    var body: some View {
        Canvas { context, size in
            var path = Path()
            for i in 1..<columns {
                let x = size.width * CGFloat(i) / CGFloat(columns)
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for i in 1..<rows {
                let y = size.height * CGFloat(i) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(theme.grid), lineWidth: 1)
        }
    }
}

/// Bouton de commande : plein (action principale) ou à liseré.
struct MonitorButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    /// Couleur du bouton ; par défaut la couleur principale du thème.
    var color: Color?
    var filled = true
    var height: CGFloat = 54
    var fontSize: CGFloat = 15
    /// Libellé long : 2 lignes plutôt qu'un texte réduit ou tronqué (grandes tailles de texte).
    var wraps = false

    func makeBody(configuration: Configuration) -> some View {
        let tint = color ?? theme.primary
        return configuration.label
            .font(theme.isSystem ? theme.font(17, .semibold) : theme.font(fontSize, .bold))
            .tracking(theme.isSystem ? 0 : (fontSize >= 14 ? 2 : 1))
            .lineLimit(wraps ? 2 : 1)
            .minimumScaleFactor(wraps ? 1 : 0.7)
            .multilineTextAlignment(.center)
            .padding(.vertical, wraps ? 6 : 0)
            .textCase(theme.isSystem ? nil : .uppercase)
            .foregroundStyle(filled ? theme.onPrimary : tint)
            .frame(maxWidth: .infinity)
            // 44 pt au moins (HIG), quelle que soit la hauteur demandée ; un libellé sur 2 lignes
            // agrandit le bouton
            .frame(minHeight: max(height, 44), maxHeight: wraps ? nil : max(height, 44))
            .background(filled ? tint : tint.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                .stroke(tint, lineWidth: filled || theme.isSystem ? 0 : 1))
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.35))
    }
}

/// Petit bouton carré d'en-tête.
struct IconButton: View {
    @Environment(\.theme) private var theme
    let systemImage: String
    var color: Color? = nil
    var highlighted = false
    let action: () -> Void

    var body: some View {
        let tint = color ?? theme.text
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? theme.onPrimary : tint)
                .frame(width: 36, height: 36)
                .background(highlighted ? tint : theme.panel,
                            in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous)
                    .stroke(highlighted ? tint : theme.line, lineWidth: 1))
                // Zone de toucher de 44 × 44 pt (HIG), le dessin reste à 36
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }
}

// MARK: - Feuilles natives

/// Une feuille hors compteur (skill reps-ux, § 11) : un `NavigationStack`, le titre natif (grand
/// titre ou en ligne), le bouton de fermeture dans la barre. Le détail s'y pousse, avec le retour
/// par glissement.
struct SheetNavigation<Content: View>: View {
    let title: String
    let display: NavigationBarItem.TitleDisplayMode
    let content: Content

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(display)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { CloseButton() }
                }
        }
    }
}

/// Fermer une feuille : xmark dans la barre de navigation.
struct CloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .fontWeight(.semibold)
        }
        .accessibilityLabel("Fermer")
    }
}

extension View {
    /// Habille une feuille d'une barre de navigation native (titre et fermeture).
    func sheetNavigation(_ title: String, display: NavigationBarItem.TitleDisplayMode = .large) -> some View {
        SheetNavigation(title: title, display: display, content: self)
    }
}

extension View {
    /// Une feuille hors compteur : le thème système et le mode clair ou sombre de l'iPhone
    /// (skill reps-ux, § 11).
    func systemSheet() -> some View {
        environment(\.theme, .system)
            .preferredColorScheme(SystemPalette.deviceScheme)
    }
}

// MARK: - Cartes

extension View {
    /// Le fond d'une carte : thème du compteur, un panneau à liseré ; thème système, une carte
    /// façon Santé (secondarySystemGroupedBackground, 12 pt d'arrondi continu, sans liseré).
    func cardBackground(_ theme: AppTheme) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
            .overlay {
                if !theme.isSystem {
                    RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1)
                }
            }
    }
}

/// L'en-tête d'une carte façon Santé : un SF Symbol et un libellé dans la couleur du domaine, un
/// complément à droite (date, verdict), un chevron si la carte s'ouvre.
struct CardHeader<Trailing: View>: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let title: String
    var color: Color?
    var opens = false
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 6) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: symbol)
            }
            .font(theme.font(15, .semibold))
            .foregroundStyle(color ?? theme.primary)
            .lineLimit(1)
            Spacer(minLength: 8)
            trailing()
            if opens {
                Image(systemName: "chevron.right")
                    .font(theme.font(13, .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension CardHeader where Trailing == EmptyView {
    init(symbol: String, title: String, color: Color? = nil, opens: Bool = false) {
        self.init(symbol: symbol, title: title, color: color, opens: opens, trailing: { EmptyView() })
    }
}
