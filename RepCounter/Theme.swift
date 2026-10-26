import SwiftUI

/// Style « moniteur » : fond quasi noir, panneaux à liseré fin sur une grille, chiffres et
/// libellés à chasse fixe, voyants d'état et tracé lumineux comme sur un écran de surveillance.
enum Theme {
    static let background = Color(red: 0.02, green: 0.03, blue: 0.04)
    static let panel = Color(red: 0.05, green: 0.07, blue: 0.09)
    static let line = Color(red: 0.13, green: 0.18, blue: 0.22)
    static let grid = Color(red: 0.07, green: 0.11, blue: 0.14)
    static let text = Color(red: 0.87, green: 0.93, blue: 0.96)
    static let dim = Color(red: 0.45, green: 0.53, blue: 0.58)
    /// Tracé principal : le bleu de l'icône.
    static let trace = Color(red: 0.24, green: 0.76, blue: 1.0)
    static let violet = Color(red: 0.67, green: 0.39, blue: 0.98)
    static let ok = Color(red: 0.18, green: 0.90, blue: 0.62)
    static let warn = Color(red: 1.0, green: 0.69, blue: 0.13)
    static let alarm = Color(red: 1.0, green: 0.31, blue: 0.31)

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
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

/// Libellé de panneau : capitales espacées, chasse fixe.
struct MonitorLabel: View {
    let text: String
    var color = Theme.dim

    init(_ text: String, color: Color = Theme.dim) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(10, .semibold))
            .tracking(1.5)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Voyant d'état lumineux.
struct StatusLED: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.9), radius: 4)
    }
}

/// Panneau à liseré fin, avec un titre et un élément optionnel à droite du titre.
struct MonitorPanel<Content: View, Accessory: View>: View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

extension MonitorPanel where Accessory == EmptyView {
    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.init(title, accessory: { EmptyView() }, content: content)
    }
}

/// Valeur chiffrée avec son libellé (case de tableau de bord).
struct MetricTile: View {
    let label: String
    let value: String
    var unit: String? = nil
    var color = Theme.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonitorLabel(label)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.mono(20, .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit)
                        .font(Theme.mono(10))
                        .foregroundStyle(Theme.dim)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// Grille de fond d'un tracé.
struct MonitorGrid: View {
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
            context.stroke(path, with: .color(Theme.grid), lineWidth: 1)
        }
    }
}

/// Bouton de commande : plein (action principale) ou à liseré.
struct MonitorButtonStyle: ButtonStyle {
    var color = Theme.trace
    var filled = true
    var height: CGFloat = 54

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.mono(15, .bold))
            .tracking(2)
            .textCase(.uppercase)
            .foregroundStyle(filled ? Color.black : color)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(filled ? color : color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(color, lineWidth: filled ? 0 : 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Petit bouton carré d'en-tête.
struct IconButton: View {
    let systemImage: String
    var color = Theme.text
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(highlighted ? Color.black : color)
                .frame(width: 36, height: 36)
                .background(highlighted ? color : Theme.panel, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(highlighted ? color : Theme.line, lineWidth: 1))
        }
    }
}
