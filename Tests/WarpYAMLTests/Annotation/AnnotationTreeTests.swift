//
//  AnnotationTreeTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("The prose and the defaults a text's tree writes beside its declarations")
struct AnnotationTreeTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the keys come off a procedure and its parameters, and are kept by the procedure's full name")
    func theKeysComeOffAndAreKept() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          Lib.say:
            description: Says the words.
            parameters:
              - words: String
              - timeout: { type: Int, default: 30, hint: seconds }
              - quiet: { hint: says nothing }
            body: []
        types:
          Lib.Box:
            struct: { size: Int }
            procedures: { grown: { parameters: [ by: { type: Int, default: 1 } ] } }
        extensions:
          Card: { procedures: { describe: { description: Says what it is. } } }
        contracts:
          Lib.Named: { procedures: { name: { description: kept } } }
        """)
        let naming = try Naming(of: text, leaningOn: Declarations().adding(types: [Name("Other.Card")]))

        // When
        let sut = try Annotation(of: try naming.prefixed(text), reading: naming)

        // Then
        #expect(sut.document == (try parser.parse("""
        procedures:
          Lib.say:
            parameters: [ words: String, timeout: Int, quiet: {} ]
            body: []
        types:
          Lib.Box:
            struct: { size: Int }
            procedures: { grown: { parameters: [ by: Int ] } }
        extensions:
          Card: { procedures: { describe: {} } }
        contracts:
          Lib.Named: { procedures: { name: { description: kept } } }
        """)))
        #expect(sut.documentation.descriptions == ["Lib.say": "Says the words.", "Other.Card.describe": "Says what it is."])
        #expect(sut.documentation.hints == ["Lib.say": ["timeout": "seconds", "quiet": "says nothing"]])
        #expect(sut.defaults[[.key("procedures"), .key("Lib.say")]]?.map(\.position) == [1])
        #expect(sut.defaults[[.key("types"), .key("Lib.Box"), .key("procedures"), .key("grown")]]?.count == 1)
    }

    @Test("a default of null is refused at the default")
    func aDefaultOfNullIsRefused() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            parameters:
              - x: { type: Int?, default: null }
        """)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try Annotation(of: text, reading: .none)
        }

        // Then
        #expect(error?.message == "a default of null is what an Optional parameter left out is handed. Write 'x: T?'")
        #expect(error?.position == Origin.Position(line: 4, column: 26))
    }

    @Test("a description that is no string is refused at its key")
    func aDescriptionNoStringIsRefused() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f: { description: [ two, lines ] }
        """)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try Annotation(of: text, reading: .none)
        }

        // Then
        #expect(error?.message == "a description is a string")
        #expect(error?.position == Origin.Position(line: 2, column: 8))
    }
}
