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
    /// Récupération : un segment par tranche de 15 s (VoiceOver et Audio Graphs le disent).
    var rest = false

    var body: some View {
        ZStack {
            SegmentRing(lit: lit, segments: segments, color: color, goalSegment: goalSegment)
            if let live { LiveRing(live: live, pale: palePulse) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityChartDescriptor(descriptor)
    }

    private var summary: String {
        let done = min(lit, segments)
        if rest { return "Repos : \(done) tranches de 15 secondes sur \(segments)" }
        return "\(done) segments allumés sur \(segments)" + (goalSegment.map { ", objectif au segment \($0)" } ?? "")
    }

    /// Le cadran pour les Audio Graphs : un point par segment, 1 allumé, 0 éteint.
    private var descriptor: SeriesChartDescriptor {
        let count = max(segments, 1)
        let points: [(label: String, value: Double)] = (1...count).map { index in
            (label: "\(index)", value: index <= lit ? 1.0 : 0.0)
        }
        return SeriesChartDescriptor(title: rest ? "Repos, tranches de 15 s" : "Tour en cours", summary: summary,
                                     xTitle: rest ? "Tranche" : "Segment", yTitle: "Allumé", points: points, range: 0...1)
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
    /// Segments dessinés (le dernier anneau du tunnel n'a que ceux de la cible) ; nil : tous.
    var drawn: Int? = nil
    /// Épaisseur de l'anneau, en part du rayon.
    var thickness: CGFloat = 0.105

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = min(size.width, size.height) / 2 - 3
            let inner = outer * (1 - thickness)
            let gap = 0.07
            for i in 0..<min(drawn ?? segments, segments) {
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

/// Le tunnel de comptage (idée de Vincent, `Process/CYCLE.md`) : un anneau de 10 segments par
/// dizaine de la cible. Le tour en cours est devant ; les suivants sont derrière, plus petits et
/// serrés, comme au fond d'un tunnel ; le dernier n'a que les segments de la cible, qui se voit en
/// entier. À chaque dizaine faite, on avance d'un cran : l'anneau fait passe derrière soi.
/// Au-delà de la cible, un anneau vert de 10 à la fois.
struct TunnelFace: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let done: Int
    let target: Int
    let color: Color
    /// Pâle avant la validation (répétitions pas encore comptées).
    var pale = false

    /// Anneaux visibles au plus (cible jusqu'à 40) ; les plus lointains se fondent au fond.
    static let depth = 4
    /// Écart entre deux anneaux du tunnel, en part du rayon : faible (Vincent).
    static let step: CGFloat = 0.1

    var body: some View {
        let per = CounterDial.segmentsPerLap
        let laps = max(1, (target + per - 1) / per)
        // Le tour en cours : il change à la 11e, 21e… répétition (le tour plein reste affiché à 10, 20…)
        let current = max(0, done - 1) / per
        let beyond = done > target || current >= laps
        let visible = beyond ? [current] : Array(current..<min(laps, current + Self.depth))
        ZStack {
            ForEach(visible.reversed(), id: \.self) { lap in
                let rank = lap - current
                let lapDone = min(max(done - lap * per, 0), per)
                let segments = beyond || lap < laps - 1 ? per : target - (laps - 1) * per
                SegmentRing(lit: lapDone, segments: per, color: done >= target ? theme.ok : color,
                            goalSegment: nil, drawn: segments,
                            thickness: rank == 0 ? 0.105 : 0.07)
                    .opacity(rank == 0 ? 1 : (pale ? 0.35 : 0.75) - Double(rank) * 0.12)
                    .scaleEffect(1 - CGFloat(rank) * Self.step)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.25).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.85), value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) sur \(target)")
    }
}
