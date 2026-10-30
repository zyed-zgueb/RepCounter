import SwiftUI

/// Le cadran du compteur, à deux anneaux (skill reps-ux, § 4).
/// - Extérieur : il compte. Toujours 10 segments, un par répétition ; le tour repart à chaque
///   dizaine (avec les trois notes jouées toutes les 10). L'objectif de la série : sa case est
///   cerclée d'un filet sur le tour où il tombe ; atteint, l'anneau passe au vert.
/// - Intérieur : la jauge du mouvement capté en direct, pâle avant la validation.
/// En récupération, l'extérieur compte les tranches de 15 s jusqu'au repos prévu, puis passe au
/// vert : ce n'est pas une trotteuse de 60 s.
struct CounterDialFace: View {
    @Environment(\.theme) private var theme
    /// Segments allumés (0 … `segments`).
    let lit: Int
    var segments = CounterDial.segmentsPerLap
    let color: Color
    /// Segment cerclé (objectif), sur le tour en cours.
    var goalSegment: Int? = nil
    /// Mouvement capté (anneau intérieur) ; nil : pas d'anneau intérieur.
    var live: LiveSignal? = nil
    /// Anneau intérieur pâle (avant la validation, en veille).
    var palePulse = false

    var body: some View {
        ZStack {
            SegmentRing(lit: lit, segments: segments, color: color, goalSegment: goalSegment)
            if let live { LiveRing(live: live, pale: palePulse) }
        }
        .accessibilityChartDescriptor(SeriesChartDescriptor(
            title: "Tour en cours", summary: "\(min(lit, segments)) segments allumés sur \(segments)" + (goalSegment.map { ", objectif au segment \($0)" } ?? ""),
            xTitle: "Segment", yTitle: "Allumé",
            points: (1...max(segments, 1)).map { (label: "\($0)", value: $0 <= lit ? 1 : 0) }))
    }
}

enum CounterDial {
    static let segmentsPerLap = 10
    /// Rayon de l'anneau intérieur, en part du rayon du cadran.
    static let innerRadius: CGFloat = 0.67

    /// Segments allumés sur le tour en cours : 1 à 10 dès la première répétition (10 pile à
    /// chaque dizaine), 0 avant.
    static func lit(_ done: Int) -> Int {
        done <= 0 ? 0 : (done % segmentsPerLap == 0 ? segmentsPerLap : done % segmentsPerLap)
    }

    /// Case de l'objectif, cerclée sur le tour où il tombe (nil s'il tombe sur une dizaine).
    static func goalSegment(done: Int, target: Int?) -> Int? {
        guard let target, target > 0, target % segmentsPerLap != 0 else { return nil }
        let lapOfTarget = (target - 1) / segmentsPerLap
        let lapNow = max(0, done - 1) / segmentsPerLap
        return lapNow == lapOfTarget ? target % segmentsPerLap - 1 : nil
    }
}

/// L'anneau qui compte : des portions d'anneau séparées par un petit vide.
private struct SegmentRing: View {
    @Environment(\.theme) private var theme
    let lit: Int
    let segments: Int
    let color: Color
    let goalSegment: Int?

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 3
            let inner = outer * 0.895
            let gap = 0.07
            for i in 0..<segments {
                let start = Double(i) / Double(segments) * 2 * .pi - .pi / 2 + gap
                let end = Double(i + 1) / Double(segments) * 2 * .pi - .pi / 2 - gap
                var path = Path()
                path.addArc(center: center, radius: outer, startAngle: .radians(start), endAngle: .radians(end), clockwise: false)
                path.addArc(center: center, radius: inner, startAngle: .radians(end), endAngle: .radians(start), clockwise: true)
                path.closeSubpath()
                context.fill(path, with: .color(i < lit ? color : theme.line))
                if i == goalSegment, i >= lit {
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                }
            }
        }
        .shadow(color: color.opacity(lit > 0 ? 0.4 * min(theme.glow, 1) : 0), radius: 10)
        .accessibilityHidden(true)
    }
}

/// La jauge du mouvement capté (30 fois par seconde) : seul cet anneau est redessiné.
private struct LiveRing: View {
    @Environment(\.theme) private var theme
    @ObservedObject var live: LiveSignal
    let pale: Bool

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let width = side * 0.025
            ZStack {
                Circle().stroke(theme.line.opacity(0.6), lineWidth: width)
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(live.phase, 0), 1)))
                    .stroke(pale ? theme.dim.opacity(0.5) : theme.primary.opacity(0.9),
                            style: StrokeStyle(lineWidth: width, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: side * CounterDial.innerRadius, height: side * CounterDial.innerRadius)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

/// Une pastille par dizaine de l'objectif, pleine quand la dizaine est faite (vert : objectif
/// atteint). Rien au-delà de 6 dizaines : le nombre « sur N » suffit.
struct LapDots: View {
    @Environment(\.theme) private var theme
    let target: Int
    let done: Int

    var body: some View {
        let count = (target + CounterDial.segmentsPerLap - 1) / CounterDial.segmentsPerLap
        if count >= 1, count <= 6 {
            let color = done >= target ? theme.ok : theme.primary
            HStack(spacing: 5) {
                ForEach(0..<count, id: \.self) { index in
                    let full = done >= min((index + 1) * CounterDial.segmentsPerLap, target)
                    Circle()
                        .fill(full ? color : .clear)
                        .overlay(Circle().stroke(full ? color : theme.line, lineWidth: 1))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
