//
//  NamedArgumentTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
import WarpYAML

// A call names its arguments where the symbol table holds the callee: the
// document hands them by position, in the callee's order, and an Optional
// parameter the call does not name is handed `null`.
@Suite("A call hands its arguments by name to a callee the table holds")
struct NamedArgumentTests {
    // MARK: - Property
    // A document another text leans on, one of whose parameters is Optional.
    private static let library = """
    name: Lib
    procedures:
      say:
        access: public
        parameters: [ words: Array<String>, timeout: Int? ]
        returns: String
        result: { call: { procedure: joined, arguments: { strings: { ref: words }, separator: " " } } }
    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a call to the text's own procedure hands its arguments in the callee's order")
    func aCallToTheTextsOwnIsInTheCalleesOrder() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { call: { procedure: joined, arguments: [ [ { ref: first }, { ref: second } ], "-" ] } }
          entry:
            access: public
            returns: String
            result: { call: { procedure: pair, arguments: { second: b, first: a } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Text.joined ]
        procedures:
          App.entry:
            access: public
            returns: String
            body: [ { value: { return: { call: { procedure: App.pair, arguments: [ a, b ] } } } } ]
          App.pair:
            parameters: [ { name: first, type: String }, { name: second, type: String } ]
            returns: String
            body:
              - value:
                  return:
                    call: { procedure: Standard.Text.joined, arguments: [ [ { ref: first }, { ref: second } ], "-" ] }
        """)
    }

    @Test("the arguments are written in the callee's order, whatever order the call writes them in")
    func theArgumentsRunInTheCalleesOrder() throws {
        // Given
        let sut = try YAMLFrontend()

        let document = try sut.document(from: """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            access: public
            returns: String
            failing: [aborted]
            result:
              call:
                procedure: pair
                arguments:
                  second: { abort: second }
                  first: { abort: first }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Control.abort ]
        procedures:
          App.entry:
            access: public
            returns: String
            failing: [ aborted ]
            body:
              - value:
                  return:
                    call:
                      procedure: App.pair
                      arguments:
                        - { call: { procedure: Standard.Control.abort, arguments: [ first ] } }
                        - { call: { procedure: Standard.Control.abort, arguments: [ second ] } }
          App.pair:
            parameters: [ { name: first, type: String }, { name: second, type: String } ]
            returns: String
            body: [ { value: { return: { ref: first } } } ]
        """)
    }

    @Test("a call to a leaned-on procedure hands null for an Optional it does not name")
    func anOptionalLeftOutIsHandedNull() throws {
        // Given
        let sut = try YAMLFrontend().leaning(on: [.text(Self.library)])

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          entry:
            access: public
            returns: String
            result: { call: { procedure: say, arguments: { words: [hi, there] } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.say ]
        procedures:
          App.entry:
            access: public
            returns: String
            body: [ { value: { return: { call: { procedure: Lib.say, arguments: [ [ hi, "there" ], null ] } } } } ]
        """)
    }

    @Test("std's procedures are called by their parameters' names")
    func stdIsCalledByName() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          entry:
            access: public
            returns: String
            result: { call: { procedure: Standard.Text.joined, arguments: { separator: ", ", strings: [a, b] } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Text.joined ]
        procedures:
          App.entry:
            access: public
            returns: String
            body:
              - { value: { return: { call: { procedure: Standard.Text.joined, arguments: [ [ a, b ], ", " ] } } } }
        """)
    }

    @Test("a name the callee does not declare is refused at its key, naming what it takes")
    func anUnknownNameRefuses() throws {
        // Given
        let sut = try YAMLFrontend().leaning(on: [.text(Self.library)])

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                returns: String
                result:
                  call:
                    procedure: say
                    arguments:
                      words: [hi]
                      timout: 30
            """)
        } throws: { error in
            Self.refusal(error) == "'Lib.say' takes no 'timout'. It takes words, timeout"
                && Self.line(of: error) == 9
        }
    }

    @Test("a parameter that is not Optional and that the call does not name is refused at the arguments")
    func aRequiredParameterLeftOutRefuses() throws {
        // Given
        let sut = try YAMLFrontend().leaning(on: [.text(Self.library)])

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                returns: String
                result:
                  call:
                    procedure: say
                    arguments: { timeout: 30 }
            """)
        } throws: { error in
            Self.refusal(error) == "'Lib.say' takes words, Array<String>, which this call does not name"
                && Self.line(of: error) == 7
        }
    }

    @Test("a callee the table does not hold takes its arguments by position")
    func aCalleeTheTableDoesNotHoldRefuses() throws {
        // Given
        let sut = try YAMLFrontend()

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                body:
                  - value: { call: { procedure: Host.raw.say, arguments: { words: [hi] } } }
            """)
        } throws: { error in
            Self.refusal(error)
                == "'Host.raw.say' is not declared by a document this text leans on, so its arguments are written by position"
                && Self.line(of: error) == 4
        }
    }

    @Test("a place at an argument written by name, in the callee's order, stands at its key's line")
    func aBuildRefusalStandsAtTheKey() throws {
        // Given
        let sut = try YAMLFrontend()
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            access: public
            body:
              - let: paired
                value:
                  call:
                    procedure: pair
                    arguments:
                      second: 2
                      first: a
        """

        // When. `second` is handed second, and the build refuses it
        let reading = try sut.document(from: text).origin.reading(
            ["procedures", "App.entry", "body", 0, "value", "call", "arguments", 1]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 15)
    }

    @Test("a call of a value takes its arguments by position")
    func aCallOfAValueRefusesNames() throws {
        // Given
        let sut = try YAMLFrontend()

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ f: "(Int) -> Int" ]
                returns: Int
                result: { call: { procedure: { ref: f }, arguments: { of: 1 } } }
            """)
        } throws: { error in
            Self.refusal(error) == "a call of a value hands its arguments by position, as a list"
        }
    }

    // MARK: - Public
    // MARK: - Private
    private static func refusal(_ error: any Error) -> String? {
        (error as? AuthoringError)?.message
    }

    private static func line(of error: any Error) -> Int? {
        guard let position = (error as? AuthoringError)?.position else { return nil }

        return position.line
    }
}
