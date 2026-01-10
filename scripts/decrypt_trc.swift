#!/usr/bin/env swift
/**
 Decrypt and view .trc files for debugging FlexyMacV2
 Usage: swift decrypt_trc.swift [path_to_trc_file]

 If no path given, shows all .trc files in cache and lets you pick one.
 */

import Foundation
import Compression

// V1 compatible passwords - MUST match Configuration.swift
let INTERNAL_PASSWORD = "99C5CB2EAA4EF8C3AB722F6B320FF006022783D063DC60DE217300B6A631A91B"
let EXTERNAL_PASSWORD = "23D405A00C105E32447B3700535CE159C820825658A6989208E16A1F1797F5BB"

let CACHE_DIR = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/flexytime/cache")

// MARK: - ZIP Extraction using unzip command (simplest approach)

func extractZip(at path: URL, to destination: URL, password: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
    process.arguments = ["-P", password, "-o", path.path, "-d", destination.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    } catch {
        return false
    }
}

// MARK: - Find TRC Files

func findTrcFiles() -> [URL] {
    var files: [URL] = []

    guard let enumerator = FileManager.default.enumerator(
        at: CACHE_DIR,
        includingPropertiesForKeys: [.contentModificationDateKey],
        options: [.skipsHiddenFiles]
    ) else {
        return files
    }

    for case let url as URL in enumerator {
        if url.pathExtension == "trc" {
            files.append(url)
        }
    }

    // Sort by modification date, newest first
    return files.sorted { url1, url2 in
        let date1 = (try? url1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
        let date2 = (try? url2.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast
        return date1 > date2
    }
}

// MARK: - Decrypt TRC

func decryptTrc(at path: URL) -> [String: Any]? {
    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)

    do {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Layer 1: Extract outer ZIP
        let outerDir = tempDir.appendingPathComponent("outer")
        try FileManager.default.createDirectory(at: outerDir, withIntermediateDirectories: true)

        guard extractZip(at: path, to: outerDir, password: EXTERNAL_PASSWORD) else {
            print("Failed to extract outer ZIP (wrong password or corrupted)")
            return nil
        }

        // Find inner ZIP (it's named as SHA256 hash without extension)
        let outerContents = try FileManager.default.contentsOfDirectory(at: outerDir, includingPropertiesForKeys: nil)
        // Inner file is the SHA256 hash - no extension, but it's a ZIP file
        guard let innerZip = outerContents.first(where: { !$0.lastPathComponent.hasPrefix(".") }) else {
            print("No inner ZIP found")
            return nil
        }

        // Layer 2: Extract inner ZIP
        let innerDir = tempDir.appendingPathComponent("inner")
        try FileManager.default.createDirectory(at: innerDir, withIntermediateDirectories: true)

        guard extractZip(at: innerZip, to: innerDir, password: INTERNAL_PASSWORD) else {
            print("Failed to extract inner ZIP")
            return nil
        }

        // Find JSON file
        let innerContents = try FileManager.default.contentsOfDirectory(at: innerDir, includingPropertiesForKeys: nil)
        guard let jsonFile = innerContents.first(where: { $0.pathExtension == "json" }) else {
            print("No JSON file found")
            return nil
        }

        // Read JSON
        let jsonData = try Data(contentsOf: jsonFile)
        guard let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("Invalid JSON")
            return nil
        }

        return json

    } catch {
        print("Error: \(error.localizedDescription)")
        return nil
    }
}

// MARK: - Display

func formatViews(_ views: [[String: Any]]?) {
    guard let views = views, !views.isEmpty else {
        print("  (no views)")
        return
    }

    for (index, view) in views.enumerated() {
        let process = view["ProcessName"] as? String ?? "?"
        let title = view["Title"] as? String ?? "?"
        let time = view["Time"] as? String ?? "?"
        let expire = view["ExpireTime"] as? String ?? "?"

        let shortTitle = title.count > 50 ? String(title.prefix(50)) + "..." : title

        print("  [\(index + 1)] \(process)")
        print("      Title: \(shortTitle)")
        print("      Time: \(time) -> \(expire)")
    }
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
}

// MARK: - Main

func main() {
    var trcPath: URL

    if CommandLine.arguments.count > 1 {
        trcPath = URL(fileURLWithPath: CommandLine.arguments[1])
        guard FileManager.default.fileExists(atPath: trcPath.path) else {
            print("File not found: \(trcPath.path)")
            exit(1)
        }
    } else {
        let files = findTrcFiles()

        if files.isEmpty {
            print("No .trc files found in cache.")
            print("Cache directory: \(CACHE_DIR.path)")
            print("\nRun the app first to generate some activity data.")
            exit(0)
        }

        print("Available .trc files:\n")
        for (index, file) in files.enumerated() {
            let attrs = try? FileManager.default.attributesOfItem(atPath: file.path)
            let size = attrs?[.size] as? Int ?? 0
            let mtime = attrs?[.modificationDate] as? Date ?? Date()

            print("  [\(index + 1)] \(file.lastPathComponent) (\(size) bytes) - \(formatDate(mtime))")
        }

        print()
        print("Enter number to decrypt (or 'q' to quit): ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
            print("Invalid input")
            exit(1)
        }

        if input.lowercased() == "q" {
            exit(0)
        }

        guard let index = Int(input), index >= 1, index <= files.count else {
            print("Invalid selection")
            exit(1)
        }

        trcPath = files[index - 1]
    }

    print("\n" + String(repeating: "=", count: 60))
    print("Decrypting: \(trcPath.lastPathComponent)")
    print(String(repeating: "=", count: 60))

    guard let data = decryptTrc(at: trcPath) else {
        print("\nFailed to decrypt file")
        exit(1)
    }

    print("\nDevice Type: \(data["DeviceType"] ?? "?")")
    print("Version: \(data["Version"] ?? "?")")
    print("Username: \(data["Username"] ?? "?")")
    print("Machine Name: \(data["MachineName"] ?? "?")")
    print("IP Address: \(data["IpAddress"] ?? "?")")
    print("Data Type: \(data["DataType"] ?? "?")")
    print("Record Date: \(data["RecordDate"] ?? "?")")

    let views = data["Views"] as? [[String: Any]]
    print("\nViews (\(views?.count ?? 0)):")
    formatViews(views)

    print("\n" + String(repeating: "=", count: 60))
    print("Raw JSON:")
    print(String(repeating: "=", count: 60))

    if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
    }
}

main()
