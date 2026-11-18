//
//  CompletionPointTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A completion asked in a text being written: the statement at the position
// is written as what it reads up to there, the statements after it are left
// out, and where the text still does not spend, the other bodies are read
// empty.
@Suite("What a completion reads")
struct CompletionPointTests {
    // MARK: - Property
    private let frontend: YAMLFrontend

    // Line 11 is being written, after the dot or before it, and line 13 and
    // the other procedure do not read.
    private let written = """
    name: Demo
    types:
      Report: { struct: { outcome: String, count: Int } }
    procedures:
      entry:
        parameters: [ report: "Report?" ]
        body:
          - let: first
            value: 1
          - let: typing
            value: { ref: report?.ou }
          - let: later
            value: { call: { procedure: nothing } }
      other:
        body:
          - value: { call: { procedure: none } }
    """

    // Two texts of one module: the first declares what the second's body
    // calls, and line 8 of the second is being written.
    private static let giving = """
    name: Demo
    procedures:
      give: { returns: String, result: "x" }
    """

    private static let reading = """
    name: Demo
    procedures:
      entry:
        body:
          - let: first
            value: { call: { procedure: give } }
          - let: typing
            value: { ref: first.cou }
    """

    // MARK: - Initializer
    init() throws {
        self.frontend = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("after a dot, the statement reads the path before it, at the receiver's place")
    func afterADotTheStatementReadsThePath() throws {
        // When
        let sut = try frontend.completion(at: Origin.Position(line: 11, column: 33), in: written)

        // Then
        let statement: [Origin.Step] = ["procedures", "Demo.entry", "body", 1]

        #expect(sut.names.map(\.spelling) == ["first", "report"])
        #expect(sut.receiver == statement + ["value"])
        #expect(Self.node(at: statement, in: sut.origin.document) == ["value": ["ref": "report"]])
        #expect(Self.node(at: ["procedures", "Demo.entry", "body"], in: sut.origin.document)?.arrayValue?.count == 2)
        #expect(sut.origin.reading(statement).position.line == 10)
    }

    @Test("in a member an extension gives the text's own struct, the receiver stands where the declaration gives it")
    func inAnExtensionOfTheTextsStruct() throws {
        // Given. Line 12 is being written, after the dot
        let text = """
        name: Demo
        types:
          Report: { struct: { outcome: String } }
        extensions:
          Report:
            procedures:
              shown:
                parameters: [ of: Report ]
                returns: String
                body:
                  - let: typing
                    value: { ref: of.ou }
        """

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 12, column: 28), in: text)

        // Then
        #expect(sut.names.map(\.spelling) == ["of"])
        #expect(sut.receiver == ["types", "Demo.Report", "procedures", "shown", "body", 0, "value"])
    }

    @Test("where the path holds no dot, the statement reads nothing and gives the names alone")
    func withNoDotTheStatementReadsNothing() throws {
        // When
        let sut = try frontend.completion(
            at: Origin.Position(line: 11, column: 26),
            in: written.replacingOccurrences(of: "report?.ou", with: "rep")
        )

        // Then
        #expect(sut.names.map(\.spelling) == ["first", "report"])
        #expect(sut.receiver == nil)
        #expect(Self.node(at: ["procedures", "Demo.entry", "body", 1], in: sut.origin.document) == ["value": nil])
    }

    @Test("a statement later in the body reads the names before it, the one being written among them")
    func aLaterStatementReadsTheNamesBeforeIt() throws {
        // When
        let sut = try frontend.completion(at: Origin.Position(line: 13, column: 20), in: written)

        // Then
        #expect(sut.names.map(\.spelling) == ["first", "report", "typing"])
    }

    @Test("a position in no procedure's body is refused there")
    func aPositionInNoBodyIsRefused() throws {
        // When
        let refused = refusal { try frontend.completion(at: Origin.Position(line: 3, column: 10), in: written) }

        // Then
        #expect(refused?.message == "no statement of a procedure's body stands here")
        #expect(refused?.position == Origin.Position(line: 3, column: 10))
    }

    @Test("in a loop's condition, the condition reads the path and the loop stays, reading its round")
    func aConditionReadsThePathAndTheLoopStays() throws {
        // Given
        let text = """
        name: Demo
        procedures:
          entry:
            body:
              - let: spin
                value:
                  loop:
                    while: { ref: spin.ind }
                    body:
                      - value: { call: { procedure: nothing } }
        """

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 8, column: 39), in: text)

        // Then
        let loop: [Origin.Step] = ["procedures", "Demo.entry", "body", 0, "value", "loop"]

        #expect(sut.names.map(\.spelling) == ["spin"])
        #expect(sut.receiver == loop + ["while"])
        #expect(Self.node(at: loop, in: sut.origin.document) == ["while": ["ref": "spin"], "body": []])
    }

    @Test("a text with CRLF line ends reads the path as one with LF does")
    func aTextWithCarriageReturnsReadsThePath() throws {
        // Given
        let text = written.replacingOccurrences(of: "\n", with: "\r\n")

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 11, column: 33), in: text)

        // Then
        #expect(sut.receiver == ["procedures", "Demo.entry", "body", 1, "value"])
    }

    @Test("a text of a module reads what another text of it declares, which its document holds")
    func aTextReadsItsModulesOtherTexts() throws {
        // Given. Line 8 of the second text is being written, after the dot
        let texts = [Self.giving, Self.reading]

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 8, column: 32), inText: 1, of: texts)

        // Then
        #expect(sut.names.map(\.spelling) == ["first"])
        #expect(sut.receiver == ["procedures", "Demo.entry", "body", 1, "value"])
        #expect(Self.node(at: ["procedures", "Demo.give"], in: sut.origin.document) != nil)
        #expect(sut.origin.reading(["procedures", "Demo.entry", "body", 1]).text == 1)
    }

    @Test("where another text of the module does not spend, its bodies are read empty")
    func anotherTextThatDoesNotSpendIsReadEmpty() throws {
        // Given
        let broken = Self.giving + "\n  broken: { body: [ { value: { call: { procedure: nowhere } } } ] }"

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 8, column: 32), inText: 1, of: [broken, Self.reading])

        // Then
        #expect(sut.receiver == ["procedures", "Demo.entry", "body", 1, "value"])
        #expect(Self.node(at: ["procedures", "Demo.broken", "body"], in: sut.origin.document) == [])
    }

    @Test("what is written in place is found in its own text, where another writes the same at the same place")
    func whatIsWrittenIsFoundInItsOwnText() throws {
        // Given. The first text writes, where the second's statement being
        // written stands, the statement that one is written as
        let same = """
        name: Demo
        procedures:
          give: { returns: String, result: "x" }
          other:
            parameters: [ first: Int ]
            body:
              - value: { ref: first }
        """

        // When
        let sut = try frontend.completion(at: Origin.Position(line: 8, column: 32), inText: 1, of: [same, Self.reading])

        // Then
        #expect(sut.receiver == ["procedures", "Demo.entry", "body", 1, "value"])
    }

    @Test("what is written in place is looked for in its own text alone, and refused in it where only another holds it")
    func whatIsWrittenOnlyInAnotherTextIsRefused() throws {
        // Given. The second text's point, and a document where only the first
        // text holds what it wrote
        let sut = try CompletionPoint(in: try YAMLParser().parse(Self.reading), inText: 1, at: Origin.Position(line: 8, column: 32))

        // When
        var refused: AuthoringError?

        do {
            _ = try sut.places(in: sut.text.inText(0))
        } catch {
            refused = error
        }

        // Then
        #expect(refused?.message == "no statement of a procedure's body stands here")
        #expect(refused?.text == 1)
        #expect(refused?.position == Origin.Position(line: 8, column: 32))
    }

    @Test("a completion in a text the module does not have is refused")
    func aCompletionInNoTextIsRefused() {
        // When
        let refused = refusal {
            try frontend.completion(at: Origin.Position(line: 8, column: 32), inText: 2, of: [Self.giving, Self.reading])
        }

        // Then
        #expect(refused?.message == "a completion is asked in one of the module's texts, and there is no text 2")
    }

    @Test("the receiver is the path before the last dot, reading quotes and brackets", arguments: [
        ("report.ou", "report"),
        ("report?.", "report"),
        ("a[\"k.j\"].", "a[\"k.j\"]"),
        ("items[cur.", "cur"),
        ("items[0].name.fi", "items[0].name"),
        ("report", nil),
        (".x", nil)
    ] as [(String, String?)])
    func theReceiverIsThePathBeforeTheLastDot(written: String, receiver: String?) {
        // When / Then
        #expect(CompletionPoint.receiver(of: written) == receiver)
    }

    // MARK: - Public
    // MARK: - Private
    private static func node(at steps: [Origin.Step], in tree: Tree) -> Tree? {
        steps.reduce(Optional(tree)) { node, step in
            switch step {
            case let .key(key):
                node?[key]

            case let .index(index):
                node?.arrayValue.flatMap { elements in elements.indices.contains(index) ? elements[index] : nil }
            }
        }
    }
}
