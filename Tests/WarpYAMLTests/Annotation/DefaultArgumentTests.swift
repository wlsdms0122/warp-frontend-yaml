//
//  DefaultArgumentTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
import WarpYAML

// A parameter's `default:` is spent at its declaration: the parameter reads
// `T?`, and the body first binds it to what it was handed or the default.
@Suite("A default is spent at the declaration")
struct DefaultArgumentTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a defaulted parameter reads Optional, and the body binds it to what it was handed or the default")
    func aDefaultIsBoundInTheBody() throws {
        // Given
        let text = """
        name: App
        procedures:
          wait:
            access: public
            parameters: [ timeout: { type: Int, default: 30 } ]
            returns: Int
            result: { ref: timeout }
          entry:
            access: public
            returns: Array<Int>
            result:
              - { call: { procedure: wait, arguments: [ null ] } }
              - { call: { procedure: wait, arguments: [ 5 ] } }
              - { call: { procedure: wait, arguments: {} } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          App.entry:
            access: public
            returns: "Array<Int>"
            body:
              - value:
                  return:
                    - { call: { procedure: App.wait, arguments: [ null ] } }
                    - { call: { procedure: App.wait, arguments: [ 5 ] } }
                    - { call: { procedure: App.wait, arguments: [ null ] } }
          App.wait:
            access: public
            parameters: [ { name: timeout, type: "Int?" } ]
            returns: Int
            body:
              - let: timeout
                type: Int
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: timeout }
                      - closure: { const: true, isolated: true, returns: Int, body: [ { value: { return: 30 } } ] }
              - { value: { return: { ref: timeout } } }
        """)
    }

    @Test("a default on an Optional parameter is taken by null, an omitted argument and a host's null alike")
    func aDefaultOnAnOptionalParameter() throws {
        // Given. A `String?` holding none, handed in a variable, is the
        // outer some and reaches the body as null.
        let text = """
        name: App
        procedures:
          label:
            access: public
            parameters: [ of: { type: String?, default: d } ]
            returns: String?
            result: { ref: of }
          entry:
            access: public
            returns: Array<String?>
            body:
              - let: none
                type: String?
                value: null
            result:
              - { call: { procedure: label, arguments: [ null ] } }
              - { call: { procedure: label, arguments: {} } }
              - { call: { procedure: label, arguments: [ { ref: none } ] } }
              - { call: { procedure: label, arguments: [ a ] } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          App.entry:
            access: public
            returns: "Array<String?>"
            body:
              - { let: none, type: "String?", value: null }
              - value:
                  return:
                    - { call: { procedure: App.label, arguments: [ null ] } }
                    - { call: { procedure: App.label, arguments: [ null ] } }
                    - { call: { procedure: App.label, arguments: [ { ref: none } ] } }
                    - { call: { procedure: App.label, arguments: [ a ] } }
          App.label:
            access: public
            parameters: [ { name: of, type: "String??" } ]
            returns: "String?"
            body:
              - let: of
                type: "String?"
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: of }
                      - closure:
                          const: true
                          isolated: true
                          returns: "String?"
                          body: [ { value: { return: d } } ]
              - { value: { return: { ref: of } } }
        """)
    }

    @Test("a default reads the parameters, an earlier defaulted one as it settled")
    func aDefaultReadsTheParameters() throws {
        // Given
        let text = """
        name: App
        procedures:
          span:
            access: public
            parameters:
              - from: Int
              - to: { type: Int, default: { of: { ref: from }, plus: 1 } }
              - step: { type: Int, default: { of: { ref: to }, minus: { ref: from } } }
            returns: Array<Int>
            result: [ { ref: from }, { ref: to }, { ref: step } ]
          entry:
            access: public
            returns: Array<Array<Int>>
            result:
              - { call: { procedure: span, arguments: { from: 2 } } }
              - { call: { procedure: span, arguments: { from: 2, to: 6 } } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Numeric.minus, Standard.Numeric.plus, Standard.Optional.unwrapped ]
        procedures:
          App.entry:
            access: public
            returns: "Array<Array<Int>>"
            body:
              - value:
                  return:
                    - { call: { procedure: App.span, arguments: [ 2, null, null ] } }
                    - { call: { procedure: App.span, arguments: [ 2, 6, null ] } }
          App.span:
            access: public
            parameters: [ { name: from, type: Int }, { name: to, type: "Int?" }, { name: step, type: "Int?" } ]
            returns: "Array<Int>"
            body:
              - let: to
                type: Int
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: to }
                      - closure:
                          const: true
                          isolated: true
                          returns: Int
                          body:
                            - value:
                                return:
                                  call: { procedure: Standard.Numeric.plus, arguments: [ { ref: from }, 1 ] }
              - let: step
                type: Int
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: step }
                      - closure:
                          const: true
                          isolated: true
                          returns: Int
                          body:
                            - value:
                                return:
                                  call:
                                    procedure: Standard.Numeric.minus
                                    arguments: [ { ref: to }, { ref: from } ]
              - { value: { return: [ { ref: from }, { ref: to }, { ref: step } ] } }
        """)
    }

    @Test("a procedure-typed default is a closure, applied through the binding's written type")
    func aProcedureTypedDefault() throws {
        // Given
        let text = """
        name: App
        procedures:
          seven:
            access: public
            parameters: [ make: { type: "() -> Int", default: { closure: { returns: Int, result: 7 } } } ]
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

    @Test("a parameter of any type writes no type on its binding")
    func anUntypedParameterWritesNoType() throws {
        // Given
        let text = """
        name: App
        procedures:
          echo:
            access: public
            parameters: [ of: { default: x } ]
            returns: Any
            result: { ref: of }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          App.echo:
            access: public
            parameters: [ { name: of, type: "Any?" } ]
            returns: Any
            body:
              - let: of
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: of }
                      - { closure: { const: true, isolated: true, returns: Any, body: [ { value: { return: x } } ] } }
              - { value: { return: { ref: of } } }
        """)
    }

    @Test("an empty mapping as a default is an empty dictionary")
    func anEmptyMappingDefaultIsAnEmptyDictionary() throws {
        // Given
        let text = """
        name: App
        procedures:
          run:
            access: public
            parameters: [ env: { type: "Dictionary<String, String>", default: {} } ]
            returns: "Dictionary<String, String>"
            result: { ref: env }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          App.run:
            access: public
            parameters: [ { name: env, type: "Dictionary<String, String>?" } ]
            returns: "Dictionary<String, String>"
            body:
              - let: env
                type: "Dictionary<String, String>"
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: env }
                      - closure:
                          const: true
                          isolated: true
                          returns: "Dictionary<String, String>"
                          body: [ { value: { return: { dictionary: [] } } } ]
              - { value: { return: { ref: env } } }
        """)
    }

    @Test("a member of a type and one an extension gives spend their defaults alike")
    func aMembersDefaultIsSpent() throws {
        // Given
        let text = """
        name: App
        types:
          Card:
            struct: { title: String }
            procedures:
              label:
                parameters: [ of: Card, mark: { type: String, default: "*" } ]
                returns: String
                result: { format: "${m}${t}", with: { m: { ref: mark }, t: { ref: of.title } } }
        extensions:
          Int:
            procedures:
              scaled:
                parameters: [ of: Int, by: { type: Int, default: 10 } ]
                returns: Int
                result: { of: { ref: of }, times: { ref: by } }
        procedures:
          entry:
            access: public
            returns: Array<Any>
            failing: [cast_refused]
            result:
              - { call: { procedure: Card.label, arguments: { of: { as: { of: { struct: { title: a } }, type: Card } } } } }
              - { call: { procedure: Int.scaled, arguments: { of: 4 } } }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: [ Standard.Numeric.times, Standard.Optional.unwrapped, Standard.Text.joined, Standard.Text.text ]
        types:
          App.Card:
            procedures:
              label:
                parameters: [ { name: of, type: App.Card }, { name: mark, type: "String?" } ]
                returns: String
                body:
                  - let: mark
                    type: String
                    value:
                      call:
                        procedure: Standard.Optional.unwrapped
                        arguments:
                          - { ref: mark }
                          - closure:
                              const: true
                              isolated: true
                              returns: String
                              body: [ { value: { return: "*" } } ]
                  - value:
                      return:
                        call:
                          procedure: Standard.Text.joined
                          arguments:
                            - [ { call: { procedure: Standard.Text.text, arguments: [ { ref: mark } ] } }, { call: { procedure: Standard.Text.text, arguments: [ { ref: of.title } ] } } ]
                            - ""
            struct:
              title: String
        extensions:
          Int:
            procedures:
              scaled:
                parameters: [ { name: of, type: Int }, { name: by, type: "Int?" } ]
                returns: Int
                body:
                  - let: by
                    type: Int
                    value:
                      call:
                        procedure: Standard.Optional.unwrapped
                        arguments:
                          - { ref: by }
                          - closure:
                              const: true
                              isolated: true
                              returns: Int
                              body: [ { value: { return: 10 } } ]
                  - value:
                      return: { call: { procedure: Standard.Numeric.times, arguments: [ { ref: of }, { ref: by } ] } }
        procedures:
          App.entry:
            access: public
            returns: "Array<Any>"
            failing: [ cast_refused ]
            body:
              - value:
                  return:
                    - call:
                        procedure: App.Card.label
                        arguments: [ { as: { type: App.Card, of: { struct: { title: a } } } }, null ]
                    - { call: { procedure: Int.scaled, arguments: [ 4, null ] } }
        """)
    }

    @Test("a call by name leaves a defaulted parameter out, the text's own and a leaned-on one")
    func aCallByNameLeavesADefaultOut() throws {
        // Given
        let written = """
        name: Lib
        procedures:
          say:
            access: public
            parameters: [ words: String, timeout: { type: Int, default: 30, hint: seconds } ]
            returns: String
            result: { format: "${c} ${t}", with: { c: { ref: words }, t: { text: { ref: timeout } } } }
        """
        let frontend = try YAMLFrontend().leaning(on: [.text(written)])

        // When
        let document = try frontend.document(from: """
        name: App
        procedures:
          entry:
            access: public
            returns: String
            result: { call: { procedure: say, arguments: { words: hi } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.say ]
        procedures:
          App.entry:
            access: public
            returns: String
            body: [ { value: { return: { call: { procedure: Lib.say, arguments: [ hi, null ] } } } } ]
        """)
        #expect(try sut.documentation(from: written).hints == ["Lib.say": ["timeout": "seconds"]])
    }

    @Test("a text writing its imports names what a default sends, as it names what a spelling sends")
    func aClaimedImportsListIsKept() throws {
        // Given
        let text = { (imports: String) in
            """
            imports: \(imports)
            procedures:
              wait:
                parameters: [ timeout: { type: Int, default: 30 } ]
                returns: Int
                result: { ref: timeout }
            """
        }

        // When / Then. The list the text writes stands, a wrong one included,
        // for the load to refuse
        try expectDocument(try sut.document(from: text("[ Standard.Optional.unwrapped ]")), is: """
        warp: 1
        imports: [ Standard.Optional.unwrapped ]
        procedures:
          wait:
            parameters: [ { name: timeout, type: "Int?" } ]
            returns: Int
            body:
              - let: timeout
                type: Int
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: timeout }
                      - closure: { const: true, isolated: true, returns: Int, body: [ { value: { return: 30 } } ] }
              - { value: { return: { ref: timeout } } }
        """)
        try expectDocument(try sut.document(from: text("[]")), is: """
        warp: 1
        imports: []
        procedures:
          wait:
            parameters: [ { name: timeout, type: "Int?" } ]
            returns: Int
            body:
              - let: timeout
                type: Int
                value:
                  call:
                    procedure: Standard.Optional.unwrapped
                    arguments:
                      - { ref: timeout }
                      - closure: { const: true, isolated: true, returns: Int, body: [ { value: { return: 30 } } ] }
              - { value: { return: { ref: timeout } } }
        """)
    }

    @Test("a default of null is refused at the default")
    func aDefaultOfNullRefuses() {
        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              wait:
                parameters:
                  - timeout: { type: Int?, default: null }
            """)
        } throws: { error in
            Self.message(of: error)
                == "a default of null is what an Optional parameter left out is handed. Write 'timeout: T?'"
                && Self.line(of: error) == 4
        }
    }

    @Test("a default on a parameter handed in place is refused at the parameter")
    func aDefaultInPlaceRefuses() {
        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              bump:
                parameters:
                  - count: { type: inout Int, default: 0 }
                body:
                  - set: count
                    value: 1
            """)
        } throws: { error in
            Self.message(of: error) == "a parameter handed in place takes a variable, and a default is none"
                && (error as? AuthoringError)?.position == Origin.Position(line: 4, column: 9)
        }
    }

    @Test("a closure's parameter takes no default: the pair is written as it is, and a place at it reads its line")
    func aClosuresParameterTakesNoDefault() throws {
        // Given
        let text = """
        procedures:
          entry:
            body:
              - let: f
                value:
                  closure:
                    parameters: [ n: { type: Int, default: 1 } ]
                    returns: Int
                    result: { ref: n }
        """

        // When
        let document = try sut.document(from: text)

        // Then. The load refuses the pair at the parameter
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body:
              - let: f
                value:
                  closure:
                    parameters: [ { n: { type: Int, default: 1 } } ]
                    returns: Int
                    body: [ { value: { return: { ref: n } } } ]
        """)

        let reading = document.origin.reading(["procedures", "entry", "body", 0, "value", "closure", "parameters", 0])

        #expect(reading.exact)
        #expect(reading.position.line == 7)
    }

    @Test("a default that does not read is written as it is, and a place in it reads its line")
    func aDefaultThatDoesNotReadRefuses() throws {
        // Given
        let text = """
        procedures:
          wait:
            parameters:
              - timeout:
                  type: Int
                  default: { cast: 2 }
            returns: Int
            result: { ref: timeout }
        """

        // When. The load refuses the cast the binding returns
        let reading = try sut.document(from: text).origin.reading(["procedures", "wait"] + Self.returned + ["cast"])

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 6)
    }

    @Test("a place inside a default reads the default's line, and one after the bindings its own", arguments: [
        (
            "parameters:\n      - n:\n          type: Int\n          default: { of: 1, plus: \"a\" }",
            ["procedures", "f"] + DefaultArgumentTests.returned + ["call", "arguments", 1] as [Origin.Step],
            8
        ),
        (
            "parameters:\n      - n:\n          type: Int\n          default: { ref: seed }",
            ["procedures", "f"] + DefaultArgumentTests.returned + ["ref"] as [Origin.Step],
            8
        ),
        (
            "parameters: [ n: { type: Int, default: 1 } ]\n    body:\n      - let: m\n        value: { of: { ref: n }, plus: \"a\" }",
            ["procedures", "f", "body", 1, "value", "call", "arguments", 1] as [Origin.Step],
            8
        )
    ])
    func aPlaceInADefaultReadsTheTextsLine(written: String, steps: [Origin.Step], line: Int) throws {
        // Given
        let text = "var:\n  seed: { type: Int, value: 3 }\nprocedures:\n  f:\n    \(written)"

        // When
        let reading = try sut.document(from: text).origin.reading(steps)

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == line)
    }

    @Test("a default nested past the bound is refused inside the default the text wrote")
    func aDefaultNestedPastTheBoundRefusesInIt() {
        // Given. The outermost array stands at column 34, inside 6 containers
        // of the text and 13 of the document once its binding is spent. So
        // the writer refuses the 116th array, at column 149, and the parse
        // refuses the 123rd, at column 156
        let text = { (depth: Int) in
            let nested = String(repeating: "[", count: depth) + "1" + String(repeating: "]", count: depth)

            return """
            name: App
            procedures:
              entry:
                parameters:
                  - x: { type: Any, default: \(nested) }
                returns: Any
                description: reads x
                body:
                  - let: y
                    value: { ref: x }
                result: { ref: y }
            """
        }

        // When
        let deepest = Result { try sut.document(from: text(115)) }
        let written = Result { try sut.document(from: text(116)) }
        let parsed = Result { try sut.document(from: text(400)) }

        // Then
        #expect(throws: Never.self) { try deepest.get() }
        #expect {
            try written.get()
        } throws: { error in
            Self.message(of: error) == "the document nests deeper than 128 containers"
                && (error as? AuthoringError)?.position == Origin.Position(line: 5, column: 149)
        }
        #expect {
            try parsed.get()
        } throws: { error in
            Self.message(of: error) == "the text nests deeper than 128 containers"
                && (error as? AuthoringError)?.position == Origin.Position(line: 5, column: 156)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // The steps from a procedure to what its first binding's closure
    // returns: the default the text wrote.
    private static let returned: [Origin.Step] = [
        "body", 0, "value", "call", "arguments", 1, "closure", "body", 0, "value", "return"
    ]

    private static func message(of error: any Error) -> String? {
        (error as? AuthoringError)?.message
    }

    private static func line(of error: any Error) -> Int? {
        guard let position = (error as? AuthoringError)?.position else { return nil }

        return position.line
    }
}
