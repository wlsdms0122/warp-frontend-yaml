//
//  ElaboratorTreeTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A closure's signature, completed from the slot it stands in")
struct ElaboratorTreeTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a closure handed to a declared procedure takes its parameter types, returns, failing and marks")
    func aClosureTakesTheCalleesSlot() throws {
        // Given. A parameter written `Any` stands, and what the closure
        // writes stands
        let text = """
        procedures:
          App.f:
            body:
              - value: { call: { procedure: App.map, arguments: [ [ 1 ], { closure: { parameters: [ { name: x } ], body: [] } } ] } }
              - value: { call: { procedure: App.map, arguments: [ [ 1 ], { closure: { parameters: [ { name: x, type: Any } ], returns: Bool, body: [] } } ] } }
        """

        // When
        let completed = try self.completed(text)

        // Then
        #expect(completed == (try parser.parse("""
        procedures:
          App.f:
            body:
              - value:
                  call:
                    procedure: App.map
                    arguments:
                      - [ 1 ]
                      - closure:
                          parameters: [ { name: x, type: Int } ]
                          returns: String
                          failing: [ App.Bad ]
                          const: true
                          isolated: true
                          body: []
              - value:
                  call:
                    procedure: App.map
                    arguments:
                      - [ 1 ]
                      - closure:
                          parameters: [ { name: x, type: Any } ]
                          returns: Bool
                          failing: [ App.Bad ]
                          const: true
                          isolated: true
                          body: []
        """)))
    }

    @Test("a position naming the callee's type parameter is left to the closure")
    func aTypeParameterIsLeftToTheClosure() throws {
        // Given
        let text = """
        procedures:
          App.f:
            body:
              - value: { call: { procedure: App.apply, arguments: [ { closure: { parameters: [ { name: x } ], body: [] } } ] } }
        """

        // When
        let completed = try self.completed(text)

        // Then
        #expect(completed == (try parser.parse("""
        procedures:
          App.f:
            body:
              - value: { call: { procedure: App.apply, arguments: [ { closure: { parameters: [ { name: x } ], body: [] } } ] } }
        """)))
    }

    @Test("a closure bound by a typed let or module variable, or returned, takes the type it stands at")
    func aBoundOrReturnedClosureTakesItsType() throws {
        // Given. An array's elements, a dictionary's values and an Optional's
        // payload stand at what the slot holds there, and a closure in a
        // closure's body returns what its own closure returns
        let text = """
        var:
          handler: { type: "() -> Int", value: { closure: { body: [] } } }
        procedures:
          App.f:
            returns: "(Int) -> Int"
            body:
              - { let: g, type: "Array<(Int) -> Bool>", value: [ { closure: { parameters: [ { name: a } ], body: [] } } ] }
              - { let: d, type: "Dictionary<String, () -> Int>?", value: { dictionary: [ [ a, { closure: { body: [] } } ] ] } }
              - value:
                  conditional:
                    when: true
                    then:
                      - value: { return: { closure: { parameters: [ { name: b } ], body: [ { value: { return: { closure: { body: [] } } } } ] } } }
        """

        // When
        let completed = try self.completed(text)

        // Then
        #expect(completed == (try parser.parse("""
        var:
          handler: { type: "() -> Int", value: { closure: { returns: Int, body: [] } } }
        procedures:
          App.f:
            returns: "(Int) -> Int"
            body:
              - { let: g, type: "Array<(Int) -> Bool>", value: [ { closure: { parameters: [ { name: a, type: Int } ], returns: Bool, body: [] } } ] }
              - { let: d, type: "Dictionary<String, () -> Int>?", value: { dictionary: [ [ a, { closure: { returns: Int, body: [] } } ] ] } }
              - value:
                  conditional:
                    when: true
                    then:
                      - value:
                          return:
                            closure:
                              parameters: [ { name: b, type: Int } ]
                              returns: Int
                              body: [ { value: { return: { closure: { body: [] } } } } ]
        """)))
    }

    @Test("what the slot fills stands at the closure, made")
    func theFilledPartsStandAtTheClosure() throws {
        // Given
        let text = """
        var:
          handler: { type: "() -> Int", value: { closure: { body: [] } } }
        """

        // When
        let closure = try completed(text)["var"]?["handler"]?["value"]?["closure"]

        // Then
        #expect(closure?["returns"]?.position == closure?.position)
        #expect(closure?["returns"]?.isImplicit == true)
    }

    @Test("a connective's side takes its signature from Standard's slot")
    func aConnectivesSideTakesItsSlot() throws {
        // Given
        let side = "{ closure: { body: [ { value: { return: { ref: a } } } ] } }"
        let text = """
        procedures:
          App.f:
            body:
              - value: { call: { procedure: Standard.Logic.and, arguments: [ [ \(side) ] ] } }
              - value: { call: { procedure: Standard.Logic.tryOr, arguments: [ [ \(side) ] ] } }
        """

        // When
        let completed = try Elaborator(leaningOn: try Declarations.standard()).completed(try parser.parse(text))

        // Then
        let signature = "returns: Bool, const: true, isolated: true"
        let body = "body: [ { value: { return: { ref: a } } } ]"

        #expect(completed == (try parser.parse("""
        procedures:
          App.f:
            body:
              - value: { call: { procedure: Standard.Logic.and, arguments: [ [ { closure: { \(signature), \(body) } } ] ] } }
              - value:
                  call:
                    procedure: Standard.Logic.tryOr
                    arguments: [ [ { closure: { \(signature), failing: anything, \(body) } } ] ]
        """)))
    }

    // MARK: - Public
    // MARK: - Private
    private func completed(_ text: String) throws -> Tree {
        let declarations = try Declarations().adding(try parser.parse("""
        procedures:
          App.map:
            parameters:
              - { name: items, type: "Array<Int>" }
              - { name: f, type: "const isolated (Int) throws(App.Bad) -> String" }
          App.apply:
            parameters: [ { name: f, type: "(some T) -> some T" } ]
        """))

        return try Elaborator(leaningOn: declarations).completed(try parser.parse(text))
    }
}
