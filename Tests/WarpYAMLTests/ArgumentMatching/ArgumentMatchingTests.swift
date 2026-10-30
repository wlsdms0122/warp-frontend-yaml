//
//  ArgumentMatchingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A call's arguments written by name, handed by position")
struct ArgumentMatchingTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("named arguments are handed in the callee's order, an Optional one not named handed null")
    func namedArgumentsAreHandedInOrder() throws {
        // Given / When / Then. A call inside an argument is matched too, and a
        // call by position is left
        #expect(try matched("""
        { call: { procedure: App.greet, arguments: { times: 2, who: { call: { procedure: App.name, arguments: {} } } } } }
        """) == (try parser.parse(document(holding: """
        { call: { procedure: App.greet, arguments: [ { call: { procedure: App.name, arguments: [] } }, 2 ] } }
        """))))
        #expect(try matched("{ call: { procedure: App.greet, arguments: { who: a } } }") == (try parser.parse(document(
            holding: "{ call: { procedure: App.greet, arguments: [ a, null ] } }"
        ))))
        #expect(try matched("{ call: { procedure: App.greet, arguments: [ a ] } }") == (try parser.parse(document(
            holding: "{ call: { procedure: App.greet, arguments: [ a ] } }"
        ))))
    }

    @Test("a call by name the declarations do not fit is refused", arguments: [
        ("{ call: { procedure: App.greet, arguments: { who: a, loud: true } } }", "'App.greet' takes no 'loud'. It takes who, times", 94),
        ("{ call: { procedure: App.greet, arguments: { times: 1 } } }", "'App.greet' takes who, String, which this call does not name", 73),
        (
            "{ call: { procedure: Lib.f, arguments: { x: 1 } } }",
            "'Lib.f' is not declared by a document this text leans on, so its arguments are written by position",
            69
        ),
        ("{ call: { procedure: { ref: f }, arguments: { x: 1 } } }", "a call of a value hands its arguments by position, as a list", 74),
        ("{ call: { arguments: { x: 1 } } }", "a call writing its arguments by name names the procedure it calls", 51),
        ("{ call: { procedure: \"\", arguments: { x: 1 } } }", "a name is written, and this one is empty", 66)
    ])
    func aCallThatDoesNotFitIsRefused(written: String, message: String, column: Int) throws {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try matched(written)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: 1, column: column))
    }

    // MARK: - Public
    // MARK: - Private
    // `App.f`, whose body is one statement of `expression`.
    private func document(holding expression: String) -> String {
        "procedures: { App.f: { body: [ { value: \(expression) } ] } }"
    }

    private func matched(_ expression: String) throws -> Tree {
        let text = try parser.parse(document(holding: expression))
        let declarations = try Declarations().adding(try parser.parse("""
        procedures:
          App.greet: { parameters: [ { name: who, type: String }, { name: times, type: Int? } ] }
          App.name: { returns: String }
        """))
        return try ArgumentMatching(declarations: declarations).matched(text)
    }
}
