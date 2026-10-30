//
//  StatementSugarTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("The statement shorthands a text writes, spent into the document's spelling")
struct StatementSugarTests {
    // MARK: - Property
    private let parser = YAMLParser()
    private let sut = StatementSugar()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a return value is a last return, after the body or as the whole body")
    func aResultIsALastReturn() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            body: [ { let: x, value: 1 } ]
            result: { ref: x }
          g:
            result: { closure: { result: 2 } }
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f:
            body: [ { let: x, value: 1 }, { value: { return: { ref: x } } } ]
          g:
            body: [ { value: { return: { closure: { body: [ { value: { return: 2 } } ] } } } } ]
        """)))
    }

    @Test("a parameter pair is a name and the type it holds, and one holding nothing writes no type")
    func aPairIsANameAndAType() throws {
        // Given. `Any` written out stands, and a pair under `name` is a pair
        let text = try parser.parse("""
        procedures:
          f:
            parameters: [ count: Int, value: Any, anything: {}, name: String, { name: x, type: Int } ]
            body:
              - value: { closure: { parameters: [ y: {} ], result: { ref: y } } }
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f:
            parameters:
              - { name: count, type: Int }
              - { name: value, type: Any }
              - { name: anything }
              - { name: name, type: String }
              - { name: x, type: Int }
            body:
              - value: { closure: { parameters: [ { name: y } ], body: [ { value: { return: { ref: y } } } ] } }
        """)))
    }

    @Test("cases are the conditionals they stand for, each in the else of the one before")
    func casesAreNestedConditionals() throws {
        // Given. A case inside an arm is spent too
        let text = try parser.parse("""
        procedures:
          f:
            body:
              - value:
                  cases:
                    - { when: a, then: [ { value: 1 } ] }
                    - when: b
                      then:
                        - value: { cases: [ { when: c, then: [] } ] }
                    - { else: [ { value: 3 } ] }
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f:
            body:
              - value:
                  conditional:
                    when: a
                    then: [ { value: 1 } ]
                    else:
                      - value:
                          conditional:
                            when: b
                            then: [ { value: { conditional: { when: c, then: [] } } } ]
                            else: [ { value: 3 } ]
        """)))
    }

    @Test("cases keep the statement's name for the load to refuse")
    func casesKeepTheName() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f: { body: [ { let: x, value: { cases: [ { when: a, then: [] } ] } } ] }
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f: { body: [ { let: x, value: { conditional: { when: a, then: [] } } } ] }
        """)))
    }

    @Test("cases written out of shape are refused at the arm", arguments: [
        ("[]", "cases holds at least one case, a `when` and its `then`", 24),
        ("[ { else: [] }, { when: a, then: [] } ]", "the `else` arm comes last, and case 1 follows it", 47),
        ("[ { when: a, then: [] }, { else: [] }, { else: [] } ]", "cases holds one `else` arm", 70),
        ("[ { when: a, else: [] } ]", "a case is a `when` and its `then`, or an `else` alone", 33),
        ("[ { when: a, then: [], otherwise: [] } ]", "a case: unknown key(s) otherwise. Known keys: else, then, when", 54)
    ])
    func casesOutOfShapeAreRefused(arms: String, message: String, column: Int) throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            body: [ { value: { cases: \(arms) } } ]
        """)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.spent(text)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: 3, column: column))
    }

    @Test("each is an arm holding the array and the loop over it, the loop under the statement's name")
    func eachIsAnArmAndALoop() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            body:
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: name
                    index: at
                    body: [ { value: { ref: name } } ]
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        #expect(spent == (try parser.parse("""
        procedures:
          f:
            body:
              - value:
                  conditional:
                    when: true
                    then:
                      - { let: name, value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: name } ] } }
                            body:
                              - { let: name, value: { ref: "name[walk.index]" } }
                              - { let: at, value: { ref: walk.index } }
                              - { value: { ref: name } }
        """)))
    }

    @Test("each written out of shape is refused where it is written", arguments: [
        ("{ value: { each: { of: [], as: x, body: [] } } }", "each is named: `let: <name>` binds the round the walk reads", 15),
        ("{ set: w, value: { each: { of: [], as: x, body: [] } } }", "each is named: `let: <name>` binds the round the walk reads", 23),
        ("{ let: w, value: { each: { of: [], as: w, body: [] } } }", "each binds the walk, the element and the position under separate names, and 'w' is two of them", 48),
        ("{ let: w, value: { each: { of: [], as: a.b, body: [] } } }", "'a.b' is no name a path reads. A path is written with `.`, `[`, `]` and `?`, so a name holding one, or white space at either end, is never the one it reaches", 48),
        ("{ let: w, value: { each: { of: [], as: x } } }", "each writes `of`, `as` and `body`", 32),
        ("{ let: w, value: { each: { of: [], as: x, body: [], in: y } } }", "each: unknown key(s) in. Known keys: as, body, index, of", 65)
    ])
    func eachOutOfShapeIsRefused(statement: String, message: String, column: Int) throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            body: [ \(statement) ]
        """)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.spent(text)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: 3, column: column))
    }

    @Test("a node a shorthand makes stands where the shorthand is written, implicit")
    func aMadeNodeStandsAtItsShorthand() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          f:
            result: 1
        """)

        // When
        let spent = try sut.spent(text)

        // Then
        let returned = spent["procedures"]?["f"]?["body"]?.arrayValue?.first

        #expect(returned?.position == Origin.Position(line: 3, column: 5))
        #expect(returned?.isImplicit == true)
        #expect(returned?["value"]?["return"]?.isImplicit == false)
    }
}
