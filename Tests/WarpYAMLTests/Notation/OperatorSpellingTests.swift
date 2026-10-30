//
//  OperatorSpellingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Testing
@testable import WarpYAML

// The operator spellings this notation offers: what a mapping is read as, and
// what is left for the load.
@Suite("The operators this notation spells")
struct OperatorSpellingTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a mapping that writes no operator is left as written for the load", arguments: [
        // A struct whose fields have an operator's or a tag's name is written
        // under `struct`, where each field is the expression it is.
        "{ struct: { count: { ref: n }, ref: { ref: n } } }",
        // A cast holds its `of` inside, never beside `as`.
        "{ as: { of: { ref: n }, type: Bool } }",
        // Several keys with no subject are no spelling.
        "{ kind: number, text: \"12\" }",
        // A tag beside a subject is the tag's, and the load refuses the pair.
        "{ ref: x, of: { ref: n } }"
    ])
    func aMappingThatWritesNoOperatorIsLeft(written: String) throws {
        // Given / When / Then
        #expect(try spent(written) == (try parser.parse(document(holding: written))))
    }

    @Test("a spelling written with a subject it does not take, or without one it needs, is refused", arguments: [
        "{ of: { ref: n }, not: { ref: n } }",
        "{ of: { ref: n }, present: { ref: n } }",
        "{ one_of: [ a ] }"
    ])
    func aSpellingOutOfShapeIsRefused(written: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try spent(written)
        }

        // Then
        #expect(error?.position != nil)
    }

    @Test("a document declaring a procedure by the name a spelling reaches does not capture it")
    func aLocalDeclarationDoesNotCaptureASpelling() throws {
        // Given / When / Then. `is` reaches `Standard.Logic.equal` by its full
        // name, so the text's own `equal` is not called.
        #expect(try spent("{ of: 1, is: 1 }", declaring: "equal: {}") == (try parser.parse(document(holding: """
        { call: { procedure: Standard.Logic.equal, arguments: [ 1, 1 ] } }
        """, declaring: "App.equal: {}"))))
    }

    @Test("what this notation says with procedures, Standard declares")
    func everyProcedureSpelledHereIsDeclared() throws {
        // Given. A spelling is spent into a procedure, and a template into two.
        let owed = Set(OperatorTable.spellings.values.map(\.procedure)).union(["Standard.Text.text", "Standard.Text.joined"])

        // When
        let declarations = try Declarations.standard()

        // Then
        #expect(owed.count > 2)
        #expect(owed.filter { procedure in declarations.signature(of: procedure) == nil }.isEmpty)
    }

    // MARK: - Public
    // MARK: - Private
    // A text named `App` declaring `declaring` beside `f`, whose body is one
    // statement of `expression`.
    private func text(holding expression: String, declaring: String = "") -> String {
        """
        name: App
        procedures: { \(declaring.isEmpty ? "" : "\(declaring), ")f: { body: [ { value: \(expression) } ] } }
        """
    }

    // The same, as the document names it.
    private func document(holding expression: String, declaring: String = "") -> String {
        """
        procedures: { \(declaring.isEmpty ? "" : "\(declaring), ")App.f: { body: [ { value: \(expression) } ] } }
        """
    }

    private func spent(_ expression: String, declaring: String = "") throws -> Tree {
        let text = try parser.parse(text(holding: expression, declaring: declaring))
        let naming = try Naming(of: text, leaningOn: try Declarations.standard())

        return try ExpressionSugar(reading: naming).spent(try naming.prefixed(text))
    }
}
