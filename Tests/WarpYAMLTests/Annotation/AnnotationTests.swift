//
//  AnnotationTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
import WarpYAML

// A procedure's description and a parameter's hint leave the text beside the
// document, by the names the document declares, and never inside it.
@Suite("A text's prose is handed back beside its document")
struct AnnotationTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    private static let bank = """
    name: Bank
    types:
      Account:
        struct: { cents: Int }
        procedures:
          describe:
            description: What an account says of itself.
            parameters: [ of: Account ]
            returns: String
            result: { text: { ref: of.cents } }
    extensions:
      Int:
        procedures:
          cents:
            description: An amount read as cents.
            parameters: [ of: Int ]
            returns: Int
            result: { ref: of }
    procedures:
      transfer:
        description: Moves an amount between two accounts.
        parameters:
          - from: Account
          - to: { type: Account, hint: the account credited }
          - memo: { hint: anything the statement shows }
        returns: Int
        result: { ref: from.cents }
    """

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a description is keyed by the procedure's full name, a member's and an extension's included")
    func aDescriptionIsKeyedByTheFullName() throws {
        // Given / When
        let documentation = try sut.documentation(from: Self.bank)

        // Then
        #expect(
            documentation.descriptions == [
                "Bank.transfer": "Moves an amount between two accounts.",
                "Bank.Account.describe": "What an account says of itself.",
                "Int.cents": "An amount read as cents."
            ]
        )
    }

    @Test("a hint is keyed by the procedure and the parameter it is written on")
    func aHintIsKeyedByItsParameter() throws {
        // Given / When
        let documentation = try sut.documentation(from: Self.bank)

        // Then
        #expect(
            documentation.hints == [
                "Bank.transfer": ["to": "the account credited", "memo": "anything the statement shows"]
            ]
        )
    }

    @Test("the document holds neither key, and a pair with a hint holds its type or nothing")
    func theDocumentHoldsNoProse() throws {
        // Given / When / Then
        try expectDocument(try sut.document(from: Self.bank), is: """
        warp: 1
        imports: [ Standard.Text.text ]
        types:
          Bank.Account:
            struct: { cents: Int }
            procedures:
              describe:
                parameters: [ { name: of, type: Bank.Account } ]
                returns: String
                body: [ { value: { return: { call: { procedure: Standard.Text.text, arguments: [ { ref: of.cents } ] } } } } ]
        extensions:
          Int:
            procedures:
              cents:
                parameters: [ { name: of, type: Int } ]
                returns: Int
                body: [ { value: { return: { ref: of } } } ]
        procedures:
          Bank.transfer:
            parameters: [ { name: from, type: Bank.Account }, { name: to, type: Bank.Account }, { name: memo } ]
            returns: Int
            body: [ { value: { return: { ref: from.cents } } } ]
        """)
    }

    @Test("reading the prose spends no body")
    func readingTheProseSpendsNoBody() throws {
        // Given. A body this notation cannot read
        let text = """
        procedures:
          entry:
            description: Runs.
            body:
              - value: { of: 1, plus: 2, minus: 3 }
        """

        // When
        let documentation = try sut.documentation(from: text)

        // Then
        #expect(documentation.descriptions == ["entry": "Runs."])
        #expect(throws: AuthoringError.self) { try sut.document(from: text) }
    }

    @Test("a description or a hint that is no string is refused at its key", arguments: [
        ("description: 3\n    returns: Int", 3),
        ("parameters: [ x: { type: Int, hint: [ a ] } ]", 3)
    ])
    func proseThatIsNoStringIsRefused(written: String, line: Int) {
        // Given
        let text = """
        procedures:
          entry:
            \(written)
        """

        // When / Then
        #expect {
            try sut.documentation(from: text)
        } throws: { error in
            guard let position = (error as? AuthoringError)?.position else { return false }

            return "\(error)".contains("is a string") && position.line == line
        }
    }

    @Test("a hint on a procedure and a description on a type are written as the keys they are, for the load to refuse", arguments: [
        ("procedures:\n  entry:\n    hint: no", "{ warp: 1, imports: [], procedures: { entry: { hint: \"no\" } } }"),
        ("types:\n  Card:\n    description: no\n    struct: { title: String }", "{ warp: 1, imports: [], types: { Card: { description: \"no\", struct: { title: String } } } }")
    ])
    func proseElsewhereIsWrittenThrough(text: String, written: String) throws {
        // Given / When / Then
        try expectDocument(try sut.document(from: text), is: written)
    }

    @Test("a pair holding a mapping with neither a hint nor a default is refused")
    func aPairHoldingAMappingWithNeitherAHintNorADefaultRefuses() {
        // Given
        let text = """
        procedures:
          entry:
            parameters: [ count: { type: Int } ]
        """

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut.document(from: text) }

        // Then
        #expect(refusal?.message == "a parameter written as a pair holds its type, or nothing")
        #expect(refusal?.position == Origin.Position(line: 3, column: 19))
    }
    
    // MARK: - Public
    // MARK: - Private
}
