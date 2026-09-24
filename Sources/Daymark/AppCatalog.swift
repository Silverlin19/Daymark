import Foundation

enum AppCatalog {
    private struct Candidate {
        let name: String
        let path: String
        let category: AppCategory
    }

    static func installedDefaults() -> [DaymarkAppLink] {
        let candidates = [
            Candidate(name: "ChatGPT", path: "/Applications/ChatGPT.app", category: .productivity),
            Candidate(name: "Pages", path: "/Applications/Pages.app", category: .productivity),
            Candidate(name: "Xcode", path: "/Applications/Xcode.app", category: .productivity),
            Candidate(name: "Visual Studio Code", path: "/Applications/Visual Studio Code.app", category: .productivity),
            Candidate(name: "Canva", path: "/Applications/Canva.app", category: .productivity),
            Candidate(name: "Spotify", path: "/Applications/Spotify.app", category: .play),
            Candidate(name: "OpenEmu", path: "/Applications/OpenEmu.app", category: .play),
            Candidate(name: "PCSX2", path: "/Applications/PCSX2-v2.8.2.app", category: .play),
            Candidate(name: "Dolphin", path: "/Applications/Dolphin.app", category: .play),
            Candidate(name: "RPCS3", path: "/Applications/RPCS3.app", category: .play),
            Candidate(name: "Prime Video", path: "/Applications/Prime Video.app", category: .play)
        ]

        return candidates.compactMap { candidate in
            guard FileManager.default.fileExists(atPath: candidate.path) else { return nil }
            return DaymarkAppLink(name: candidate.name, path: candidate.path, category: candidate.category)
        }
    }
}
