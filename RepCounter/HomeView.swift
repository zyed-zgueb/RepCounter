import SwiftUI

// Couleurs de l'icône : anneau violet (#AB64FA) vers bleu (#3DC1FE)
let ringStartColor = Color(red: 0.67, green: 0.39, blue: 0.98)
let brandColor = Color(red: 0.24, green: 0.76, blue: 1.0)
let screenBackground = Color(red: 0.07, green: 0.07, blue: 0.09)
let cardBackground = Color(red: 0.13, green: 0.13, blue: 0.16)

/// Accueil : un exercice par carte, sans caméra. Toucher une carte lance la séance.
struct HomeView: View {
    @AppStorage(WorkoutModel.announceEveryKey) private var announceEvery = 1

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(Exercise.allCases) { exercise in
                            NavigationLink(value: exercise) {
                                ExerciseCard(exercise: exercise)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    announceSetting
                }
                .padding(20)
            }
            .background(screenBackground.ignoresSafeArea())
            .navigationDestination(for: Exercise.self) { exercise in
                WorkoutView(exercise: exercise)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(brandColor)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("REPS")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .tracking(2)
                .foregroundStyle(
                    LinearGradient(colors: [ringStartColor, brandColor], startPoint: .leading, endPoint: .trailing)
                )
            Text("Quel exercice ?")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
            Text("Place le téléphone comme indiqué : il compte et annonce tes répétitions.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 12)
    }

    private var announceSetting: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Annonce vocale", systemImage: "speaker.wave.2.fill")
                .font(.headline)
                .foregroundStyle(.white)
            Picker("Annonce vocale", selection: $announceEvery) {
                Text("Chaque rep").tag(1)
                Text("Toutes les 5").tag(5)
                Text("Toutes les 10").tag(10)
            }
            .pickerStyle(.segmented)
            Text("Les répétitions non annoncées font un bip court.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ExerciseCard: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: exercise.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [ringStartColor, brandColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(height: 36)
            Text(exercise.title)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(exercise.placement)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
