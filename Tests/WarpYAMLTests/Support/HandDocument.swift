//
//  HandDocument.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A document written by hand: YAML in the document's own shape, parsed with
// nothing spent and written as a document's bytes.
func handDocument(_ written: String) throws -> Data {
    try BinaryWriter().write(try YAMLParser().parse(written))
}

// Expects the bytes a text was spent into to be the hand document's. A
// difference is recorded with the spent tree as one flow mapping.
func expectDocument(
    _ spent: (document: Data, origin: Origin),
    is written: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    guard spent.document != (try handDocument(written)) else { return }

    Issue.record("the document written is \(HandDocument.flow(spent.origin.document))", sourceLocation: sourceLocation)
}

enum HandDocument {
    // MARK: - Public
    // A tree as one YAML flow mapping, its keys in the order of their bytes.
    static func flow(_ tree: Tree) -> String {
        switch tree.content {
        case .null:
            "null"

        case let .bool(bool):
            "\(bool)"

        case let .int(int):
            "\(int)"

        case let .double(double):
            "\(double)"

        case let .string(string):
            scalar(string)

        case let .array(elements):
            elements.isEmpty ? "[]" : "[ \(elements.map(flow).joined(separator: ", ")) ]"

        case let .dictionary(entries):
            entries.isEmpty
                ? "{}"
                : "{ \(entries.sorted { $0.key.utf8.lexicographicallyPrecedes($1.key.utf8) }.map { entry in "\(scalar(entry.key)): \(flow(entry.value))" }.joined(separator: ", ")) }"
        }
    }

    // MARK: - Private
    // A string plain where YAML reads it back as the same string, quoted
    // otherwise.
    private static func scalar(_ string: String) -> String {
        let plain = string.range(of: #"^[A-Za-z_][A-Za-z0-9_.]*$"#, options: .regularExpression) != nil
            && !["true", "false", "null", "yes", "no", "on", "off", "y", "n"].contains(string.lowercased())

        guard !plain else { return string }

        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return "\"\(escaped)\""
    }
}
