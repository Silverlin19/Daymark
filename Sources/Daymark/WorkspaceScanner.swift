import Foundation

enum WorkspaceScanner {
    static func scan(path: String) -> [ProjectSnapshot] {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .contentModificationDateKey, .isHiddenKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return [] }

        return urls.compactMap { url -> ProjectSnapshot? in
            guard let values = try? url.resourceValues(forKeys: keys), values.isDirectory == true, values.isHidden != true else { return nil }
            let branch = gitOutput(arguments: ["-C", url.path, "branch", "--show-current"])
            let status = gitOutput(arguments: ["-C", url.path, "status", "--porcelain"])
            return ProjectSnapshot(
                name: url.lastPathComponent,
                path: url.path,
                branch: branch?.isEmpty == false ? branch : nil,
                isDirty: status?.isEmpty == false,
                lastModified: values.contentModificationDate ?? .distantPast,
                kind: projectKind(at: url)
            )
        }
        .sorted { $0.lastModified > $1.lastModified }
    }

    private static func projectKind(at url: URL) -> String {
        let manager = FileManager.default
        if manager.fileExists(atPath: url.appendingPathComponent("Package.swift").path) { return "Swift" }
        if manager.fileExists(atPath: url.appendingPathComponent("package.json").path) { return "Web" }
        if manager.fileExists(atPath: url.appendingPathComponent("pyproject.toml").path) || manager.fileExists(atPath: url.appendingPathComponent("requirements.txt").path) { return "Python" }
        if (try? manager.contentsOfDirectory(atPath: url.path).contains(where: { $0.hasSuffix(".xcodeproj") })) == true { return "Xcode" }
        return "Folder"
    }

    private static func gitOutput(arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
