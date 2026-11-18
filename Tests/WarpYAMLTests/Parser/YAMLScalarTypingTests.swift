//
//  YAMLScalarTypingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/9/26.
//

import Foundation
import Testing
@testable import WarpYAML

// Scalar typing is the parser's work alone. Nothing about procedures is under
// test here, so nothing about procedures is loaded.
@Suite("A scalar's type")
struct YAMLScalarTypingTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("plain scalars take JSON literal typing only", arguments: [
        ("value: no", Tree.string("no")),
        ("value: on", Tree.string("on")),
        ("value: \"09:20\"", Tree.string("09:20")),
        ("value: 09:20", Tree.string("09:20")),
        ("value: 007", Tree.string("007")),
        ("value: true", Tree.bool(true)),
        ("value: false", Tree.bool(false)),
        ("value: 42", Tree.int(42)),
        ("value: -7", Tree.int(-7)),
        ("value: 1.5", Tree.double(1.5)),
        ("value: \"42\"", Tree.string("42")),
        ("value: null", Tree.null),
        ("value: ~", Tree.null)
    ])
    func plainScalarsTakeJSONLiteralTypingOnly(
        yaml: String,
        expected: Tree
    ) throws {
        // Given / When
        let decoded = try object(yaml)

        // Then
        #expect(decoded["value"] == expected)
    }

    @Test("anchor aliases share the value")
    func aliasesShareValueThroughAnchor() throws {
        // Given
        let yaml = """
        base: &anchor 1
        copy: *anchor
        """

        // When
        let decoded = try object(yaml)

        // Then
        #expect(decoded["copy"] == .int(1))
    }

    @Test("numeric typing survives the YAML load", arguments: [
        ("value: 3.0", Tree.double(3.0)),
        ("value: 3.5e1", Tree.double(35.0)),
        ("value: 42", Tree.int(42))
    ])
    func numericTypingSurvivesYAMLLoad(
        yaml: String,
        expected: Tree
    ) throws {
        // Given / When. No JSON text round trip to collapse `3.0` into int
        let decoded = try object(yaml)

        // Then
        #expect(decoded["value"] == expected)
    }

    // MARK: - Public
    // MARK: - Private
    private func object(_ yaml: String) throws -> [String: Tree] {
        try #require(try YAMLParser().parse(Data(yaml.utf8)).dictionaryValue)
    }
}
