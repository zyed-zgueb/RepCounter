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
    @AppStorage(Profile.sexKey) private var sexID = ""
    @AppStorage(Profile.birthYearKey) private var birthYear = 0

    @State private var showsYearWheel = false

    /// Années proposées, des plus anciennes aux plus récentes (ordre de la roue des dates d'iOS).
    private static let birthYears: [Int] = {
        let current = Calendar.current.component(.year, from: Date())
        return Array(current - 95...current - 10)
    }()

    /// Position de départ de la roue quand aucune année n'est choisie.
    private static let defaultBirthYear = 1985

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

                    MonitorPanel("Profil") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                ForEach(Sex.allCases) { option in
                                    Button(option.title) { sexID = sexID == option.rawValue ? "" : option.rawValue }
                                        .buttonStyle(MonitorButtonStyle(filled: sexID == option.rawValue, height: 40, fontSize: 11))
                                }
                            }
                            // Année : une roue (comme les dates d'iOS), qui s'ouvre sous la ligne
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    if birthYear == 0 { birthYear = Self.defaultBirthYear }
                                    showsYearWheel.toggle()
                                }
                            } label: {
                                HStack {
                                    Text("ANNÉE DE NAISSANCE")
                                        .font(theme.font(11, .semibold))
                                        .tracking(1)
                                        .foregroundStyle(theme.text)
                                    Spacer()
                                    Text(birthYear == 0 ? "—" : String(birthYear))
                                        .font(theme.font(14, .semibold))
                                        .foregroundStyle(theme.primary)
                                        .monospacedDigit()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(theme.dim)
                                        .rotationEffect(.degrees(showsYearWheel ? 180 : 0))
                                }
                                .frame(height: 36)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if showsYearWheel {
                                Picker("Année de naissance", selection: $birthYear) {
                                    ForEach(Self.birthYears, id: \.self) { year in
                                        Text(String(year))
                                            .font(theme.font(18, .semibold))
                                            .foregroundStyle(theme.text)
                                            .tag(year)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 150)
                                .clipped()
                                HStack {
                                    Button("Effacer") {
                                        withAnimation(.easeInOut(duration: 0.25)) { birthYear = 0; showsYearWheel = false }
                                    }
                                    .foregroundStyle(theme.dim)
                                    Spacer()
                                    Button("OK") {
                                        withAnimation(.easeInOut(duration: 0.25)) { showsYearWheel = false }
                                    }
                                    .foregroundStyle(theme.primary)
                                }
                                .font(theme.font(13, .bold))
                            }
                            note("Facultatif, reste sur ton iPhone. Sert à situer ton niveau en pompes sur le barème de référence (score d'endurance).")
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
