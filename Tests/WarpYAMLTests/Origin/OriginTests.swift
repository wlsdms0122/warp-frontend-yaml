//
//  OriginTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/30/26.
//

import Foundation
import Testing
import WarpYAML

// The far end of a refusal: whoever loads or builds a document says which
// place it refused, as the spec's steps, and the document's origin says which
// line of the text the author typed it on. Each place here is written by
// hand, as the steps a load or a build names.
@Suite("Where the text is")
struct OriginTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    // A document with one of everything a place steps through: a
    // declaration, a parameter, a body, a statement by position, a construct
    // and an argument.
    private let written = """
    name: Demo
    procedures:
      entry:
        parameters:
          - count: Int
        body:
          - let: spin
            value:
              loop:
                while: { ref: count }
                body:
                  - let: sent
                    value:
                      call:
                        procedure: helper
                        arguments:
                          - { ref: count }
      helper:
        parameters:
          - amount: Int
    """

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a place the text wrote is followed exactly, step by step")
    func aPlaceReachesTheLineItsProceduresWereTypedOn() throws {
        // Given
        let sut = try frontend.document(from: written).origin
        let entry: [Origin.Step] = ["procedures", "Demo.entry"]

        // When
        let procedure = sut.reading(entry)
        let parameter = sut.reading(entry + ["parameters", 0])
        let statement = sut.reading(entry + ["body", 0])
        let argument = sut.reading(entry + ["body", 0, "value", "loop", "body", 0, "value", "call", "arguments", 0])

        // Then
        #expect(procedure.exact)
        #expect(parameter.exact)
        #expect(statement.exact)
        #expect(argument.exact)
        #expect(argument.followed == 12)

        #expect(procedure.position == Origin.Position(line: 3, column: 3))
        #expect(parameter.position == Origin.Position(line: 5, column: 9))
        #expect(statement.position.line == 7)
        #expect(argument.position.line == 17)
    }

    @Test("a key the document writes in full reaches the short key the text wrote under `name:`")
    func aFullKeyReachesTheShortOne() throws {
        // Given
        let sut = try frontend.document(from: written).origin

        // When
        let full = sut.reading(["procedures", "Demo.helper", "parameters", 0])
        let short = sut.reading(["procedures", "helper"])

        // Then. The document has no key `helper`, so the walk stops at
        // `procedures`
        #expect(full.exact)
        #expect(full.position.line == 20)
        #expect(short.exact == false)
        #expect(short.followed == 1)
        #expect(short.asked == 2)
        #expect(short.position.line == 2)
    }

    @Test("an extension's key, written in full, reaches the head the text wrote short")
    func anExtensionKeyReachesItsHead() throws {
        // Given
        let text = """
        name: Bank
        types:
          Account: { struct: {} }
        extensions:
          Array<Account>:
            procedures:
              total: {}
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["extensions", "Array<Bank.Account>", "procedures", "total"]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 7)
    }

    @Test("a statement is found by its position, so one name written twice stays two")
    func aStatementIsFoundByPosition() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            body:
              - var: gate
              - set: gate
                value: 1
        """
        let sut = try frontend.document(from: text).origin

        // When
        let first = sut.reading(["procedures", "Demo.entry", "body", 0])
        let second = sut.reading(["procedures", "Demo.entry", "body", 1])

        // Then
        #expect(first.exact)
        #expect(first.position.line == 5)
        #expect(second.exact)
        #expect(second.position.line == 6)
    }

    @Test("a key the document does not have is written through, and a place at it reads its key")
    func aKeyTheLoadRefusesReachesItsLine() throws {
        // Given. The load refuses the key, so the author is sent to the key
        // and not to the statement holding it
        let text = """
        name: Demo
        procedures:
          entry:
            body:
              - let: sent
                value: x
                fallbck: y
          helper:
            body:
              - let: helper
                value:
                  closure:
                    body:
                      - let: inner
                        value: x
                        fallbck: y
        """
        let sut = try frontend.document(from: text).origin

        // When
        let statement = sut.reading(["procedures", "Demo.entry", "body", 0, "fallbck"])
        let closure = sut.reading(["procedures", "Demo.helper", "body", 0, "value", "closure", "body", 0, "fallbck"])

        // Then
        #expect(statement.exact)
        #expect(statement.position == Origin.Position(line: 7, column: 9))
        #expect(closure.exact)
        #expect(closure.position == Origin.Position(line: 16, column: 17))
    }

    @Test("a host's own construct key is written through, and a place inside it reads its line")
    func aComposedHostReachesTheSamePlace() throws {
        // Given
        let text = """
        procedures:
          entry:
            body:
              - value:
                  unless:
                    when: false
                    body:
                      - var: gate
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["procedures", "entry", "body", 0, "value", "unless", "body", 0]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 8)
    }

    @Test("a place past what the document holds stops at the deepest node it reached")
    func aPlaceThatRunsOutOfTheDocumentSaysSo() throws {
        // Given
        let sut = try frontend.document(from: written).origin
        let loop: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "loop"]

        // When
        let pastAScalar = sut.reading(loop + ["while", "ref", "name"])
        let pastAList = sut.reading(loop + ["body", 1, "value"])

        // Then
        #expect(pastAScalar.exact == false)
        #expect(pastAScalar.followed == 8)
        #expect(pastAScalar.asked == 9)
        #expect(pastAScalar.position.line == 10)
        #expect(pastAList.exact == false)
        #expect(pastAList.followed == 7)
        #expect(pastAList.position.line == 11)
    }

    @Test("a statement after a procedure's default bindings counts the bindings, and stands at its own line")
    func aStatementAfterTheBindingsReadsItsLine() throws {
        // Given
        let sut = try frontend.document(from: Self.defaulted).origin

        // When
        let statement = sut.reading(["procedures", "App.wait", "body", 2])
        let returned = sut.reading(["procedures", "App.wait", "body", 3, "value", "return", "ref"])

        // Then
        #expect(statement.exact)
        #expect(statement.position.line == 12)
        #expect(returned.exact)
        #expect(returned.position.line == 14)
    }

    @Test("a place in a binding the text did not write stands at its parameter, and inside the default at the default")
    func aPlaceInABindingReadsTheDefault() throws {
        // Given
        let sut = try frontend.document(from: Self.defaulted).origin
        let binding: [Origin.Step] = ["procedures", "App.wait", "body", 1]

        // When
        let statement = sut.reading(binding)
        let handed = sut.reading(binding + ["value", "call", "arguments", 0])
        let closure = sut.reading(binding + ["value", "call", "arguments", 1, "closure"])
        let value = sut.reading(binding + ["value", "call", "arguments", 1, "closure", "body", 0, "value", "return"])
        let inside = sut.reading(
            binding + ["value", "call", "arguments", 1, "closure", "body", 0, "value", "return", "call", "arguments", 0]
        )

        // Then
        #expect(statement.exact == false)
        #expect(statement.followed == 3)
        #expect(statement.position.line == 8)
        #expect(handed.exact == false)
        #expect(handed.position.line == 8)
        #expect(closure.exact == false)
        #expect(closure.position.line == 8)
        #expect(value.exact)
        #expect(value.position.line == 10)
        #expect(inside.exact)
        #expect(inside.position.line == 10)
    }

    @Test("a place under a later arm of `cases` reads the line in that arm", arguments: [
        (
            "- when: { of: { ref: n }, is: 2 }\n              then:\n                - let: q\n                  value: { call: { procedure: pair, arguments: [ a, 2 ] } }",
            ["else", 0, "value", "conditional", "then", 0, "value", "call", "arguments", 1] as [Origin.Step],
            17
        ),
        (
            "- else:\n                - let: q\n                  value: { call: { procedure: pair, arguments: [ a, 2 ] } }",
            ["else", 0, "value", "call", "arguments", 1] as [Origin.Step],
            16
        )
    ])
    func anArmReachesItsLine(arm: String, steps: [Origin.Step], line: Int) throws {
        // Given. The second arm stands in the first one's `else`, and the
        // last `else` arm in the second one's
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            parameters: [ n: Int ]
            body:
              - value:
                  cases:
                    - when: { of: { ref: n }, is: 1 }
                      then: []
                    \(arm)
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["procedures", "App.entry", "body", 0, "value", "conditional"] + steps
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == line)
    }

    @Test("a place under the first arm of `cases` reads the line in that arm, and the nesting stands at the arm", arguments: [
        "first: a\n                        second: 2",
        "- a\n                        - 2"
    ])
    func aFirstArmReachesItsLine(arguments: String) throws {
        // Given. The first arm is the conditional the statement is read as
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            parameters: [ n: Int ]
            body:
              - value:
                  cases:
                    - when: { of: { ref: n }, is: 1 }
                      then:
                        - let: q
                          value:
                            call:
                              procedure: pair
                              arguments:
                                \(arguments)
        """
        let sut = try frontend.document(from: text).origin
        let conditional: [Origin.Step] = ["procedures", "App.entry", "body", 0, "value", "conditional"]

        // When
        let argument = sut.reading(conditional + ["then", 0, "value", "call", "arguments", 1])
        let nesting = sut.reading(conditional)

        // Then
        #expect(argument.exact)
        #expect(argument.position.line == 20)
        #expect(nesting.exact == false)
        #expect(nesting.position.line == 12)
    }

    @Test("a place in the body of `each` reads the line in that body, after the round's bindings", arguments: [
        ("", 1, 19),
        ("\n            index: i", 2, 20)
    ])
    func aWalkReachesItsBody(index: String, statement: Int, line: Int) throws {
        // Given. Each round binds the element, and the position where the
        // text names one, before the body's statements
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            body:
              - let: walk
                value:
                  each:
                    of: [ a, b ]
                    as: s\(index)
                    body:
                      - let: q
                        value:
                          call:
                            procedure: pair
                            arguments: [ { ref: s }, 2 ]
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            Self.loop(in: "App.entry") + ["body", .index(statement), "value", "call", "arguments", 1]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == line)
    }

    @Test("a place in what `each` is spent into stands at what the text wrote it from")
    func aWalksPartsReachTheirLines() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            parameters: [ words: "Array<String>" ]
            body:
              - let: walk
                value:
                  each:
                    of: { ref: words }
                    as: word
                    body: []
        """
        let sut = try frontend.document(from: text).origin
        let arm: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "conditional"]

        // When
        let array = sut.reading(arm + ["then", 0, "value"])
        let count = sut.reading(Self.loop(in: "Demo.entry") + ["while", "call", "arguments", 1, "call", "arguments", 0])
        let element = sut.reading(Self.loop(in: "Demo.entry") + ["body", 0, "let"])
        let read = sut.reading(Self.loop(in: "Demo.entry") + ["body", 0, "value", "ref"])
        let condition = sut.reading(arm + ["when"])

        // Then. The array's binding holds what `of` wrote, the count reads
        // it at `of`, and each round's element is bound where `as` is
        #expect(array.exact)
        #expect(array.position.line == 9)
        #expect(count.exact == false)
        #expect(count.position.line == 9)
        #expect(element.exact)
        #expect(element.position.line == 10)
        #expect(read.exact == false)
        #expect(read.position.line == 10)
        #expect(condition.exact == false)
        #expect(condition.position.line == 8)
    }

    @Test("an operator mapping is read as the call it is spent into, each argument where the text wrote it")
    func anOperatorReachesItsArguments() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            body:
              - let: spin
                value:
                  loop:
                    while:
                      of: 1
                      greaterThan: 0
                    body: []
        """
        let sut = try frontend.document(from: text).origin
        let call: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "loop", "while", "call"]

        // When
        let subject = sut.reading(call + ["arguments", 0])
        let operand = sut.reading(call + ["arguments", 1])
        let callee = sut.reading(call + ["procedure"])

        // Then
        #expect(subject.exact)
        #expect(subject.position.line == 9)
        #expect(operand.exact)
        #expect(operand.position.line == 10)
        #expect(callee.exact == false)
        #expect(callee.position.line == 10)
    }

    @Test("a place under each operator form reads the line its operand wrote", arguments: [
        // One key alone: `count` takes what is under it.
        (
            "returns: Int\n    body:\n      - let: n\n        value:\n          count: 5\n    result: { ref: n }",
            ["body", 0, "value", "call", "arguments", 0] as [Origin.Step],
            12,
            true
        ),
        // A procedure the text declares, beside a subject.
        (
            "returns: String\n    body:\n      - let: out\n        value:\n          of: a\n          pair: 2\n    result: { ref: out }",
            ["body", 0, "value", "call", "arguments", 1] as [Origin.Step],
            13,
            true
        ),
        // An operand the form fixes beside the one under the key.
        (
            "returns: Bool\n    result:\n      present:\n        call:\n          procedure: pair\n          arguments: [ a, b ]",
            ["body", 0, "value", "return", "call", "arguments", 0] as [Origin.Step],
            10,
            true
        ),
        (
            "returns: Bool\n    result:\n      present:\n        call:\n          procedure: pair\n          arguments: [ a, b ]",
            ["body", 0, "value", "return", "call", "arguments", 1] as [Origin.Step],
            10,
            false
        )
    ])
    func anOperatorFormReachesItsLine(entry: String, steps: [Origin.Step], line: Int, exact: Bool) throws {
        // Given
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            \(entry)
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(["procedures", "App.entry"] + steps)

        // Then
        #expect(reading.exact == exact)
        #expect(reading.position.line == line)
    }

    @Test("a side of a connective is a closure completed from its slot, and its body reads the side's line")
    func aConnectiveSideReachesItsLine() throws {
        // Given
        let text = """
        name: App
        procedures:
          flag:
            const: true
            parameters: [ x: String ]
            returns: Bool
            result: true
          entry:
            returns: Bool
            body:
              - let: ok
                value:
                  all_of:
                    - true
                    - call:
                        procedure: flag
                        arguments: [ 2 ]
            result: { ref: ok }
        """
        let sut = try frontend.document(from: text).origin
        let side: [Origin.Step] = ["procedures", "App.entry", "body", 0, "value", "call", "arguments", 0, 1, "closure"]

        // When
        let argument = sut.reading(side + ["body", 0, "value", "return", "call", "arguments", 0])
        let returns = sut.reading(side + ["returns"])

        // Then
        #expect(argument.exact)
        #expect(argument.position.line == 17)
        #expect(returns.exact == false)
        #expect(returns.position.line == 15)
    }

    @Test("a closure handed to a call is followed into its body, and its operand's argument reads its line")
    func anOperatorOperandReachesItsLine() throws {
        // Given. The closure is the operand under `map`
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            returns: "Array<String>"
            body:
              - let: out
                value:
                  of: [ a, b ]
                  map:
                    closure:
                      parameters: [ s: String ]
                      returns: String
                      body:
                        - let: r
                          value:
                            call:
                              procedure: pair
                              arguments: [ { ref: s }, 2 ]
                      result: { ref: r }
            result: { ref: out }
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["procedures", "App.entry", "body", 0, "value", "call", "arguments", 1, "closure", "body", 0]
                + ["value", "call", "arguments", 1]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 22)
    }

    @Test("a template's piece is followed into the call it is spent into, to the expression it reads")
    func aTemplatesPieceReachesItsBinding() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            parameters: [ who: String ]
            body:
              - let: said
                value: { format: "hi ${name}", with: { name: { ref: who } } }
        """
        let sut = try frontend.document(from: text).origin
        let pieces: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "call", "arguments", 0]

        // When
        let piece = sut.reading(pieces + [0])
        let read = sut.reading(pieces + [1, "call", "arguments", 0])

        // Then. The text piece the template wrote no node for stands at it
        #expect(piece.exact == false)
        #expect(piece.position.line == 7)
        #expect(read.exact)
        #expect(read.position.line == 7)
    }

    @Test("arguments written by name are read in the callee's order, an Optional left out at the arguments")
    func namedArgumentsReadInTheCalleesOrder() throws {
        // Given
        let text = """
        name: App
        procedures:
          inner:
            const: true
            parameters: [ x: Int, y: Int, z: Int? ]
            returns: Int
            result: { ref: x }
          entry:
            returns: Int
            body:
              - let: r
                value:
                  call:
                    procedure: inner
                    arguments:
                      - 1
                      - call:
                          procedure: inner
                          arguments:
                            y: "x"
                            x: 2
                      - null
            result: { ref: r }
        """
        let sut = try frontend.document(from: text).origin
        let inner: [Origin.Step] = ["procedures", "App.entry", "body", 0, "value", "call", "arguments", 1, "call"]

        // When
        let first = sut.reading(inner + ["arguments", 0])
        let second = sut.reading(inner + ["arguments", 1])
        let leftOut = sut.reading(inner + ["arguments", 2])

        // Then
        #expect(first.exact)
        #expect(first.position.line == 21)
        #expect(second.exact)
        #expect(second.position.line == 20)
        #expect(leftOut.exact == false)
        #expect(leftOut.followed == 10)
        #expect(leftOut.position.line == 19)
    }

    @Test("`result:` is read as a `return` after the body, and a place in it reads the line it wrote", arguments: [
        (
            "returns: String\n    body:\n      - let: x\n        value: a\n    result:\n      call:\n        procedure: pair\n        arguments:\n          - { ref: x }\n          - 2",
            ["body", 1, "value", "return", "call", "arguments", 1] as [Origin.Step],
            17
        ),
        (
            "body:\n      - let: f\n        value:\n          closure:\n            returns: String\n            result:\n              call:\n                procedure: pair\n                arguments:\n                  - a\n                  - 2",
            ["body", 0, "value", "closure", "body", 0, "value", "return", "call", "arguments", 1] as [Origin.Step],
            18
        )
    ])
    func aReturnValueReachesItsLine(entry: String, steps: [Origin.Step], line: Int) throws {
        // Given
        let text = """
        name: App
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            \(entry)
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(["procedures", "App.entry"] + steps)

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == line)
    }

    @Test("a struct whose fields are called `body` and `result` is read as written")
    func aStructHoldsNoReturnValue() throws {
        // Given
        let text = """
        name: App
        types:
          Reply: { struct: { body: String, result: Int } }
        procedures:
          pair:
            parameters: [ first: String, second: String ]
            returns: String
            result: { ref: first }
          entry:
            body:
              - let: s
                type: Reply
                value:
                  struct:
                    body:
                      call:
                        procedure: pair
                        arguments:
                          - a
                          - 2
                    result: 1
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["procedures", "App.entry", "body", 0, "value", "struct", "body", "call", "arguments", 1]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 20)
    }

    @Test("a place in a module variable reads the line under its `value`")
    func aVariableReachesItsArgument() throws {
        // Given
        let text = """
        name: App
        var:
          greeting:
            type: String
            value:
              call:
                procedure: Standard.Text.joined
                arguments:
                  - [ a, b ]
                  - 1
        procedures:
          entry:
            returns: String
            result: { ref: greeting }
        """

        // When
        let reading = try frontend.document(from: text).origin.reading(
            ["var", "greeting", "value", "call", "arguments", 1]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 10)
    }

    @Test("what the Front writes for the document as a whole stands at its root")
    func theImportsListStandsAtTheRoot() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            returns: String
            result: { of: [ a, b ], joined: "" }
        """
        let sut = try frontend.document(from: text).origin

        // When
        let imports = sut.reading(["imports"])
        let first = sut.reading(["imports", 0])
        let version = sut.reading(["warp"])
        let root = sut.reading([])

        // Then
        #expect(imports.exact == false)
        #expect(imports.followed == 0)
        #expect(imports.position == root.position)
        #expect(first.exact == false)
        #expect(first.position == root.position)
        #expect(version.exact == false)
        #expect(root.exact)
        #expect(root.position.line == 1)
    }

    // MARK: - Public
    // MARK: - Private
    // A procedure with two defaults, so its body starts with two bindings
    // the text did not write.
    private static let defaulted = """
    name: App
    procedures:
      wait:
        parameters:
          - label:
              type: String
              default: idle
          - timeout:
              type: Int
              default: { of: 30, plus: 1 }
        body:
          - let: waited
            value: { ref: timeout }
        result: { ref: waited }
    """

    // The steps to the loop a walk is spent into, where the walk is the
    // first statement of `procedure`.
    private static func loop(in procedure: String) -> [Origin.Step] {
        ["procedures", .key(procedure), "body", 0, "value", "conditional", "then", 1, "value", "loop"]
    }
}
