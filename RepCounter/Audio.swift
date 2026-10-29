import AVFoundation

/// Retour sonore choisi dans les Réglages.
enum AudioMode: String, CaseIterable, Identifiable {
    /// Sons brefs et feutrés, aucune parole.
    case sounds
    /// Les sons, plus la voix aux paliers (5, 10, 15…) et en fin de série.
    case voice
    /// Aucun son : les vibrations restent.
    case silent

    static let key = "audioMode"
    static let defaultMode = AudioMode.sounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sounds: return "Sons"
        case .voice: return "Sons + voix"
        case .silent: return "Silence"
        }
    }

    static var saved: AudioMode {
        UserDefaults.standard.string(forKey: key).flatMap(AudioMode.init) ?? defaultMode
    }
}

/// Les sons de l'app, un par événement, reconnaissables sans regarder l'écran.
/// Fichiers RepCounter/Sounds/<rawValue>.wav, produits par Design/sound/make_sounds.py.
enum Cue: String, CaseIterable {
    /// Une note : une répétition.
    case rep
    /// Deux notes montantes : palier de 5.
    case rep5
    /// Trois notes : palier de 10.
    case rep10
    /// Note courte : 3, 2, 1.
    case count
    /// Accord : départ.
    case go
    /// Deux notes descendantes : fin de série.
    case setEnd
    /// Accord aigu : la cible de la série est atteinte.
    case target
    /// Récupération, toutes les 15 s : un battement grave (0:15), deux (0:30), trois (0:45),
    /// et un accord grave plus long à chaque minute pleine. Le cycle reprend chaque minute.
    case rest
    case rest2
    case rest3
    case restMinute
    /// Arpège : fin de séance.
    case finish

    static func forRep(_ reps: Int) -> Cue {
        reps % 10 == 0 ? .rep10 : (reps % 5 == 0 ? .rep5 : .rep)
    }
}

/// Joue les sons sans latence : fichiers chargés une fois en mémoire, plusieurs lecteurs
/// pour que deux sons rapprochés ne se coupent pas.
final class SoundPlayer {
    static let shared = SoundPlayer()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [Cue: AVAudioPCMBuffer] = [:]

    private init() {
        // Lecture même en mode silencieux, mélangée à la musique en cours
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)

        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav", subdirectory: "Sounds"),
                  let file = try? AVAudioFile(forReading: url),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
                  (try? file.read(into: buffer)) != nil else { continue }
            buffers[cue] = buffer
        }
        let format = buffers.values.first?.format ?? AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        for _ in 0..<4 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        try? engine.start()
    }

    func play(_ cue: Cue) {
        guard let buffer = buffers[cue] else { return }
        // Le moteur s'arrête lors d'une interruption audio (appel, changement d'écouteurs)
        if !engine.isRunning { try? engine.start() }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }
}

/// Retour sonore d'une séance, selon le réglage : sons, voix aux moments clés, ou rien.
/// Le réglage est relu à chaque événement : il peut changer pendant que l'écran est ouvert.
final class Announcer {
    private let synthesizer = AVSpeechSynthesizer()
    private lazy var voice = Announcer.bestVoice

    private var mode: AudioMode { .saved }

    init() {
        _ = SoundPlayer.shared   // charge les sons avant la séance
    }

    func play(_ cue: Cue) {
        guard mode != .silent else { return }
        SoundPlayer.shared.play(cue)
    }

    func say(_ text: String) {
        guard mode == .voice else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synthesizer.speak(utterance)
    }

    /// Meilleure voix française installée : Premium, sinon Améliorée, sinon la voix de base.
    static var bestVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "fr-FR" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "fr-FR")
    }

    /// Nom de la voix utilisée (« Audrey »…), seulement si elle est Améliorée ou Premium.
    static var qualityVoiceName: String? {
        hasQualityVoice ? bestVoice?.name : nil
    }

    /// Une voix de qualité (Améliorée ou Premium) est-elle installée ?
    static var hasQualityVoice: Bool {
        (bestVoice?.quality.rawValue ?? 0) > AVSpeechSynthesisVoiceQuality.default.rawValue
    }
}
