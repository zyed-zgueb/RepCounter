import Accessibility
import Charts
import SwiftUI

/// Réglages communs des graphiques Swift Charts (skill reps-ux, § 11) : moins de graduations en
/// tailles d'accessibilité, et l'étiquette de la valeur choisie au doigt, en haut, comme Santé.
enum ChartKit {
    /// Nombre de graduations voulu : réduit à 3 en tailles d'accessibilité.
    static func ticks(_ size: DynamicTypeSize, regular: Int = 4) -> Int {
        size.isAccessibilitySize ? min(regular, 3) : regular
    }

    /// La règle de sélection reste dans le graphique en largeur, déborde au-dessus en hauteur.
    static let overflow = AnnotationOverflowResolution(x: .fit(to: .chart), y: .disabled)
}

/// La valeur choisie au doigt : le chiffre en gras, son contexte dessous.
struct SelectionLabel: View {
    @Environment(\.theme) private var theme
    let title: String
    var detail: String?

    var body: some View {
        VStack(spacing: 1) {
            Text(symbols: title)
                .font(theme.font(15, .bold))
                .foregroundStyle(theme.text)
                .monospacedDigit()
            if let detail {
                Text(detail)
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Une série de valeurs décrite pour les Audio Graphs de VoiceOver : les dessins qui restent hors
/// Swift Charts (cadran, frises, jauge, journal) s'écoutent comme un graphique.
struct SeriesChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    var summary: String?
    let xTitle: String
    let yTitle: String
    /// Libellés uniques, dans l'ordre, et leur valeur.
    let points: [(label: String, value: Double)]
    var unit = ""
    /// Plage fixe de l'axe des valeurs (nil : de 0 au maximum des valeurs).
    var range: ClosedRange<Double>?

    func makeChartDescriptor() -> AXChartDescriptor {
        let values = points.map(\.value)
        let low = range?.lowerBound ?? Swift.min(values.min() ?? 0, 0)
        let high = range?.upperBound ?? Swift.max(values.max() ?? 1, low + 1)
        let unit = self.unit
        let x = AXCategoricalDataAxisDescriptor(title: xTitle, categoryOrder: points.map(\.label))
        let y = AXNumericDataAxisDescriptor(title: yTitle, range: low...high, gridlinePositions: []) { value in
            "\(Int(value.rounded()))\(unit)"
        }
        let series = AXDataSeriesDescriptor(name: title, isContinuous: false,
                                            dataPoints: points.map { AXDataPoint(x: $0.label, y: $0.value) })
        return AXChartDescriptor(title: title, summary: summary, xAxis: x, yAxis: y, additionalAxes: [], series: [series])
    }
}
