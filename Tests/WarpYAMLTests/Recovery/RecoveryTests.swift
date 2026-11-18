//
//  RecoveryTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A refused text is read again one procedure body at a time: declarations
// that do not read are refused alone, and once they read every body
// refused says why.
@Suite("Refusals recovered at each body")
struct RecoveryTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("the text with its declarations alone empties every body, and each body is read with the others empty")
    func aTextIsReadOneBodyAtATime() throws {
        // Given
        let text = try YAMLParser().parse("""
        procedures:
          first:
            body: [ { value: 1 } ]
        types:
          Box:
            struct: { held: Int }
            procedures:
              second:
                parameters: [ of: Self ]
                body: [ { value: 2 } ]
        """)

        // When
        let sut = try Recovery(of: text)

        // Then
        #expect(Self.bodies(of: sut.declarations).map(\.count) == [0, 0])
        #expect(Set(sut.bodies.map { text in Self.bodies(of: text).map(\.count) }) == [[1, 0], [0, 1]])
    }

    @Test("every body refused says why, in the order the text writes them")
    func everyBodyRefusedSaysWhy() throws {
        // Given
        let text = """
        procedures:
          pay:
            body:
              - value: { call: { procedure: nothing } }
          fine:
            body:
              - value: 1
          charge:
            body:
              - value: { of: 1, plus: 2, minus: 3 }
        """

        // When
        let refused = #expect(throws: TextRefused.self) { try frontend.document(from: text) }

        // Then
        #expect(refused?.refusals.map(\.position?.line) == [4, 10])
        #expect(refused?.refusals.first?.message == "no module the text uses declares 'nothing'")
    }

    @Test("declarations that do not read are refused alone, since every body reads them")
    func declarationsAreRefusedAlone() throws {
        // Given
        let text = """
        procedures:
          pay:
            description: 3
            body:
              - value: { call: { procedure: nothing } }
        """

        // When
        let refused = refusal { try frontend.document(from: text) }

        // Then
        #expect(refused?.message == "a description is a string")
        #expect(refused?.position == Origin.Position(line: 3, column: 5))
    }

    @Test("texts spent together each say their bodies' refusals, in the order the texts are handed")
    func textsSpentTogetherSayEachRefusal() throws {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  pay:\n    body:\n      - value: { call: { procedure: nothing } }",
            "name: Bank\nprocedures:\n  charge:\n    body:\n      - value: { call: { procedure: none } }"
        ]

        // When
        let refused = #expect(throws: TextRefused.self) { try frontend.document(from: texts) }

        // Then
        #expect(refused?.refusals.map(\.text) == [0, 1])
        #expect(refused?.refusals.map(\.position?.line) == [5, 5])
    }

    @Test("a procedure written with `result:` alone is a body, read on its own")
    func aResultIsReadAsABody() throws {
        // Given
        let text = """
        procedures:
          pay:
            result: { call: { procedure: nothing } }
          charge:
            body:
              - value: { call: { procedure: none } }
        """

        // When
        let refused = #expect(throws: TextRefused.self) { try frontend.document(from: text) }

        // Then
        #expect(refused?.refusals.map(\.position?.line) == [3, 6])
    }

    @Test("bytes that are not UTF-8 are refused as the texts are")
    func bytesThatAreNotUTF8AreRefused() {
        // When
        let refused = refusal { try frontend.document(from: Data([0xff, 0xfe, 0x00])) }

        // Then
        #expect(refused?.message == "the text is not UTF-8")
    }

    // MARK: - Public
    // MARK: - Private
    // What each procedure holds as its body, the document's before each
    // type's.
    private static func bodies(of text: Tree) -> [[Tree]] {
        let owned = text["types"]?.dictionaryValue?.values.compactMap { type in type["procedures"] } ?? []

        return ([text["procedures"]].compactMap { procedures in procedures } + owned)
            .flatMap { procedures in
                procedures.dictionaryValue?.sorted { first, second in first.key < second.key }.map(\.value) ?? []
            }
            .compactMap { procedure in procedure["body"]?.arrayValue }
    }
}
