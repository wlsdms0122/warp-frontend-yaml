//
//  ElaboratorTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
import WarpYAML

// A closure standing where a procedure type is written takes what its
// signature leaves out from that type.
@Suite("A closure is completed from its slot")
struct ElaboratorTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a closure handed to the text's own procedure takes its parameter types, returns and failing")
    func anArgumentOfTheTextsOwnProcedure() throws {
        // Given
        let text = """
        name: App
        procedures:
          twice:
            parameters: [ step: "(Int) throws(aborted) -> Int", from: Int ]
            returns: Int
            failing: [ aborted ]
            body:
              - let: once
                value: { call: { procedure: { ref: step }, arguments: [ { ref: from } ] } }
            result: { call: { procedure: { ref: step }, arguments: [ { ref: once } ] } }
          entry:
            access: public
            returns: Int
            failing: [ aborted ]
            result:
              call:
                procedure: twice
                arguments:
                  - { closure: { parameters: [ n: {} ], result: { of: { ref: n }, plus: 1 } } }
                  - 5
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Numeric.plus ]
        procedures:
          App.entry:
            access: public
            returns: Int
            failing: [ aborted ]
            body:
              - value:
                  return:
                    call:
                      procedure: App.twice
                      arguments:
                        - closure:
                            parameters: [ { name: "n", type: Int } ]
                            returns: Int
                            failing: [ aborted ]
                            body:
                              - value:
                                  return:
                                    call: { procedure: Standard.Numeric.plus, arguments: [ { ref: "n" }, 1 ] }
                        - 5
          App.twice:
            parameters: [ { name: step, type: "(Int) throws(aborted) -> Int" }, { name: from, type: Int } ]
            returns: Int
            failing: [ aborted ]
            body:
              - { let: once, value: { call: { procedure: { ref: step }, arguments: [ { ref: from } ] } } }
              - { value: { return: { call: { procedure: { ref: step }, arguments: [ { ref: once } ] } } } }
        """)
    }

    @Test("a body handed to a leaned-on procedure takes the slot's marks, and the types it takes are imported")
    func aBodyHandedToALeanedOnProcedure() throws {
        // Given
        let written = """
        name: Lib
        types:
          Run: { struct: { id: String } }
        procedures:
          invoke:
            access: public
            parameters: [ body: "isolated (Lib.Run) throws -> String" ]
            returns: String
            failing: anything
            result: { call: { procedure: { ref: body }, arguments: [ { struct: { id: r1 } } ] } }
        """
        let frontend = try YAMLFrontend().leaning(on: [.text(written)])

        // When
        let document = try frontend.document(from: """
        name: App
        procedures:
          entry:
            access: public
            returns: String
            failing: anything
            result: { call: { procedure: invoke, arguments: { body: { closure: { parameters: [ run: {} ], result: { ref: run.id } } } } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.Run, Lib.invoke ]
        procedures:
          App.entry:
            access: public
            returns: String
            failing: anything
            body:
              - value:
                  return:
                    call:
                      procedure: Lib.invoke
                      arguments:
                        - closure:
                            isolated: true
                            parameters: [ { name: run, type: Lib.Run } ]
                            returns: String
                            failing: anything
                            body: [ { value: { return: { ref: run.id } } } ]
        """)
    }

    @Test("a fan-out piece writing its returns keeps them, and one leaving them is left without, for the build to refuse")
    func aFanOutPieceLeavesItsGenericReturns() throws {
        // Given
        let written = """
        procedures:
          main:
            access: public
            returns: "Dictionary<String, Int>"
            failing: [concurrent_failed]
            result:
              call:
                procedure: Standard.Concurrent.allKeyed
                arguments:
                  - dictionary:
                      - [left, { closure: { RETURNS result: 1 } }]
                      - [right, { closure: { RETURNS result: 2 } }]
        """

        // When / Then
        try expectDocument(try sut.document(from: written.replacingOccurrences(of: "RETURNS", with: "returns: Int,")), is: """
        warp: 1
        imports: [ Standard.Concurrent.allKeyed ]
        procedures:
          main:
            access: public
            returns: "Dictionary<String, Int>"
            failing: [ concurrent_failed ]
            body:
              - value:
                  return:
                    call:
                      procedure: Standard.Concurrent.allKeyed
                      arguments:
                        - dictionary:
                            - [ left, { closure: { isolated: true, returns: Int, failing: anything, body: [ { value: { return: 1 } } ] } } ]
                            - [ right, { closure: { isolated: true, returns: Int, failing: anything, body: [ { value: { return: 2 } } ] } } ]
        """)
        try expectDocument(try sut.document(from: written.replacingOccurrences(of: "RETURNS", with: "")), is: """
        warp: 1
        imports: [ Standard.Concurrent.allKeyed ]
        procedures:
          main:
            access: public
            returns: "Dictionary<String, Int>"
            failing: [ concurrent_failed ]
            body:
              - value:
                  return:
                    call:
                      procedure: Standard.Concurrent.allKeyed
                      arguments:
                        - dictionary:
                            - [ left, { closure: { isolated: true, failing: anything, body: [ { value: { return: 1 } } ] } } ]
                            - [ right, { closure: { isolated: true, failing: anything, body: [ { value: { return: 2 } } ] } } ]
        """)
    }

    @Test("a position naming the callee's type parameter is left to the closure")
    func aGenericPositionIsLeft() throws {
        // Given
        let text = """
        procedures:
          main:
            access: public
            returns: Array<Int>
            result:
              call:
                procedure: Standard.Collection.map
                arguments:
                  - [ a, b ]
                  - { closure: { parameters: [ item: {} ], returns: Int, result: 1 } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Collection.map ]
        procedures:
          main:
            access: public
            returns: "Array<Int>"
            body:
              - value:
                  return:
                    call:
                      procedure: Standard.Collection.map
                      arguments:
                        - [ a, b ]
                        - closure:
                            const: true
                            isolated: true
                            parameters: [ { name: item } ]
                            returns: Int
                            body: [ { value: { return: 1 } } ]
        """)
    }

    @Test("a closure bound by a let, a var and a module variable writing a procedure type takes it")
    func aNameWritingAProcedureType() throws {
        // Given
        let text = """
        var:
          double: { type: "(Int) -> Int", value: { closure: { parameters: [ n: {} ], result: { of: { ref: n }, times: 2 } } } }
        procedures:
          main:
            access: public
            returns: Array<Int>
            body:
              - let: add
                type: "(Int) -> Int"
                value: { closure: { parameters: [ n: {} ], result: { of: { ref: n }, plus: 1 } } }
              - var: square
                type: "(Int) -> Int"
                value: { closure: { parameters: [ n: {} ], result: { of: { ref: n }, times: { ref: n } } } }
            result:
              - { call: { procedure: { ref: add }, arguments: [ 3 ] } }
              - { call: { procedure: { ref: square }, arguments: [ 3 ] } }
              - { call: { procedure: { ref: double }, arguments: [ 3 ] } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Numeric.plus, Standard.Numeric.times ]
        var:
          double:
            type: "(Int) -> Int"
            value:
              closure:
                parameters: [ { name: "n", type: Int } ]
                returns: Int
                body:
                  - value: { return: { call: { procedure: Standard.Numeric.times, arguments: [ { ref: "n" }, 2 ] } } }
        procedures:
          main:
            access: public
            returns: "Array<Int>"
            body:
              - let: add
                type: "(Int) -> Int"
                value:
                  closure:
                    parameters: [ { name: "n", type: Int } ]
                    returns: Int
                    body:
                      - value:
                          return: { call: { procedure: Standard.Numeric.plus, arguments: [ { ref: "n" }, 1 ] } }
              - var: square
                type: "(Int) -> Int"
                value:
                  closure:
                    parameters: [ { name: "n", type: Int } ]
                    returns: Int
                    body:
                      - value:
                          return:
                            call: { procedure: Standard.Numeric.times, arguments: [ { ref: "n" }, { ref: "n" } ] }
              - value:
                  return:
                    - { call: { procedure: { ref: add }, arguments: [ 3 ] } }
                    - { call: { procedure: { ref: square }, arguments: [ 3 ] } }
                    - { call: { procedure: { ref: double }, arguments: [ 3 ] } }
        """)
    }

    @Test("a closure returned where a procedure type is returned takes it")
    func aReturnedClosure() throws {
        // Given
        let text = """
        procedures:
          adder:
            parameters: [ by: Int ]
            returns: "(Int) -> Int"
            result: { closure: { parameters: [ n: {} ], result: { of: { ref: n }, plus: { ref: by } } } }
          main:
            access: public
            returns: Array<Int>
            body:
              - let: add
                value: { call: { procedure: adder, arguments: [ 2 ] } }
            result:
              - { call: { procedure: { ref: add }, arguments: [ 3 ] } }
              - { call: { procedure: { ref: add }, arguments: [ 5 ] } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Numeric.plus ]
        procedures:
          adder:
            parameters: [ { name: by, type: Int } ]
            returns: "(Int) -> Int"
            body:
              - value:
                  return:
                    closure:
                      parameters: [ { name: "n", type: Int } ]
                      returns: Int
                      body:
                        - value:
                            return:
                              call: { procedure: Standard.Numeric.plus, arguments: [ { ref: "n" }, { ref: by } ] }
          main:
            access: public
            returns: "Array<Int>"
            body:
              - { let: add, value: { call: { procedure: adder, arguments: [ 2 ] } } }
              - value:
                  return:
                    - { call: { procedure: { ref: add }, arguments: [ 3 ] } }
                    - { call: { procedure: { ref: add }, arguments: [ 5 ] } }
        """)
    }

    @Test("a procedure-typed default written as a bare closure is completed")
    func aDefaultsClosure() throws {
        // Given
        let text = """
        name: App
        procedures:
          seven:
            access: public
            parameters: [ make: { type: "() -> Int", default: { closure: { result: 7 } } } ]
            returns: Int
            result: { call: { procedure: { ref: make } } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          App.seven:
            access: public
            parameters: [ { name: make, type: "(() -> Int)?" } ]
            returns: Int
            body:
              - let: make
                type: "() -> Int"
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: make }
                      - closure:
                          const: true
                          isolated: true
                          returns: "() -> Int"
                          body:
                            - { value: { return: { closure: { returns: Int, body: [ { value: { return: 7 } } ] } } } }
              - { value: { return: { call: { procedure: { ref: make } } } } }
        """)
    }

    @Test("what a closure writes stands, an isolated the slot does not ask included")
    func whatAClosureWritesStands() throws {
        // Given
        let text = """
        procedures:
          call:
            parameters: [ body: "() -> Int" ]
            returns: Int
            result: { call: { procedure: { ref: body } } }
          main:
            access: public
            returns: Int
            result: { call: { procedure: call, arguments: [ { closure: { isolated: true, returns: Int, result: 1 } } ] } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: []
        procedures:
          call:
            parameters: [ { name: body, type: "() -> Int" } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: { ref: body } } } } } ]
          main:
            access: public
            returns: Int
            body:
              - value:
                  return:
                    call:
                      procedure: call
                      arguments: [ { closure: { isolated: true, returns: Int, body: [ { value: { return: 1 } } ] } } ]
        """)
    }

    @Test("a closure parameter written Any stands, and one written with no type takes the slot's")
    func aParameterWrittenAnyStands() throws {
        // Given. The probe's text: `x: Any` is a type the text wrote, `x: {}`
        // leaves the type to the slot
        let text = """
        procedures:
          apply:
            parameters: [ step: "(Int) -> String?", from: Int ]
            returns: String?
          entry:
            returns: String?
            body:
              - let: written
                value: { call: { procedure: apply, arguments: [ { closure: { parameters: [ x: Any ], result: { "as?": { of: { ref: x }, type: String } } } }, 5 ] } }
              - let: left
                value: { call: { procedure: apply, arguments: [ { closure: { parameters: [ x: {} ], result: { "as?": { of: { ref: x }, type: String } } } }, 5 ] } }
            result: { ref: written }
        """

        // When
        let document = try sut.document(from: text)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          apply:
            parameters: [ { name: step, type: "(Int) -> String?" }, { name: from, type: Int } ]
            returns: "String?"
          entry:
            returns: "String?"
            body:
              - let: written
                value:
                  call:
                    procedure: apply
                    arguments:
                      - closure:
                          parameters: [ { name: x } ]
                          returns: "String?"
                          body: [ { value: { return: { "as?": { type: String, of: { ref: x } } } } } ]
                      - 5
              - let: left
                value:
                  call:
                    procedure: apply
                    arguments:
                      - closure:
                          parameters: [ { name: x, type: Int } ]
                          returns: "String?"
                          body: [ { value: { return: { "as?": { type: String, of: { ref: x } } } } } ]
                      - 5
              - { value: { return: { ref: written } } }
        """)
    }

    @Test("a closure naming fewer parameters than the slot hands is written as it is, and a place at it reads its line")
    func aCountMismatchIsTheBuilds() throws {
        // Given
        let text = """
        procedures:
          fold:
            parameters: [ step: "(Int, Int) -> Int" ]
            returns: Int
            result: { call: { procedure: { ref: step }, arguments: [ 1, 2 ] } }
          main:
            access: public
            returns: Int
            body:
              - let: folded
                value:
                  call:
                    procedure: fold
                    arguments:
                      - closure: { parameters: [ a: {} ], result: { ref: a } }
            result: { ref: folded }
        """

        // When. The build refuses the closure the call hands
        let reading = try sut.document(from: text).origin.reading(
            ["procedures", "main", "body", 0, "value", "call", "arguments", 0, "closure"]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 15)
    }

    // MARK: - Public
    // MARK: - Private
}
