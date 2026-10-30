//
//  ShortNameTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/24/26.
//

import Foundation
import Testing
import WarpYAML

// A text names what it leans on short: the declarations of `Standard` and of
// the texts and interfaces its caller hands, after its own.
@Suite("A text names what it leans on by short names")
struct ShortNameTests {
    // MARK: - Property
    // A document another text leans on: a type with a member, a procedure,
    // and a private procedure.
    private static let library = """
    name: Lib
    types:
      Card:
        struct: { title: String }
        procedures:
          describe:
            parameters: [ of: Card ]
            returns: String
            result: { ref: of.title }
    procedures:
      shout:
        parameters: [ of: String ]
        returns: String
        result: { uppercased: { ref: of } }
      hidden:
        access: private
        returns: Int
        result: 1
    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a leaned-on procedure, type and member are read full by their short names")
    func aLeanedOnDeclarationIsReadFull() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [Self.library])

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          entry:
            parameters: [ card: Card ]
            returns: String
            body:
              - let: title
                value: { call: { procedure: Card.describe, arguments: [ { ref: card } ] } }
            result: { shout: { ref: title } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.Card, Lib.Card.describe, Lib.shout ]
        procedures:
          App.entry:
            parameters: [ { name: card, type: Lib.Card } ]
            returns: String
            body:
              - { let: title, value: { call: { procedure: Lib.Card.describe, arguments: [ { ref: card } ] } } }
              - { value: { return: { call: { procedure: Lib.shout, arguments: [ { ref: title } ] } } } }
        """)
    }

    @Test("a declaration of the text's own is read before one it leans on, without a refusal")
    func theTextsOwnShadowsALeanedOnOne() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [Self.library])

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          shout:
            parameters: [ of: String ]
            returns: String
            result: { ref: of }
          entry:
            returns: String
            result: { shout: hello }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          App.entry:
            returns: String
            body: [ { value: { return: { call: { procedure: App.shout, arguments: [ hello ] } } } } ]
          App.shout:
            parameters: [ { name: of, type: String } ]
            returns: String
            body: [ { value: { return: { ref: of } } } ]
        """)
    }

    @Test("a short name two leaned-on declarations share is refused where it is written")
    func twoLeanedOnDeclarationsRefuse() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [
            Self.library,
            """
            name: Other
            procedures:
              shout:
                parameters: [ of: String ]
                returns: String
                result: { ref: of }
            """
        ])

        // When
        var refusal: AuthoringError?

        do {
            _ = try sut.document(from: """
            name: App
            procedures:
              entry:
                returns: String
                body:
                  - let: said
                    value: { call: { procedure: shout, arguments: [ hello ] } }
                result: { ref: said }
            """)
        } catch let error as AuthoringError {
            refusal = error
        }

        // Then
        #expect(refusal?.message == "'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full")

        guard let position = refusal?.position else {
            Issue.record("the refusal stands at the call's procedure")

            return
        }

        #expect(position == Origin.Position(line: 7, column: 26))
    }

    @Test("an operator key two leaned-on declarations share is refused as the name", arguments: [
        "{ shout: hello }",
        "{ of: hello, shout: null }"
    ])
    func anOperatorKeyTwoDeclarationsShareRefuses(written: String) throws {
        // Given
        let sut = try Self.frontend(leaningOn: [
            Self.library,
            "name: Other\nprocedures:\n  shout:\n    parameters: [ of: String ]\n    returns: String\n    result: { ref: of }"
        ])

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                returns: String
                result: \(written)
            """)
        } throws: { error in
            guard let position = (error as? AuthoringError)?.position else { return false }

            return (error as? AuthoringError)?.message
                == "'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full"
                && position.line == 4
        }
    }

    @Test("std's declarations are leaned on by every text, and its shared short names refuse", arguments: [
        ("contains", "'contains' is declared by Standard.Collection.contains and Standard.Text.contains"),
        ("first", "'first' is declared by Standard.Collection.first and Standard.Concurrent.first"),
        ("map", "'map' is declared by Standard.Collection.map and Standard.Concurrent.map")
    ])
    func stdsSharedShortNamesRefuse(name: String, message: String) throws {
        // Given
        let sut = try YAMLFrontend()

        // When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                body:
                  - value: { call: { procedure: \(name), arguments: [ [1], 1 ] } }
            """)
        } throws: { error in
            (error as? AuthoringError)?.message == "\(message). Write the one you mean in full"
        }
    }

    @Test("an operator key whose declared name is the procedure the table spells is one reading")
    func anOperatorKeyOfStdIsOneReading() throws {
        // Given. `count` is std's `Standard.Collection.count` and the table's
        // operator alike, and `contains` is two of std's, so the table's
        let sut = try YAMLFrontend()

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            parameters: [ xs: Array<Int> ]
            returns: Bool
            body:
              - let: n
                value: { count: { ref: xs } }
            result: { of: { ref: xs }, contains: { ref: n } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.contains, Standard.Collection.count ]
        procedures:
          entry:
            parameters: [ { name: xs, type: "Array<Int>" } ]
            returns: Bool
            body:
              - { let: "n", value: { call: { procedure: Standard.Collection.count, arguments: [ { ref: xs } ] } } }
              - value:
                  return:
                    call: { procedure: Standard.Collection.contains, arguments: [ { ref: xs }, { ref: "n" } ] }
        """)
    }

    @Test("a contract in a bound is read by its short name")
    func aContractInABoundIsReadFull() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let document = try sut.document(from: """
        procedures:
          smaller:
            parameters: [ a: "some T: Comparable", b: some T ]
            returns: Bool
            result: { of: { ref: a }, less_than: { ref: b } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Comparable, Standard.Comparable.lessThan ]
        procedures:
          smaller:
            parameters: [ { name: a, type: "some T: Standard.Comparable" }, { name: b, type: "some T" } ]
            returns: Bool
            body:
              - value:
                  return: { call: { procedure: Standard.Comparable.lessThan, arguments: [ { ref: a }, { ref: b } ] } }
        """)
    }

    @Test("a leaned-on document is reached by its full names as well")
    func aFullNameReachesALeanedOnDocument() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [Self.library])

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: String
            result: { call: { procedure: Lib.shout, arguments: [ hello ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.shout ]
        procedures:
          entry:
            returns: String
            body: [ { value: { return: { call: { procedure: Lib.shout, arguments: [ hello ] } } } } ]
        """)
    }

    @Test("a full name a text writes stays that name where another declaration's short name is the same")
    func aFullNameStaysBesideAnEqualShortName() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [
            """
            name: Lib
            procedures:
              say:
                parameters: [ of: {} ]
                returns: String
                result: A
            """,
            """
            name: App2
            types:
              Lib:
                struct: { tag: String }
                procedures:
                  say:
                    parameters: [ of: Lib ]
                    returns: String
                    result: B
            """
        ])

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: String
            result: { call: { procedure: Lib.say, arguments: [ x ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.say ]
        procedures:
          entry:
            returns: String
            body: [ { value: { return: { call: { procedure: Lib.say, arguments: [ x ] } } } } ]
        """)
    }

    @Test("a full name with no prefix stays that name beside a short name it equals")
    func anUnprefixedFullNameStays() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [
            Self.library,
            """
            procedures:
              shout:
                parameters: [ of: String ]
                returns: String
                result: { ref: of }
            """
        ])

        // When
        let document = try sut.document(from: """
        name: App
        procedures:
          entry:
            returns: String
            result: { call: { procedure: shout, arguments: [ hello ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ shout ]
        procedures:
          App.entry:
            returns: String
            body: [ { value: { return: { call: { procedure: shout, arguments: [ hello ] } } } } ]
        """)
    }

    @Test("a private procedure is its document's, and has no short name")
    func aPrivateProcedureHasNoShortName() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [Self.library])

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: Int
            body:
              - let: n
                value: { call: { procedure: hidden } }
            result: { ref: n }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ hidden ]
        procedures:
          entry:
            returns: Int
            body: [ { let: "n", value: { call: { procedure: hidden } } }, { value: { return: { ref: "n" } } } ]
        """)
    }

    @Test("a host's interface is leaned on, and a call by name into it is matched by its signature")
    func aHostsInterfaceIsLeanedOn() throws {
        // Given
        let sut = try YAMLFrontend().leaning(on: [
            .interface(
                Data(
                    """
                    (interface 1)
                    (procedure Host.fetch
                      (parameter url (type String))
                      (parameter timeout (type (optional Int)))
                      (returns String))
                    """.utf8
                )
            )
        ])

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: String
            result: { call: { procedure: fetch, arguments: { url: example } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Host.fetch ]
        procedures:
          entry:
            returns: String
            body: [ { value: { return: { call: { procedure: Host.fetch, arguments: [ example, null ] } } } } ]
        """)
    }

    @Test("a leaned-on interface that does not read is refused where it is leaned on")
    func anInterfaceThatDoesNotReadIsRefused() throws {
        // Given
        let sut = try YAMLFrontend()

        // When / Then
        #expect(throws: (any Error).self) { try sut.leaning(on: [.interface(Data("(warp 1)".utf8))]) }
    }

    @Test("an origin reads the document as it was spent against what the text leans on")
    func anOriginReadsTheSameTable() throws {
        // Given
        let sut = try Self.frontend(leaningOn: [Self.library])
        let text = """
        procedures:
          entry:
            returns: String
            result: { shout: hello }
        """

        // When. The leaned-on `shout` is a call, and its argument is what
        // the text wrote under the key
        let reading = try sut.document(from: text).origin.reading(
            ["procedures", "entry", "body", 0, "value", "return", "call", "arguments", 0]
        )

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 4)
    }

    // MARK: - Public
    // MARK: - Private
    private static func frontend(leaningOn texts: [String]) throws -> YAMLFrontend {
        try YAMLFrontend().leaning(on: texts.map(Dependency.text))
    }
}
