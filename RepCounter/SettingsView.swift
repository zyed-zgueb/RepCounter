import SwiftData
import SwiftUI

/// Réglages, rangés hors de l'écran d'entraînement : mes exercices, profil, retour sonore, thème,
/// outils d'analyse.
struct SettingsView: View {
    /// Mode analyse : affiche pendant la séance l'enregistrement des mesures et le diagnostic.
    static let analysisModeKey = "analysisMode"

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var tipJar: TipJar
    @AppStorage(AudioMode.key) private var audioMode = AudioMode.defaultMode
    @AppStorage(SettingsView.analysisModeKey) private var analysisMode = false
    @AppStorage(Profile.sexKey) private var sexID = ""
    @AppStorage(Profile.birthYearKey) private var birthYear = 0
    @AppStorage(Exercise.mineKey) private var mineValue = Exercise.defaultMineValue
    @AppStorage(Exercise.armbandKey) private var hasArmband = false
    @AppStorage(WelcomeView.key) private var welcomed = false
    @AppStorage(Coach.key) private var coachStep = 0

    @State private var showsYearWheel = false
    @State private var showsExercises = false
    @State private var showsSupport = false

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
            VerticalScroll {
                VStack(spacing: 14) {
                    MonitorPanel("Mes exercices") {
                        VStack(alignment: .leading, spacing: 8) {
                            Button { showsExercises = true } label: {
                                HStack(spacing: 8) {
                                    ForEach(Exercise.decode(mineValue)) { exercise in
                                        ExerciseIcon(exercise: exercise, size: 22)
                                            .foregroundStyle(theme.primary)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(theme.dim)
                                }
                                .frame(height: 36)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mes exercices : " + Exercise.decode(mineValue).map(\.title).joined(separator: ", "))
                            Rectangle().fill(theme.line).frame(height: 1)
                                .padding(.vertical, 4)
                            Toggle(isOn: $hasArmband) {
                                Text("J'AI UN BRASSARD")
                                    .font(theme.font(14, .bold))
                                    .foregroundStyle(theme.text)
                            }
                            .tint(theme.primary)
                            note(hasArmband ? "Biceps, développé, rowing : au bras." : "Biceps, développé, rowing : à la caméra.")
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
                                .frame(maxWidth: .infinity)
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
                            note("Facultatif. Situe ton niveau en pompes.")
                        }
                    }

                    MonitorPanel("Retour sonore") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                ForEach(AudioMode.allCases) { mode in
                                    Button(mode.title) { audioMode = mode }
                                        .buttonStyle(MonitorButtonStyle(filled: audioMode == mode, height: 40, fontSize: 11))
                                }
                            }
                            if let audioNote { note(audioNote) }
                        }
                    }

                    MonitorPanel("Thème") {
                        VStack(spacing: 8) {
                            ForEach(themeStore.themes) { option in
                                ThemeRow(option: option,
                                         selected: option.id == themeStore.current.id) {
                                    themeStore.selectedID = option.id
                                }
                            }
                        }
                    }

                    MonitorPanel("Reps") {
                        VStack(alignment: .leading, spacing: 8) {
                            Button { showsSupport = true } label: {
                                HStack {
                                    Image(systemName: "cup.and.saucer.fill")
                                        .foregroundStyle(theme.warn)
                                    Text("SOUTENIR REPS")
                                        .font(theme.font(14, .bold))
                                        .foregroundStyle(theme.text)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(theme.dim)
                                }
                                .frame(height: 36)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            note("Un don ne débloque rien : c'est un merci.")
                            if SourceCode.isPublic {
                                Rectangle().fill(theme.line).frame(height: 1)
                                    .padding(.vertical, 4)
                                Link(destination: SourceCode.url) {
                                    HStack {
                                        Text("CODE SOURCE")
                                            .font(theme.font(14, .bold))
                                            .foregroundStyle(theme.text)
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(theme.dim)
                                    }
                                    .frame(height: 36)
                                    .contentShape(Rectangle())
                                }
                                note("Rien ne quitte l'iPhone : vérifiable.")
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
                            note("Enregistrement ● et diagnostic des capteurs.")
                            if analysisMode {
                                AccuracyList()
                                Rectangle().fill(theme.line).frame(height: 1)
                                    .padding(.vertical, 4)
                                Button("Revoir l'onboarding") { replayOnboarding() }
                                    .buttonStyle(MonitorButtonStyle(color: theme.primary, filled: false, height: 44, fontSize: 12))
                                note("Ton historique est conservé.")
                            }
                        }
                    }

                    VStack(spacing: 4) {
                        note("Aucune image enregistrée")
                        // Version et commit : de quoi retrouver le code d'une app donnée
                        note("Reps \(AppVersion.label)")
                            .monospacedDigit()
                            .textSelection(.enabled)
                    }
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .sheet(isPresented: $showsExercises) {
            MyExercisesView()
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
        .sheet(isPresented: $showsSupport) {
            SupportView()
                .environmentObject(tipJar)
                .environment(\.theme, theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }

    /// Repart comme au premier lancement : les Réglages se ferment, puis la bienvenue s'affiche.
    private func replayOnboarding() {
        PlacementGuide.forgetAll()
        coachStep = 0
        dismiss()
        // Après la fermeture des Réglages : la bienvenue ne peut pas s'ouvrir par-dessus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { welcomed = false }
    }

    /// Une ligne seulement quand le choix ne se comprend pas seul.
    private var audioNote: String? {
        switch audioMode {
        case .sounds: return nil
        case .voice:
            return Announcer.qualityVoiceName == nil
                ? "Voix plus naturelle : Réglages › Accessibilité › Contenu énoncé › Voix." : nil
        case .silent: return "Les vibrations restent."
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(theme.font(11))
            .foregroundStyle(theme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Mes exercices : ceux du cadran, dans l'ordre (poignée ≡ pour le changer), puis les autres
/// exercices du catalogue. − retire un exercice du cadran, + l'y ajoute ; il en reste toujours un.
private struct MyExercisesView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Exercise.mineKey) private var mineValue = Exercise.defaultMineValue

    private var mine: [Exercise] { Exercise.decode(mineValue) }
    private var others: [Exercise] { Exercise.allCases.filter { !mine.contains($0) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("MES EXERCICES")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            List {
                Section {
                    // Identifiants propres à chaque section : un exercice ajouté devient une nouvelle
                    // ligne (avec sa poignée ≡), au lieu de la ligne « Autres » déplacée, sans poignée
                    ForEach(mine, id: \.mineRowID) { exercise in
                        row(exercise, adding: false)
                    }
                    .onMove { from, to in
                        var list = mine
                        list.move(fromOffsets: from, toOffset: to)
                        mineValue = Exercise.encode(list)
                    }
                } header: {
                    MonitorLabel("Dans le cadran")
                } footer: {
                    Text("Glisse ≡ pour changer l'ordre.")
                        .font(theme.font(11))
                        .foregroundStyle(theme.dim)
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others, id: \.otherRowID) { exercise in
                            row(exercise, adding: true)
                        }
                    } header: {
                        MonitorLabel("Autres exercices")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
    }

    private func row(_ exercise: Exercise, adding: Bool) -> some View {
        let locked = !adding && mine.count == 1
        return HStack(spacing: 12) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                withAnimation {
                    mineValue = Exercise.encode(adding ? mine + [exercise] : mine.filter { $0 != exercise })
                }
            } label: {
                Image(systemName: adding ? "plus.circle.fill" : "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(adding ? theme.ok : (locked ? theme.dim.opacity(0.4) : theme.warn))
            }
            .buttonStyle(.plain)
            .disabled(locked)
            .accessibilityLabel(adding ? "Ajouter \(exercise.title)" : "Retirer \(exercise.title)")
            ExerciseIcon(exercise: exercise, size: 26)
                .foregroundStyle(adding ? theme.dim : theme.primary)
            Text(exercise.title)
                .font(theme.font(15, .semibold))
                .foregroundStyle(adding ? theme.dim : theme.text)
        }
        .padding(.vertical, 4)
        .listRowBackground(theme.panel)
    }
}

private extension Exercise {
    var mineRowID: String { "mine." + rawValue }
    var otherRowID: String { "other." + rawValue }
}

/// Précision du comptage (mode analyse) : par exercice et par mode, la part des séries exactes
/// et la précision par répétition, d'après les corrections faites en fin de séance.
private struct AccuracyList: View {
    @Environment(\.theme) private var theme
    @Query private var sessions: [SessionRecord]

    var body: some View {
        let rows = CountingAccuracy.make(sessions)
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(theme.line).frame(height: 1)
                .padding(.vertical, 4)
            MonitorLabel("Précision du comptage")
            if rows.isEmpty {
                Text("Aucune séance pour l'instant.")
                    .font(theme.font(11))
                    .foregroundStyle(theme.dim)
            }
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    ExerciseIcon(exercise: row.exercise, size: 20)
                        .foregroundStyle(theme.primary)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.exercise.shortTitle + (row.sensing == "camera" ? " · caméra" : row.sensing == "motion" ? " · mouvement" : ""))
                            .font(theme.font(13, .bold))
                            .foregroundStyle(theme.text)
                        Text("\(row.exactSets)/\(row.sets) séries exactes · \(row.missedOrExtra) erreur\(row.missedOrExtra > 1 ? "s" : "") sur \(row.reps) reps")
                            .font(theme.font(11))
                            .foregroundStyle(theme.dim)
                    }
                    Spacer(minLength: 4)
                    Text("\(Int((row.exactShare * 100).rounded())) %")
                        .font(theme.font(15, .bold))
                        .foregroundStyle(row.exactShare >= 0.95 ? theme.ok : (row.exactShare >= 0.8 ? theme.text : theme.warn))
                        .monospacedDigit()
                }
            }
            // Le gabarit personnel des abdos : ce que l'app a appris de ton geste
            let learned = LearnedGesture.load(.crunches).count
            if learned > 0 {
                Text("Geste appris (abdos) : \(learned) répétitions" + (learned < GestureTemplate.minReps
                     ? ", actif dès \(GestureTemplate.minReps)." : ", actif : les séries irrégulières sont comptées."))
                    .font(theme.font(11))
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Corrige chaque série fausse. Objectif : 95 %.")
                .font(theme.font(11))
                .foregroundStyle(theme.dim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Aperçu d'un thème : ses couleurs et son nom dans sa police.
private struct ThemeRow: View {
    @Environment(\.theme) private var theme
    let option: AppTheme
    let selected: Bool
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
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? theme.primary : theme.dim)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Défilement vertical seulement : le contenu prend la largeur de l'écran, jamais plus. Un
/// élément trop large (une roue de sélection, un texte qui ne se coupe pas) ne fait pas
/// défiler l'écran de côté. Ne rebondit que si le contenu dépasse l'écran.
struct VerticalScroll<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView(.vertical) {
            content()
                .containerRelativeFrame(.horizontal)
        }
        .bounceOnlyIfNeeded()
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
