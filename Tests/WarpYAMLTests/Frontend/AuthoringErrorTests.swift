//
//  AuthoringErrorTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/31/26.
//

import Foundation
import Testing
@testable import WarpYAML

// The refusal an author gets back from what they handed: the Front's own
// stands at the position of what it refuses, in the text it stands in.
@Suite("What the author is told")
struct AuthoringErrorTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a refusal says where it stands before what it says")
    func aRefusalSaysWhereItStands() throws {
        // Given
        let written = """
        name: Demo
        procedures:
          entry:
            description: 3
        """

        // When
        let error = #expect(throws: AuthoringError.self) {
            try frontend.document(from: written)
        }

        // Then
        #expect(error?.message == "a description is a string")
        #expect(error?.position == Origin.Position(line: 4, column: 5))
        #expect(error?.text == nil)
        #expect(error?.description == "4:5: a description is a string")
    }

    @Test("a refusal of no one spot of the text says no position")
    func aRefusalWithNoPositionSaysNone() {
        // Given
        let sut = AuthoringError("the text is refused")

        // When / Then
        #expect(sut.description == "the text is refused")
    }

    @Test("a declaration file that does not read is refused where it stands, in its place among those handed")
    func aDeclarationFileThatDoesNotReadIsRefused() {
        // Given
        let declared = Data("(interface 1)\n(procedure App.g (returns Int) (returns Int))".utf8)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try frontend.leaning(on: [.text("name: Lib"), .interface(declared)])
        }

        // Then
        #expect(error?.position == Origin.Position(line: 2, column: 32))
        #expect(error?.text == 1)
        #expect(error?.description == "text 1, 2:32: 'returns' is written twice")
    }

    @Test("a key a call names an argument by that is no name is refused at the argument")
    func aNameThatIsNoNameIsRefusedAtTheArgument() {
        // Given. The key is `e` and a combining acute accent, not in normal
        // form C. The argument stands at its key, column 56
        let written = """
        name: App
        procedures:
          pair:
            parameters: [ { first: Int } ]
          entry:
            body:
              - value: { call: { procedure: pair, arguments: { "e\u{301}": 1 } } }
        """

        // When
        let error = #expect(throws: AuthoringError.self) {
            try frontend.document(from: written)
        }

        // Then
        #expect(error?.message == "the name 'e\u{301}' is not in normal form C")
        #expect(error?.position == Origin.Position(line: 7, column: 56))
    }

    // MARK: - Public
    // MARK: - Private
}
