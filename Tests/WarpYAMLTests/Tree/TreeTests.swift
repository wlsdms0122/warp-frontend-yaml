//
//  TreeTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A tree is read by its keys and its kinds")
struct TreeTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a dictionary is read under its keys, and a tree of another kind under none")
    func aDictionaryIsReadUnderItsKeys() {
        // Given
        let sut: Tree = ["procedures": ["App.g": ["const": true, "returns": "Int"]], "imports": []]

        // When
        let procedure = sut["procedures"]?["App.g"]

        // Then
        #expect(procedure?["const"]?.boolValue == true)
        #expect(procedure?["returns"]?.stringValue == "Int")
        #expect(sut["imports"]?.arrayValue == [])
        #expect(sut["imports"]?["App.g"] == nil)
        #expect(sut["types"] == nil)
    }

    @Test("a tree equals another by what it holds, wherever each came from")
    func aTreeEqualsAnotherByWhatItHolds() throws {
        // Given
        let sut = try YAMLParser().parse("rounds: [1, 2]")
        let written: Tree = ["rounds": [1, 2]]

        // When
        let made = try #require(sut["rounds"]).making(.array([1, 2, 3]))

        // Then
        #expect(sut == written)
        #expect(Set([sut, written]).count == 1)
        #expect(made.position == sut["rounds"]?.position)
        #expect(made.isImplicit)
        #expect(sut["rounds"]?.isImplicit == false)
    }

    // MARK: - Public
    // MARK: - Private
}
