//
//  FixtureLoader.swift
//  ConversionEngineTests
//
//  Created by Andreas Maier.
//  Copyright © 2026 Andreas Maier. All rights reserved.
//

@testable import ConversionEngine
import Foundation

// MARK: - FixtureRow

/// one parsed fixture line: `op|args|expected`, with `args` as comma-separated
/// `k=v` pairs. a value may itself contain a comma (e.g. `num=1,5`); pairs are
/// split only at a comma that precedes a `key=` token, so such values survive.
struct FixtureRow: Sendable, CustomStringConvertible {
    let op: String
    let args: [String: String]
    let expected: String

    func string(_ key: String) -> String { args[key] ?? "" }

    func int(_ key: String) -> Int { Int(args[key] ?? "") ?? 0 }

    var description: String {
        "\(op)|\(args)|\(expected)"
    }
}

// MARK: - FixtureLoader

enum FixtureLoader {
    /// loads and parses a fixture file from the test bundle's `Fixtures` folder.
    /// skips `#` comment lines and blanks; splits each row on `|`.
    static func rows(_ name: String) -> [FixtureRow] {
        guard let url = Bundle.module.url(forResource: name,
                                          withExtension: "txt",
                                          subdirectory: "Fixtures"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("missing fixture \(name).txt in test bundle")
        }

        var rows: [FixtureRow] = []
        for rawLine in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.components(separatedBy: "|")
            guard parts.count == 3 else { continue }

            let op = parts[0]
            let argString = parts[1]
            let expected = parts[2]

            var args: [String: String] = [:]
            if !argString.isEmpty {
                // split into key=value pairs only at commas that precede a `key=`
                // token, so a comma inside a value (e.g. `num=1,5`) is preserved.
                for pair in splitArgs(argString) {
                    guard let eq = pair.firstIndex(of: "=") else { continue }
                    let key = String(pair[pair.startIndex..<eq])
                    let value = String(pair[pair.index(after: eq)...])
                    args[key] = value
                }
            }
            rows.append(FixtureRow(op: op, args: args, expected: expected))
        }
        return rows
    }

    /// splits an argument string into `key=value` segments, breaking only at a
    /// comma that is immediately followed by a `key=` token. this preserves a
    /// comma that is part of a value (e.g. `num=1,5,base=10` -> `num=1,5` + `base=10`).
    private static func splitArgs(_ argString: String) -> [String] {
        let separator = try? Regex(",(?=[A-Za-z_][A-Za-z0-9_]*=)")
        guard let separator else { return [argString] }
        return argString.split(separator: separator).map(String.init)
    }
}

// MARK: - Engine result helpers

extension FixtureLoader {
    /// maps an `ERR:token` fixture string to a typed error, or `nil` when the
    /// expected value is an ordinary output string.
    static func error(for token: String) -> ConversionError? {
        switch token {
        case "ERR:invalidCharacter": .invalidCharacter
        case "ERR:baseOutOfRange": .baseOutOfRange
        case "ERR:divisionByZero": .divisionByZero
        default: nil
        }
    }
}

extension Result where Success == String, Failure == ConversionError {
    /// flattens a convert/calculate result into the engine's fixture token form.
    var fixtureValue: String {
        switch self {
        case let .success(value): value
        case let .failure(error): "ERR:\(error.token)"
        }
    }
}

extension ConversionError {
    var token: String {
        switch self {
        case .invalidCharacter: "invalidCharacter"
        case .baseOutOfRange: "baseOutOfRange"
        case .divisionByZero: "divisionByZero"
        }
    }
}
