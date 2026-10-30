//
//  YAMLParserTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/18/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A parse is a function from text to a `Tree`, and this is that function's
// whole contract: the values it builds, and the ways it refuses.
@Suite("Text becoming a tree")
struct YAMLParserTests {
    // MARK: - Property
    private let sut = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the three container kinds build the three value kinds")
    func containersBecomeValues() throws {
        // Given / When
        let parsed = try sut.parse("""
        name: greeter
        rounds:
          - 1
          - 2
        nested:
          inner: true
        """)

        // Then
        #expect(parsed == [
            "name": "greeter",
            "rounds": [1, 2],
            "nested": ["inner": true]
        ])
    }

    @Test("a quoted scalar is a string, whatever it would have meant unquoted", arguments: [
        "\"true\"",
        "'3'",
        "\"null\"",
        "\"1.5\""
    ])
    func quotedScalarsStayStrings(written: String) throws {
        // Given / When. The retyping rule reads plain scalars only, so quoting is how
        // a document says "this is a string" and it has to hold for every procedure that
        // would otherwise be taken
        let parsed = try sut.parse("subject: \(written)")

        // Then
        #expect(parsed["subject"]?.stringValue != nil)
    }

    @Test("a block scalar is a string")
    func blockScalarsStayStrings() throws {
        // Given / When
        let parsed = try sut.parse("""
        subject: |
          true
        """)

        // Then
        #expect(parsed["subject"]?.stringValue != nil)
    }

    @Test("bytes are read as UTF-8")
    func dataIsReadAsText() throws {
        // Given / When
        let parsed = try sut.parse(Data("subject: 3".utf8))

        // Then
        #expect(parsed == ["subject": 3])
    }

    @Test("a byte order mark in front of the text is not part of it", arguments: [
        "\u{FEFF}a: 1\nb: 2",
        "\u{FEFF}a: 1"
    ])
    func aByteOrderMarkIsNotText(text: String) throws {
        // Given
        let plain = try sut.parse(String(text.unicodeScalars.dropFirst()))

        // When
        let parsed = try sut.parse(text)
        let read = try sut.parse(Data(text.utf8))

        // Then
        #expect(parsed == plain)
        #expect(read == plain)
    }

    @Test("a byte order mark in front of bytes that are not UTF-8 moves no column")
    func aByteOrderMarkMovesNoColumn() {
        // Given
        let bytes = Data("ab".utf8) + Data([0xFF])

        // When
        let plain = #expect(throws: AuthoringError.self) {
            try sut.parse(bytes)
        }
        let marked = #expect(throws: AuthoringError.self) {
            try sut.parse(Data("\u{FEFF}".utf8) + bytes)
        }

        // Then
        #expect(plain?.position == Origin.Position(line: 1, column: 3))
        #expect(marked?.position == plain?.position)
    }

    @Test("bytes that are not UTF-8 are refused")
    func invalidBytesAreRefused() {
        // Given. A lone continuation byte is not a UTF-8 sequence
        let bytes = Data([0xFF, 0xFE, 0xFD])

        // When / Then
        #expect(throws: AuthoringError.self) {
            try sut.parse(bytes)
        }
    }

    @Test("text that is not YAML is refused, and says so")
    func malformedTextIsRefused() {
        // Given / When / Then
        #expect(throws: AuthoringError.self) {
            try sut.parse("name: [unclosed")
        }
    }

    @Test("an empty document is refused rather than read as nothing")
    func emptyDocumentIsRefused() {
        // Given / When / Then. Nothing is not a value, so a blank file is
        // refused as blank rather than read as a document
        #expect(throws: AuthoringError.self) {
            try sut.parse("")
        }
        #expect(throws: AuthoringError.self) {
            try sut.parse("# only a comment\n")
        }
    }

    @Test("a key that is not a scalar is refused")
    func nonScalarKeyIsRefused() {
        // Given / When / Then. A document's key is read as a name, so a sequence key has
        // nothing to become
        #expect(throws: AuthoringError.self) {
            try sut.parse("""
            ? [a, b]
            : taken
            """)
        }
    }

    @Test("a number the reader cannot hold is refused rather than approximated", arguments: [
        "999999999999999999999999999999",
        "1e999"
    ])
    func unholdableNumberIsRefused(written: String) {
        // Given / When / Then. An integer literal wider than `Int` must not fall through to the
        // float pattern and read as roughly itself, which is a document being
        // read as one it is not
        #expect(throws: AuthoringError.self) {
            try sut.parse("subject: \(written)")
        }
    }

    @Test("a number the reader cannot hold is refused in one wording, tagged or not", arguments: [
        ("999999999999999999999999999999", "!!int"),
        ("1e999", "!!float")
    ])
    func unholdableNumberIsSaidOneWay(written: String, tag: String) throws {
        // Given / When
        let untagged = #expect(throws: AuthoringError.self) {
            try sut.parse("subject: \(written)")
        }
        let tagged = #expect(throws: AuthoringError.self) {
            try sut.parse("subject: \(tag) \(written)")
        }

        // Then. Only the text with no tag is read as a string once quoted
        let said = try #require(tagged?.message)

        #expect(untagged?.message == "\(said). Quote it if you meant a string")
    }

    @Test("an explicit core-schema tag reads its YAML 1.2 core schema forms", arguments: [
        ("!!str 12", Tree.string("12")),
        ("!!str true", Tree.string("true")),
        ("!!str null", Tree.string("null")),
        ("! 12", Tree.string("12")),
        ("!!int 12", Tree.int(12)),
        ("!!int \"12\"", Tree.int(12)),
        ("!!int +12", Tree.int(12)),
        ("!!int -12", Tree.int(-12)),
        ("!!int 007", Tree.int(7)),
        ("!!int 0o17", Tree.int(15)),
        ("!!int 0x1F", Tree.int(31)),
        ("!!float 12", Tree.double(12)),
        ("!!float .5", Tree.double(0.5)),
        ("!!float -.5", Tree.double(-0.5)),
        ("!!float 1.", Tree.double(1)),
        ("!!float +1.5e3", Tree.double(1500)),
        ("!!float 2E-1", Tree.double(0.2)),
        ("!!bool true", Tree.bool(true)),
        ("!!bool True", Tree.bool(true)),
        ("!!bool TRUE", Tree.bool(true)),
        ("!!bool false", Tree.bool(false)),
        ("!!bool False", Tree.bool(false)),
        ("!!bool FALSE", Tree.bool(false)),
        ("!!null ~", Tree.null),
        ("!!null null", Tree.null),
        ("!!null Null", Tree.null),
        ("!!null NULL", Tree.null),
        ("!!null", Tree.null),
        ("!!seq [1]", Tree.array([.int(1)])),
        ("!!map { a: 1 }", Tree.dictionary(["a": 1]))
    ])
    func coreSchemaTagsReadTheirForms(written: String, expected: Tree) throws {
        // Given / When
        let parsed = try sut.parse("subject: \(written)")

        // Then
        #expect(parsed.dictionaryValue?["subject"] == expected)
    }

    @Test("a tag outside the core schema, or one the text is no form of, is refused", arguments: [
        "!!int twelve",
        "!!int 1_000",
        "!!int 0b101",
        "!!int 1.5",
        "!!float 1_0.5",
        "!!float 0x1p3",
        "!!bool yes",
        "!!bool tRUE",
        "!!null none",
        "!!binary aGk=",
        "!shout loud",
        "!!str [1]",
        "!!set { a: null }"
    ])
    func foreignTagsAreRefused(written: String) {
        // Given / When / Then
        #expect(throws: AuthoringError.self) {
            try sut.parse("subject: \(written)")
        }
    }

    @Test("a key is a string: it takes no tag, or the core schema's tag for a string", arguments: [
        ("!!str 12: 1", Tree.dictionary(["12": 1])),
        ("! loud: 1", Tree.dictionary(["loud": 1])),
        ("true: 1", Tree.dictionary(["true": 1]))
    ])
    func aKeyIsAString(written: String, expected: Tree) throws {
        // Given / When
        let parsed = try sut.parse(written)

        // Then
        #expect(parsed == expected)
    }

    @Test("a key under any other tag is refused where it is written", arguments: [
        "!shout loud: 1",
        "!!int 12: 1",
        "!!bool true: 1"
    ])
    func aTaggedKeyIsRefused(written: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.parse("name: x\n\(written)")
        }

        // Then
        #expect(error?.position == Origin.Position(line: 2, column: 1))
    }

    @Test("a refused tag says which refusal it is, spelled as the text wrote it", arguments: [
        ("subject: !shout loud", "tag '!shout' is outside the core schema"),
        ("subject: !!binary aGk=", "tag '!!binary' is outside the core schema"),
        ("subject: !!seq loud", "'!!seq' is not a tag a scalar takes"),
        ("subject: !!str [1]", "'!!str' is not a tag a sequence takes"),
        ("!!int 12: 1", "'!!int' is not a tag a key takes"),
        ("subject: !!int twelve", "'twelve' is tagged '!!int' and does not read as one")
    ])
    func aRefusedTagSaysWhy(written: String, said: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.parse(written)
        }

        // Then
        #expect(error?.message.contains(said) == true)
    }

    @Test("a tagged number Warp cannot hold is refused and says why", arguments: [
        ("!!float .inf", "Warp numbers are finite"),
        ("!!float -.Inf", "Warp numbers are finite"),
        ("!!float .NaN", "Warp numbers are finite"),
        ("!!float 1e999", "Warp numbers are finite"),
        ("!!int 9223372036854775808", "does not fit an Int"),
        ("!!int 0x10000000000000000", "does not fit an Int")
    ])
    func unholdableTaggedNumberIsRefused(written: String, said: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.parse("subject: \(written)")
        }

        // Then
        #expect(error?.message.contains(said) == true)
    }

    @Test("an anchored scalar keeps its typing where an alias of it is a key")
    func anAliasKeyLeavesItsAnchorUntagged() throws {
        // Given / When. Yams resolves a key's tag to compare keys, and an alias is
        // the anchored node itself
        let parsed = try sut.parse("""
        mode: &m off
        flags:
          *m : 1
        """)

        // Then
        #expect(parsed == ["mode": "off", "flags": ["off": 1]])
    }

    @Test("a key written twice is refused, whether or not it is quoted", arguments: [
        "a: 1\n\"a\": 2",
        "1: 1\n\"1\": 2"
    ])
    func aKeyWrittenTwiceIsRefused(written: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.parse(written)
        }

        // Then
        #expect(error?.position == Origin.Position(line: 2, column: 1))
    }

    @Test("a key that is no name is written as it is, for the load to refuse")
    func aKeyThatIsNoNameIsWrittenThrough() throws {
        // Given / When
        let parsed = try sut.parse("\"\": 1")

        // Then
        #expect(parsed == ["": 1])
    }

    @Test("a refusal says where the text wrote what it refuses", arguments: [
        ("subject: 999999999999999999999999999999", Origin.Position(line: 2, column: 10)),
        ("subject: !!int twelve", Origin.Position(line: 2, column: 10)),
        ("subject: [unclosed", Origin.Position(line: 3, column: 1)),
        ("subject: 1\nsubject: 2", Origin.Position(line: 3, column: 1))
    ])
    func refusalsCarryThePosition(written: String, position: Origin.Position) throws {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.parse("name: x\n\(written)")
        }

        // Then
        #expect(error?.position == position)
    }

    @Test("a line ends where YAML ends one, in a position counted here as in one the parse marks", arguments: [
        "\n",
        "\r\n",
        "\r",
        "\u{2028}"
    ])
    func aLineEndsWhereYAMLEndsOne(lineBreak: String) {
        // Given
        let text = "name: x\(lineBreak)subject: é"

        // When. Bytes that are not UTF-8 are refused at a position counted
        // here, and a key written twice at the one the parse marks
        let counted = #expect(throws: AuthoringError.self) {
            try sut.parse(Data(text.utf8) + Data([0xFF]))
        }
        let marked = #expect(throws: AuthoringError.self) {
            try sut.parse("\(text)\(lineBreak)subject: 1")
        }

        // Then
        #expect(counted?.position == Origin.Position(line: 2, column: 11))
        #expect(marked?.position == Origin.Position(line: 3, column: 1))
    }

    @Test("each node stands where the text wrote it, a mapping's entry at its key")
    func eachNodeStandsWhereTheTextWroteIt() throws {
        // Given
        let text = """
        name: greeter
        rounds:
          - 1
          - { inner: true }
        """

        // When
        let parsed = try sut.parse(text)

        // Then
        #expect(parsed.position == Origin.Position(line: 1, column: 1))
        #expect(parsed["name"]?.position == Origin.Position(line: 1, column: 1))
        #expect(parsed["rounds"]?.position == Origin.Position(line: 2, column: 1))
        #expect(parsed["rounds"]?.arrayValue?.map(\.position) == [
            Origin.Position(line: 3, column: 5),
            Origin.Position(line: 4, column: 5)
        ])
        #expect(parsed["rounds"]?.arrayValue?.last?["inner"]?.position == Origin.Position(line: 4, column: 7))
        #expect(parsed["name"]?.isImplicit == false)
    }

    @Test("a text nests at most 128 containers, the text's own mapping the first", arguments: [
        ("[", "]"),
        ("{ a: ", " }")
    ])
    func aTextNestsAtMost128Containers(open: String, close: String) async throws {
        // Given. The 128th container under `a` is the text's 129th, 127
        // openings after the first, at column 4. The YAML parse composes a
        // text 900 deep before the bound is met, which outgrows a test's own
        // thread
        let nested = { @Sendable (depth: Int) in
            "a: " + String(repeating: open, count: depth) + "1" + String(repeating: close, count: depth)
        }
        let parser = sut

        // When
        let deepest = try sut.parse(nested(127))
        let farthest = await onALargeStack { try parser.parse(nested(900)) }
        let refusals = [
            #expect(throws: AuthoringError.self) { try parser.parse(nested(128)) },
            #expect(throws: AuthoringError.self) { try farthest.get() }
        ]

        // Then
        #expect(deepest["a"] != nil)

        for refusal in refusals {
            #expect(refusal?.message == "the text nests deeper than 128 containers")
            #expect(refusal?.position == Origin.Position(line: 1, column: 4 + 127 * open.count))
        }
    }

    // MARK: - Public
    // MARK: - Private
}
