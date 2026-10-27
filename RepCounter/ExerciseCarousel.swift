import SwiftUI

/// Choix de l'exercice dans le cadran, comme les cadrans d'une montre : on glisse à gauche ou
/// à droite parmi « Mes exercices », le contenu défile à l'intérieur du cadran, qui ne bouge pas. Des points indiquent
/// la position parmi les exercices ; un toucher esquisse le geste. Pas de boucle : aux deux
/// bouts, le contenu résiste puis revient.
struct ExerciseCarousel: View {
    @Environment(\.theme) private var theme
    @Binding var selection: Exercise
    /// Mes exercices, dans l'ordre choisi.
    let exercises: [Exercise]
    let side: CGFloat

    /// Déplacement du doigt en cours (pt).
    @State private var drag: CGFloat = 0

    private var index: Int { exercises.firstIndex(of: selection) ?? 0 }
    /// Distance entre deux exercices dans le défilement.
    private var page: CGFloat { side * 0.5 }

    var body: some View {
        ZStack {
            // Le disque, fixe : c'est lui qu'on touche
            Circle()
                .fill(RadialGradient(colors: [theme.primary.opacity(0.10), theme.primary.opacity(0.03)],
                                     center: .center, startRadius: 0, endRadius: side * 0.29))
                .overlay(Circle().stroke(theme.primary.opacity(0.28), lineWidth: 1))
                .frame(width: side * 0.58, height: side * 0.58)

            // Les exercices, côte à côte, masqués par un disque à l'intérieur des graduations
            ZStack {
                ForEach(Array(exercises.enumerated()), id: \.element) { i, exercise in
                    let x = CGFloat(i - index) * page + drag
                    item(exercise)
                        .offset(x: x, y: -side * 0.03)
                        .opacity(Double(max(0, 1 - abs(x) / page)))
                }
            }
            .frame(width: side * 0.76, height: side * 0.76)
            .clipShape(Circle())

            if exercises.count > 1 {
                dots
                    .offset(y: side * 0.19)
            }
        }
        .frame(width: side, height: side)
        .contentShape(Circle())
        .gesture(swipe)
        .onTapGesture(perform: hint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exercice : \(selection.title)")
        .accessibilityValue("\(index + 1) sur \(exercises.count)")
        .accessibilityHint("Balaie vers le haut ou le bas pour changer d'exercice.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: move(by: 1)
            case .decrement: move(by: -1)
            @unknown default: break
            }
        }
    }

    private func item(_ exercise: Exercise) -> some View {
        VStack(spacing: side * 0.04) {
            ExerciseIcon(exercise: exercise, size: side * 0.24)
                .foregroundStyle(theme.primary)
            Text(exercise.shortTitle.uppercased())
                .font(theme.font(15, .bold))
                .tracking(2)
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: side * 0.5)
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(exercises.indices, id: \.self) { i in
                Circle()
                    .fill(i == index ? theme.primary : theme.dim.opacity(0.45))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let t = value.translation.width
                // Aux bouts, le contenu résiste
                let atEdge = (t > 0 && index == 0) || (t < 0 && index == exercises.count - 1)
                drag = atEdge ? t * 0.25 : t
            }
            .onEnded { value in
                let t = value.translation.width, predicted = value.predictedEndTranslation.width
                var step = 0
                if t < -page * 0.25 || predicted < -page * 0.6 { step = 1 }
                if t > page * 0.25 || predicted > page * 0.6 { step = -1 }
                move(by: step)
            }
    }

    private func move(by step: Int) {
        let target = min(max(index + step, 0), exercises.count - 1)
        if target != index { UISelectionFeedbackGenerator().selectionChanged() }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            selection = exercises[target]
            drag = 0
        }
    }

    /// Un toucher : le contenu esquisse un glissement vers l'exercice voisin, puis revient.
    private func hint() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let direction: CGFloat = index == exercises.count - 1 ? 1 : -1
        withAnimation(.easeOut(duration: 0.14)) { drag = direction * page * 0.16 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { drag = 0 }
        }
    }
}
