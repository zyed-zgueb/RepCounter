import Foundation
import UIKit

/// Enregistre les mesures d'une séance pour les rejouer avec `Simulation/replay.py`.
///
/// Format JSON Lines : une ligne `meta`, puis une ligne par mesure (instant, valeurs de chaque
/// capteur, compteur de l'app), puis une ligne `end` avec le nombre de répétitions réellement
/// faites. Les 16 s qui précèdent l'appui sur ● sont incluses : tout l'historique qui influence
/// le compteur, pour que la relecture reproduise exactement l'app. Pas de vidéo : l'image n'est que la vignette 12×16 utilisée par le compteur.
/// `append` est appelé sur la file des capteurs ; `finish` une fois l'enregistreur retiré de cette file.
final class SessionRecorder {
    /// Durée maximale : au-delà, l'enregistrement s'arrête seul (~3 Mo par minute).
    static let maxDuration: TimeInterval = 10 * 60

    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Recordings", isDirectory: true)
    }

    let url: URL
    private let handle: FileHandle
    private var firstFrameTime: Double?
    private(set) var duration: TimeInterval = 0

    /// À créer sur le fil principal (lit les informations de l'appareil).
    init?(exercise: Exercise) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let directory = Self.directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        url = directory.appendingPathComponent("\(exercise.rawValue)_\(formatter.string(from: Date())).jsonl")
        guard FileManager.default.createFile(atPath: url.path, contents: nil),
              let handle = try? FileHandle(forWritingTo: url) else { return nil }
        self.handle = handle

        let meta: [String: Any] = [
            "type": "meta",
            "version": 1,
            "exercise": exercise.rawValue,
            "sources": exercise.sources.map(\.rawValue),
            "armband": Exercise.hasArmband,
            "device": Self.deviceModel(),
            "system": UIDevice.current.systemVersion,
            "app": AppVersion.version,
            "build": AppVersion.build,
            "commit": AppVersion.commit,
            "date": ISO8601DateFormatter().string(from: Date()),
        ]
        writeJSON(meta)
    }

    /// - Parameter preRoll: mesure antérieure à l'appui sur ● (ne compte pas dans la durée).
    func append(_ frame: SensorFrame, output: AutoCounter.Output, preRoll: Bool = false) {
        if !preRoll {
            if firstFrameTime == nil { firstFrameTime = frame.time }
            duration = frame.time - (firstFrameTime ?? frame.time)
        }

        var line = "{\"t\":" + String(format: "%.4f", frame.time) + ",\"v\":{"
        line += frame.values
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { source, values in
                "\"\(source.rawValue)\":[" + values.map { String(format: "%.4f", $0) }.joined(separator: ",") + "]"
            }
            .joined(separator: ",")
        line += "}"
        if !frame.extras.isEmpty {
            line += ",\"x\":{" + frame.extras
                .sorted { $0.key < $1.key }
                .map { key, values in "\"\(key)\":[" + values.map { String(format: "%.4f", $0) }.joined(separator: ",") + "]" }
                .joined(separator: ",") + "}"
        }
        line += ",\"count\":\(output.count),\"state\":\"\(output.state)\""
        if let leader = output.source { line += ",\"leader\":\"\(leader.rawValue)\"" }
        if preRoll { line += ",\"pre\":true" }
        if output.didReset { line += ",\"reset\":true" }
        line += "}\n"
        try? handle.write(contentsOf: Data(line.utf8))
    }

    /// Termine le fichier avec le résultat de la séance.
    /// - Parameter actualReps: répétitions réellement faites, si l'utilisateur l'a indiqué.
    func finish(countedReps: Int, actualReps: Int?) {
        var end: [String: Any] = ["type": "end", "countedReps": countedReps, "duration": duration]
        if let actualReps { end["actualReps"] = actualReps }
        writeJSON(end)
        try? handle.close()
    }

    private func writeJSON(_ object: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return }
        try? handle.write(contentsOf: data + Data("\n".utf8))
    }

    /// Identifiant du modèle (ex. « iPhone14,5 » pour un iPhone 13).
    private static func deviceModel() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}
