import Foundation
import AVFoundation

struct AudioAsset: Codable {
    let name: String
    let type: String  // "bgm" or "sfx"
    let url: String
    let version: Int
}

class AudioService: ObservableObject {
    static let shared = AudioService()

    @Published var isMusicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isMusicEnabled, forKey: "audio.musicEnabled")
            if !isMusicEnabled { stopBGM() }
        }
    }
    @Published var isSFXEnabled: Bool {
        didSet { UserDefaults.standard.set(isSFXEnabled, forKey: "audio.sfxEnabled") }
    }

    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayers: [String: AVAudioPlayer] = [:]

    private let audioDir: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("audio", isDirectory: true)
    }()

    private init() {
        isMusicEnabled = UserDefaults.standard.object(forKey: "audio.musicEnabled") as? Bool ?? true
        isSFXEnabled   = UserDefaults.standard.object(forKey: "audio.sfxEnabled")   as? Bool ?? true
        try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
    }

    // MARK: - Manifest sync

    func syncManifest() async {
        guard let assets = try? await APIService.shared.getAudioManifest() else { return }
        await downloadUpdatedAssets(assets)
    }

    private func downloadUpdatedAssets(_ assets: [AudioAsset]) async {
        var versions = UserDefaults.standard.dictionary(forKey: "audio.versions") as? [String: Int] ?? [:]

        for asset in assets {
            guard let remoteURL = URL(string: asset.url) else { continue }
            let ext = remoteURL.pathExtension.isEmpty ? "mp3" : remoteURL.pathExtension
            let fileURL = audioDir.appendingPathComponent("\(asset.name).\(ext)")
            let localVersion = versions[asset.name] ?? 0

            if localVersion < asset.version || !FileManager.default.fileExists(atPath: fileURL.path) {
                guard let (data, _) = try? await URLSession.shared.data(from: remoteURL) else { continue }
                try? data.write(to: fileURL)
                versions[asset.name] = asset.version
                print("AudioService: downloaded \(asset.name) v\(asset.version)")
            }
        }
        UserDefaults.standard.set(versions, forKey: "audio.versions")
    }

    // MARK: - Playback

    func playBGM(name: String) {
        guard isMusicEnabled else { return }
        guard let url = resolveLocalURL(name: name) else {
            print("AudioService: BGM '\(name)' not found locally")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1
            bgmPlayer?.volume = 0.35
            bgmPlayer?.play()
        } catch {
            print("AudioService: failed to play BGM '\(name)': \(error)")
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    func playSFX(name: String) {
        guard isSFXEnabled else { return }
        guard let url = resolveLocalURL(name: name) else {
            print("AudioService: SFX '\(name)' not found locally")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.7
            player.play()
            sfxPlayers[name] = player
        } catch {
            print("AudioService: failed to play SFX '\(name)': \(error)")
        }
    }

    // MARK: - Helpers

    private func resolveLocalURL(name: String) -> URL? {
        for ext in ["mp3", "caf", "wav", "m4a"] {
            let url = audioDir.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        // Fallback: bundled file
        for ext in ["mp3", "caf", "wav", "m4a"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
        }
        return nil
    }
}
