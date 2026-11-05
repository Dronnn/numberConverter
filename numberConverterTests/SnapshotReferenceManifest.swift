//
//  SnapshotReferenceManifest.swift
//  numberConverter
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

import CryptoKit
import Foundation

enum SnapshotReferenceReviewState: String, Decodable, Sendable {
    case reviewed
    case diagnostic

    var permitsAcceptance: Bool {
        self == .reviewed
    }
}

struct SnapshotReference: Sendable {
    let fileURL: URL
    let snapshotName: String
    let reviewState: SnapshotReferenceReviewState
}

/// runtime profiles are explicit comparison policies, never file-existence fallbacks.
struct SnapshotReferenceManifest: Sendable {
    struct Entry: Decodable, Equatable, Sendable {
        let filename: String
        let sha256: String
    }

    struct Profile: Decodable, Equatable, Sendable {
        let reviewState: SnapshotReferenceReviewState
        let references: [String: Entry]
    }

    private struct Document: Decodable {
        let schemaVersion: Int
        let runtimes: [String: Profile]
    }

    private struct KeyScope {
        let isObject: Bool
        var expectsKey = true
        var keys: Set<String> = []
    }

    let runtimes: [String: Profile]
    let sha256: String

    init(data: Data) throws {
        let document = try JSONDecoder().decode(Document.self, from: data)
        try Self.rejectDuplicateKeys(in: data)
        guard document.schemaVersion == 1 else {
            throw SnapshotReferenceError.invalidManifest("Unsupported schema version: \(document.schemaVersion)")
        }
        guard let originals = document.runtimes["27.0"], !originals.references.isEmpty else {
            throw SnapshotReferenceError.invalidManifest("The complete original iOS27.0 profile is required")
        }
        guard originals.reviewState == .reviewed else {
            throw SnapshotReferenceError.invalidManifest("The original iOS27.0 profile must remain reviewed")
        }
        let logicalCases = Set(originals.references.keys)
        for (runtime, profile) in document.runtimes {
            guard runtime == "27.0" || runtime == "27.2" else {
                throw SnapshotReferenceError.unsupportedRuntime(runtime)
            }
            guard Set(profile.references.keys) == logicalCases else {
                throw SnapshotReferenceError.invalidManifest("Incomplete logical-case mapping for iOS\(runtime)")
            }
            for (logicalFilename, entry) in profile.references {
                try Self.validate(entry, for: logicalFilename, runtime: runtime)
            }
        }
        runtimes = document.runtimes
        sha256 = Self.digest(data)
    }

    init(contentsOf url: URL) throws {
        try self.init(data: Data(contentsOf: url))
    }

    func resolve(logicalFilename: String, runtime: String, directory: URL) throws -> SnapshotReference {
        guard let profile = runtimes[runtime] else {
            throw SnapshotReferenceError.unsupportedRuntime(runtime)
        }
        guard let entry = profile.references[logicalFilename] else {
            throw SnapshotReferenceError.missingCase(runtime: runtime, filename: logicalFilename)
        }
        let fileURL = directory.appendingPathComponent(entry.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw SnapshotReferenceError.missingFile(fileURL.path)
        }
        let actualHash = try Self.digest(Data(contentsOf: fileURL))
        guard actualHash == entry.sha256 else {
            throw SnapshotReferenceError.wrongHash(filename: entry.filename, expected: entry.sha256, actual: actualHash)
        }
        let snapshotName = String(entry.filename.split(separator: ".", maxSplits: 1)[1].dropLast(4))
        return SnapshotReference(fileURL: fileURL, snapshotName: snapshotName, reviewState: profile.reviewState)
    }

    static func logicalFilename(testName: String, name: String) -> String {
        "\(pathComponent(testName)).\(pathComponent(name)).png"
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func validate(_ entry: Entry, for logicalFilename: String, runtime: String) throws {
        let safeFilename = "^[A-Za-z0-9_-]+\\.[A-Za-z0-9_-]+\\.png$"
        guard logicalFilename.range(of: safeFilename, options: .regularExpression) != nil else {
            throw SnapshotReferenceError.invalidManifest("Unsafe logical filename: \(logicalFilename)")
        }
        let qualifiedFilename = String(logicalFilename.dropLast(4)) + "-ios27-2.png"
        guard entry.filename == logicalFilename || (runtime == "27.2" && entry.filename == qualifiedFilename) else {
            throw SnapshotReferenceError.invalidManifest("Unexpected reference filename: \(entry.filename)")
        }
        guard entry.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw SnapshotReferenceError.invalidManifest("Invalid SHA256 for \(entry.filename)")
        }
    }

    private static func pathComponent(_ value: String) -> String {
        value.replacingOccurrences(of: "\\W+", with: "-", options: .regularExpression)
            .replacingOccurrences(of: "^-|-$", with: "", options: .regularExpression)
    }

    /// native decoding has already validated the grammar; this only retains object keys it would discard.
    private static func rejectDuplicateKeys(in data: Data) throws {
        guard !data.contains(0), String(data: data, encoding: .utf8) != nil else {
            throw SnapshotReferenceError.invalidManifest("The manifest must use UTF8 encoding")
        }
        let bytes = Array(data)
        let stringDecoder = JSONDecoder()
        var scopes: [KeyScope] = []
        var cursor = 0
        while cursor < bytes.count {
            switch bytes[cursor] {
            case 0x7B, 0x5B:
                scopes.append(KeyScope(isObject: bytes[cursor] == 0x7B))
            case 0x7D, 0x5D:
                scopes.removeLast()
            case 0x2C:
                if scopes.last?.isObject == true {
                    scopes[scopes.count - 1].expectsKey = true
                }
            case 0x22:
                let start = cursor
                cursor = endOfString(in: bytes, startingAt: cursor)
                if let index = scopes.indices.last, scopes[index].isObject, scopes[index].expectsKey {
                    let key = try stringDecoder.decode(String.self, from: Data(bytes[start ..< cursor]))
                    guard scopes[index].keys.insert(key).inserted else {
                        throw SnapshotReferenceError.invalidManifest("Duplicate JSON object key: \(key)")
                    }
                    scopes[index].expectsKey = false
                }
                continue
            default:
                break
            }
            cursor += 1
        }
    }

    private static func endOfString(in bytes: [UInt8], startingAt start: Int) -> Int {
        var cursor = start + 1
        while cursor < bytes.count {
            if bytes[cursor] == 0x5C {
                cursor += 2
            } else if bytes[cursor] == 0x22 {
                return cursor + 1
            } else {
                cursor += 1
            }
        }
        return cursor
    }
}

enum SnapshotReferenceError: Error, Equatable, CustomStringConvertible {
    case invalidManifest(String)
    case unsupportedRuntime(String)
    case missingCase(runtime: String, filename: String)
    case missingFile(String)
    case wrongHash(filename: String, expected: String, actual: String)

    var description: String {
        switch self {
        case let .invalidManifest(reason):
            "Invalid snapshot reference manifest: \(reason)"
        case let .unsupportedRuntime(runtime):
            "No snapshot reference policy for actual iOS runtime \(runtime)"
        case let .missingCase(runtime, filename):
            "No explicit iOS\(runtime) snapshot reference mapping for \(filename)"
        case let .missingFile(path):
            "Snapshot reference file is missing: \(path)"
        case let .wrongHash(filename, expected, actual):
            "Snapshot reference SHA256 mismatch for \(filename): expected \(expected), actual \(actual)"
        }
    }
}
