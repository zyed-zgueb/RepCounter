import SwiftUI

/// Réglages, rangés hors de l'écran d'entraînement : retour sonore, thème, outils d'analyse.
struct SettingsView: View {
    /// Mode analyse : affiche pendant la séance l'enregistrement des mesures et le diagnostic.
    static let analysisModeKey = "analysisMode"

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeStore: ThemeStore
    @AppStorage(AudioMode.key) private var audioMode = AudioMode.defaultMode
    @AppStorage(SettingsView.analysisModeKey) private var analysisMode = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RÉGLAGES")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            // Liste de réglages : défile seulement si l'écran est trop petit
            ScrollView {
                VStack(spacing: 14) {
                    MonitorPanel("Retour sonore") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(AudioMode.allCases) { mode in
                                    Button(mode.title) { audioMode = mode }
                                        .buttonStyle(MonitorButtonStyle(filled: audioMode == mode, height: 40, fontSize: 11))
                                }
                            }
                            note(audioNote)
                        }
                    }

                    MonitorPanel("Thème") {
                        VStack(spacing: 8) {
                            ForEach(themeStore.themes) { option in
                                ThemeRow(option: option,
                                         selected: option.id == themeStore.current.id,
                                         unlocked: themeStore.isUnlocked(option)) {
                                    themeStore.selectedID = option.id
                                }
                            }
                        }
                    }

                    MonitorPanel("Analyse") {
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle(isOn: $analysisMode) {
                                Text("MODE ANALYSE")
                                    .font(theme.font(14, .bold))
                                    .foregroundStyle(theme.text)
                            }
                            .tint(theme.primary)
                            note("Affiche pendant la séance l'enregistrement des mesures (●) et le diagnostic des capteurs, pour analyser une séance qui compte mal.")
                        }
                    }

                    note("Comptage par caméra 3D et capteurs de mouvement · aucune image enregistrée")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .bounceOnlyIfNeeded()
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private var audioNote: String {
        switch audioMode {
        case .sounds:
            return "Une note par répétition, deux notes tous les 5, trois tous les 10. Notes de départ, fin de série, fin de séance."
        case .voice:
            let voice = Announcer.qualityVoiceName.map { "Voix : \($0)." }
                ?? "Pour une voix plus naturelle, télécharge une voix française Améliorée ou Premium : Réglages de l'iPhone › Accessibilité › Contenu énoncé › Voix."
            return "Les sons, plus la voix aux paliers (5, 10, 15…) et en fin de série. " + voice
        case .silent:
            return "Aucun son. Les vibrations restent."
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(theme.font(11))
            .foregroundStyle(theme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Aperçu d'un thème : ses couleurs, son nom dans sa police, et son statut (inclus ou premium).
private struct ThemeRow: View {
    @Environment(\.theme) private var theme
    let option: AppTheme
    let selected: Bool
    let unlocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HStack(spacing: 0) {
                    let swatches = [option.background, option.panel, option.primary, option.secondary, option.ok]
                    ForEach(swatches.indices, id: \.self) { index in
                        Rectangle().fill(swatches[index])
                    }
                }
                .frame(width: 70, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.line, lineWidth: 1))
                Text(option.name.uppercased())
                    .font(option.font(14, .bold))
                    .foregroundStyle(theme.text)
                Spacer()
                if option.premium {
                    Label(unlocked ? "Premium" : "Verrouillé", systemImage: unlocked ? "star.fill" : "lock.fill")
                        .font(theme.font(9, .bold))
                        .foregroundStyle(theme.warn)
                }
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? theme.primary : theme.dim)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

extension View {
    /// Un défilement ne rebondit que si le contenu dépasse l'écran (iOS 16.4+).
    @ViewBuilder
    func bounceOnlyIfNeeded() -> some View {
        if #available(iOS 16.4, *) {
            scrollBounceBehavior(.basedOnSize)
        } else {
            self
        }
    }
}
