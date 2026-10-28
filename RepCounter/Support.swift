import StoreKit
import SwiftUI
import UIKit

// MARK: - Code source

/// Le dépôt du code. Tant qu'il est privé, l'app ne renvoie pas vers lui (un lien mènerait à
/// une page introuvable) : ni lien « Code source », ni signalement par ticket GitHub, ni mention
/// « open source ». Le jour où le dépôt devient public, il suffit de passer `isPublic` à true.
enum SourceCode {
    static let isPublic = false
    static let url = URL(string: "https://github.com/zyed-zgueb/RepCounter")!
}

// MARK: - Soutien au développeur

/// Dons par achat intégré : cinq montants, du petit merci au mécénat, consommables (on peut
/// donner plusieurs fois).
/// Un don ne débloque rien : l'app est entièrement gratuite, sans pub. Créé au lancement de
/// l'app, pour clore aussi les achats terminés plus tard (validation parentale, paiement différé).
@MainActor
final class TipJar: ObservableObject {
    /// Les montants, du plus petit au plus grand. Identifiants à créer à l'identique dans App Store
    /// Connect (type consommable), aux prix indiqués ; le prix affiché vient de l'App Store.
    static let tiers: [(id: String, title: String, line: String)] = [
        ("reps.tip.thanks", "Un merci", "Un petit geste qui fait plaisir."),               // 0,99 €
        ("reps.tip.coffee", "Un café", "Pour la prochaine version."),                     // 2,99 €
        ("reps.tip.breakfast", "Un petit-déjeuner", "De quoi tenir une soirée de code."), // 5,99 €
        ("reps.tip.meal", "Un repas", "Une nouvelle fonction, financée."),                // 12,99 €
        ("reps.tip.patron", "Mécène", "Merci de faire vivre le projet.")                  // 29,99 €
    ]
    static var productIDs: [String] { tiers.map { $0.id } }

    enum Status: Equatable {
        case idle, purchasing, thanked, failed
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var status = Status.idle
    /// Le chargement des montants est terminé (réussi ou non).
    @Published private(set) var loaded = false
    private var updates: Task<Void, Never>?

    init() {
        // Achats terminés hors de l'app (validation parentale, paiement différé)
        updates = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
            }
        }
    }

    deinit { updates?.cancel() }

    /// Le merci ne s'affiche qu'une fois : on repart de zéro à la prochaine ouverture.
    func reset() {
        if status != .purchasing { status = .idle }
    }

    func load() async {
        guard products.isEmpty else { return }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
        self.loaded = true
    }

    func purchase(_ product: Product) async {
        status = .purchasing
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                status = .thanked
            case .success(.unverified(_, _)), .pending:
                status = .idle
            case .userCancelled:
                status = .idle
            @unknown default:
                status = .idle
            }
        } catch {
            status = .failed
        }
    }

    /// Nom et phrase d'un montant.
    static func wording(_ id: String) -> (title: String, line: String) {
        let tier = tiers.first { $0.id == id }
        return (tier?.title ?? "Don", tier?.line ?? "Merci !")
    }
}

/// « Soutenir Reps » : pourquoi, les montants, puis un merci. Rien d'autre.
struct SupportView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tipJar: TipJar

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SOUTENIR REPS")
                    .font(theme.font(16, .bold))
                    .tracking(3)
                    .foregroundStyle(theme.text)
                Spacer()
                IconButton(systemImage: "xmark") { dismiss() }
            }
            .padding(16)

            VerticalScroll {
                VStack(spacing: 14) {
                    MonitorPanel {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(SourceCode.isPublic ? "Gratuit, sans pub, open source." : "Gratuit, sans pub.")
                                .font(theme.font(14, .semibold))
                                .foregroundStyle(theme.text)
                            Text("Fait par une seule personne. Un don ne débloque rien : c'est un merci.")
                                .font(theme.font(12))
                                .foregroundStyle(theme.dim)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if tipJar.status == .thanked {
                        thanks
                    } else {
                        tips
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .task { await tipJar.load() }
        .onDisappear { tipJar.reset() }
    }

    @ViewBuilder
    private var tips: some View {
        if tipJar.products.isEmpty {
            MonitorLabel(tipJar.loaded ? "Dons indisponibles pour l'instant" : "Chargement…")
                .padding(.top, 8)
        } else {
            VStack(spacing: 10) {
                ForEach(tipJar.products, id: \.id) { product in
                    let wording = TipJar.wording(product.id)
                    Button {
                        Task { await tipJar.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(wording.title.uppercased())
                                    .font(theme.font(14, .bold))
                                    .foregroundStyle(theme.text)
                                Text(wording.line)
                                    .font(theme.font(11))
                                    .foregroundStyle(theme.dim)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(theme.font(15, .bold))
                                .foregroundStyle(theme.primary)
                                .monospacedDigit()
                        }
                        .padding(12)
                        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(tipJar.status == .purchasing)
                }
                if tipJar.status == .failed {
                    Text("Le paiement n'a pas abouti. Rien n'a été débité.")
                        .font(theme.font(11))
                        .foregroundStyle(theme.warn)
                }
            }
        }
    }

    private var thanks: some View {
        VStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(theme.warn)
            Text("Merci !")
                .font(theme.font(20, .bold))
                .foregroundStyle(theme.text)
            Text("Ton soutien finance la suite de Reps.")
                .font(theme.font(12))
                .foregroundStyle(theme.dim)
        }
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Moments choisis

/// Ce que l'app demande, une seule fois, et seulement après un record : d'abord une note sur
/// l'App Store (dès la 5e séance), puis un don (dès la 10e). Jamais pendant une séance, jamais
/// deux demandes à la fois.
enum Ask: Equatable {
    case review, tip

    static let reviewKey = "askedReview"
    static let tipKey = "askedTip"
    static let reviewAfterSessions = 5
    static let tipAfterSessions = 10

    static func next(sessions: Int, beatRecord: Bool, defaults: UserDefaults = .standard) -> Ask? {
        guard beatRecord else { return nil }
        if sessions >= reviewAfterSessions, !defaults.bool(forKey: reviewKey) { return .review }
        if sessions >= tipAfterSessions, !defaults.bool(forKey: tipKey) { return .tip }
        return nil
    }

    func markAsked(defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: self == .review ? Self.reviewKey : Self.tipKey)
    }
}

/// Proposition de don en fin de séance : une ligne, refusable d'une touche.
struct TipPrompt: View {
    @Environment(\.theme) private var theme
    let onSupport: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundStyle(theme.warn)
            Text("Un café pour le développeur ?")
                .font(theme.font(11))
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button("Soutenir", action: onSupport)
                .font(theme.font(12, .bold))
                .foregroundStyle(theme.primary)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(theme.dim)
            }
            .accessibilityLabel("Non merci")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(theme.panel, in: RoundedRectangle(cornerRadius: theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: theme.radius, style: .continuous).stroke(theme.line, lineWidth: 1))
    }
}

// MARK: - Signaler un comptage faux

enum CountReport {
    static let issuesURL = SourceCode.url.absoluteString + "/issues/new"

    /// Ticket GitHub pré-rempli : l'exercice, les séries (compté → réel), l'iPhone et iOS.
    /// Rien n'est envoyé par l'app : l'utilisateur relit et envoie lui-même.
    static func url(exercise: String, sets: [(counted: Int, actual: Int)]) -> URL? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let lines = sets.enumerated().map { index, set in
            "- Série \(index + 1) : comptées \(set.counted), réelles \(set.actual)"
        }
        let body = """
        **Exercice** : \(exercise)
        \(lines.joined(separator: "\n"))

        **Placement de l'iPhone** : (à plat, en poche, à la main…)
        **Ce qui s'est passé** :

        Reps \(version) · iOS \(UIDevice.current.systemVersion)
        Astuce : une capture du diagnostic (Réglages › Mode analyse) aide beaucoup.
        """
        var components = URLComponents(string: issuesURL)
        components?.queryItems = [
            URLQueryItem(name: "title", value: "Comptage faux : \(exercise)"),
            URLQueryItem(name: "body", value: body),
            URLQueryItem(name: "labels", value: "comptage")
        ]
        return components?.url
    }
}
