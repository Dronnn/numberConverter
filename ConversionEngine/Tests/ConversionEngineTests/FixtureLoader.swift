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

    /// required string value for `key`; fails loud if the key is absent so a
    /// typo or a corrupted fixture row can never silently weaken a test.
    func string(_ key: String) -> String {
        guard let value = args[key] else {
            fatalError("fixture row \(self) is missing required key '\(key)'")
        }
        return value
    }

    /// required integer value for `key`; fails loud if the key is absent or its
    /// value is not an `Int`.
    func int(_ key: String) -> Int {
        let raw = string(key)
        guard let value = Int(raw) else {
            fatalError("fixture row \(self) has non-integer value '\(raw)' for key '\(key)'")
        }
        return value
    }

    var description: String {
        "\(op)|\(args)|\(expected)"
    }
}

// MARK: - FixtureLoader

enum FixtureLoader {
    /// loads and parses a fixture file from the test bundle's `Fixtures` folder.
    ///
    /// skips `#` comment lines and blanks. every remaining row MUST have exactly
    /// three `|`-separated fields, well-formed `key=value` arg pairs, and (when
    /// `ops` is non-empty) an op drawn from that set. anything else is a corrupted
    /// fixture and aborts the test run with a precise message — corruption can
    /// never silently weaken a suite.
    static func rows(_ name: String, ops: Set<String> = []) -> [FixtureRow] {
        guard let url = Bundle.module.url(forResource: name,
                                          withExtension: "txt",
                                          subdirectory: "Fixtures"),
              let contents = try? String(contentsOf: url, encoding: .utf8) else {
            fatalError("missing fixture \(name).txt in test bundle")
        }

        var rows: [FixtureRow] = []
        for (index, rawLine) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let lineNumber = index + 1
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") { continue }

            let parts = line.components(separatedBy: "|")
            guard parts.count == 3 else {
                fatalError("\(name).txt line \(lineNumber): expected 3 '|'-separated fields, got \(parts.count) in '\(line)'")
            }

            let op = parts[0]
            let argString = parts[1]
            let expected = parts[2]

            if op.isEmpty {
                fatalError("\(name).txt line \(lineNumber): empty op in '\(line)'")
            }
            if !ops.isEmpty, !ops.contains(op) {
                fatalError("\(name).txt line \(lineNumber): unknown op '\(op)' (expected one of \(ops.sorted()))")
            }
            if expected.isEmpty {
                fatalError("\(name).txt line \(lineNumber): empty expected value in '\(line)'")
            }

            var args: [String: String] = [:]
            if !argString.isEmpty {
                // split into key=value pairs only at commas that precede a `key=`
                // token, so a comma inside a value (e.g. `num=1,5`) is preserved.
                for pair in splitArgs(argString) {
                    guard let eq = pair.firstIndex(of: "="), eq != pair.startIndex else {
                        fatalError("\(name).txt line \(lineNumber): malformed arg pair '\(pair)' in '\(line)'")
                    }
                    let key = String(pair[pair.startIndex..<eq])
                    let value = String(pair[pair.index(after: eq)...])
                    if args[key] != nil {
                        fatalError("\(name).txt line \(lineNumber): duplicate arg key '\(key)' in '\(line)'")
                    }
                    args[key] = value
                }
            }
            rows.append(FixtureRow(op: op, args: args, expected: expected))
        }

        // a fixture that parses to no data rows (empty or all comments) would create
        // a silently-passing empty suite; fail loud so corruption can't hide.
        if rows.isEmpty {
            fatalError("\(name).txt parsed to zero data rows (empty or all comments)")
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
