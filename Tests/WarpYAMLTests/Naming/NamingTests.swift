//
//  NamingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Testing
import WarpYAML

// What `name:` does beyond the declarations: a text mentions its own
// declarations short, and the document spells them full.
@Suite("A text names its own declarations short")
struct NamingTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a bare send to the text's own procedure reaches it")
    func aBareSendReachesTheTextsOwn() throws {
        // Given / When
        let document = try sut.document(from: """
        name: Lex
        procedures:
          isDigit:
            parameters: [ of: String ]
            returns: Bool
            result: true
          follows:
            parameters: [ of: String, value: String ]
            returns: Bool
            result: true
          entry:
            parameters: [ ch: String ]
            returns: Bool
            body:
              - let: direct
                value: { call: { procedure: isDigit, arguments: [ { ref: ch } ] } }
              - let: spelled
                value: { of: { ref: ch }, follows: "a" }
            result: { ref: direct }
        """)

        // Then. The call and the operator mapping both reach `Lex.isDigit`
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Lex.entry:
            parameters: [ { name: ch, type: String } ]
            returns: Bool
            body:
              - { let: direct, value: { call: { procedure: Lex.isDigit, arguments: [ { ref: ch } ] } } }
              - { let: spelled, value: { call: { procedure: Lex.follows, arguments: [ { ref: ch }, a ] } } }
              - { value: { return: { ref: direct } } }
          Lex.follows:
            parameters: [ { name: of, type: String }, { name: value, type: String } ]
            returns: Bool
            body: [ { value: { return: true } } ]
          Lex.isDigit:
            parameters: [ { name: of, type: String } ]
            returns: Bool
            body: [ { value: { return: true } } ]
        """)
    }

    @Test("a procedure the text declares is an operator by its name alone")
    func aTextsOwnProcedureAloneIsACall() throws {
        // Given / When. `isDigit` is nobody's operator and the text's own procedure
        let document = try sut.document(from: """
        name: Lex
        procedures:
          isDigit:
            parameters: [ of: String ]
            returns: Bool
            result: true
          entry:
            parameters: [ ch: String ]
            returns: Bool
            result: { isDigit: { ref: ch } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Lex.entry:
            parameters: [ { name: ch, type: String } ]
            returns: Bool
            body: [ { value: { return: { call: { procedure: Lex.isDigit, arguments: [ { ref: ch } ] } } } } ]
          Lex.isDigit:
            parameters: [ { name: of, type: String } ]
            returns: Bool
            body: [ { value: { return: true } } ]
        """)
    }

    @Test("a bare type of the text's own reads as the declared one, wherever a type is written")
    func aBareTypeIsTheTextsOwn() throws {
        // Given / When. A parameter, a return type, an array's element, a cast, a field
        // of another declared type, a claim and a bound
        let document = try sut.document(from: """
        name: Sheet
        types:
          Token:
            struct: { kind: String }
            satisfies: [Piece, Printable]
            procedures:
              line:
                parameters: [ of: Token ]
                returns: String
                result: { ref: of.kind }
          Node:
            struct: { left: Node?, tokens: Array<Token> }
            satisfies: [Piece]
        contracts:
          Printable:
            procedures:
              line: { parameters: [ of: Self ], returns: String }
          Piece: {}
        procedures:
          make:
            parameters: [ kind: String ]
            returns: Token
            result: { as: { of: { struct: { kind: { ref: kind } } }, type: Token } }
          entry:
            parameters: [ held: "some T: Piece" ]
            returns: Array<Token>
            body:
              - let: one
                value: { call: { procedure: make, arguments: [ number ] } }
            result: [ { ref: one } ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Sheet.Node:
            struct:
              left: "Sheet.Node?"
              tokens: "Array<Sheet.Token>"
            satisfies: [ Sheet.Piece ]
          Sheet.Token:
            procedures:
              line:
                parameters: [ { name: of, type: Sheet.Token } ]
                returns: String
                body: [ { value: { return: { ref: of.kind } } } ]
            struct:
              kind: String
            satisfies: [ Sheet.Piece, Sheet.Printable ]
        contracts:
          Sheet.Piece: {}
          Sheet.Printable:
            procedures:
              line: { parameters: [ { name: of, type: Self } ], returns: String }
        procedures:
          Sheet.entry:
            parameters: [ { name: held, type: "some T: Sheet.Piece" } ]
            returns: "Array<Sheet.Token>"
            body:
              - { let: one, value: { call: { procedure: Sheet.make, arguments: [ number ] } } }
              - { value: { return: [ { ref: one } ] } }
          Sheet.make:
            parameters: [ { name: kind, type: String } ]
            returns: Sheet.Token
            body: [ { value: { return: { as: { type: Sheet.Token, of: { struct: { kind: { ref: kind } } } } } } } ]
        """)
    }

    @Test("a procedure the text declares wins over an operator the table spells by that name")
    func theTextsOwnDeclarationShadowsTheTable() throws {
        // Given / When. `count` is an operator of this notation, and this text
        // declares a `count` of its own. Its own is what it means, the way a
        // declaration shadows a library's
        let document = try sut.document(from: """
        name: App
        procedures:
          count:
            parameters: [ of: String ]
            returns: Int
            result: 1
          entry:
            parameters: [ text: String ]
            returns: Int
            result: { of: { ref: text }, count: null }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          App.count:
            parameters: [ { name: of, type: String } ]
            returns: Int
            body: [ { value: { return: 1 } } ]
          App.entry:
            parameters: [ { name: text, type: String } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: App.count, arguments: [ { ref: text }, null ] } } } } ]
        """)
    }

    @Test("an operator's key alone, where the text declares the name too, is refused as two readings")
    func anOperatorKeyAloneWithATextsOwnIsRefused() {
        // Given / When / Then
        #expect {
            try sut.document(from: """
            name: App
            procedures:
              count:
                parameters: [ of: String ]
                returns: Int
                result: 1
              entry:
                parameters: [ text: String ]
                returns: Int
                result: { count: { ref: text } }
            """)
        } throws: { error in
            "\(error)".contains("alone is this notation's operator")
        }
    }

    @Test("a text that writes no name still means its own declaration by an operator's key")
    func aTextWithoutANameStillDeclares() throws {
        // Given / When. No `name:`, and a `count` of the text's own
        let document = try sut.document(from: """
        procedures:
          count:
            parameters: [ of: String ]
            returns: Int
            result: 1
          entry:
            parameters: [ text: String ]
            returns: Int
            result: { of: { ref: text }, count: null }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          count:
            parameters: [ { name: of, type: String } ]
            returns: Int
            body: [ { value: { return: 1 } } ]
          entry:
            parameters: [ { name: text, type: String } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: count, arguments: [ { ref: text }, null ] } } } } ]
        """)
    }

    @Test("a declaration named like a spelling with a form of its own is reached by its full name", arguments: [
        ("present", "{ present: { ref: x } }"),
        ("one_of", "{ of: { ref: x }, one_of: [1, 2] }")
    ])
    func aStructuralSpellingIsNotShadowed(declared: String, written: String) {
        // Given / When / Then. `present` is `x` against null and `one_of` is a
        // flipped send, forms this notation gives the key; a text's own does
        // not take the key over, with `of` or without it
        #expect {
            try sut.document(from: """
            name: App
            procedures:
              \(declared):
                parameters: [ a: Int, b: Int ]
                returns: Bool
                result: true
              entry:
                parameters: [ x: Int ]
                returns: Bool
                result: \(written)
            """)
        } throws: { error in
            "\(error)".contains("Write the declared 'App.\(declared)' by its full name")
        }
    }

    @Test("a name is read in the space it stands in")
    func aNameIsReadInItsSpace() throws {
        // Given / When. The text declares a type called `count` and no procedure by
        // that name, so `count` in a call is the operator and not the type
        let document = try sut.document(from: """
        name: App
        types:
          count: { struct: { n: Int } }
        procedures:
          entry:
            parameters: [ items: Array<String> ]
            returns: Int
            result: { count: { ref: items } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.count ]
        types:
          App.count:
            struct:
              "n": Int
        procedures:
          App.entry:
            parameters: [ { name: items, type: "Array<String>" } ]
            returns: Int
            body:
              - value: { return: { call: { procedure: Standard.Collection.count, arguments: [ { ref: items } ] } } }
        """)
    }

    @Test("a member of one of the text's types is reached by the type's short name and its own")
    func aMemberIsTheTextsOwn() throws {
        // Given / When
        let document = try sut.document(from: """
        name: Sheet
        types:
          Token:
            struct: { kind: String }
            procedures:
              kind:
                parameters: [ of: Token ]
                returns: String
                result: { ref: of.kind }
        procedures:
          entry:
            parameters: [ held: Token ]
            returns: String
            result: { call: { procedure: Token.kind, arguments: [ { ref: held } ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Sheet.Token:
            procedures:
              kind:
                parameters: [ { name: of, type: Sheet.Token } ]
                returns: String
                body: [ { value: { return: { ref: of.kind } } } ]
            struct:
              kind: String
        procedures:
          Sheet.entry:
            parameters: [ { name: held, type: Sheet.Token } ]
            returns: String
            body: [ { value: { return: { call: { procedure: Sheet.Token.kind, arguments: [ { ref: held } ] } } } } ]
        """)
    }

    @Test("a member an extension gives one of the text's types shadows a leaned-on member of its short name")
    func anExtendedMemberShadowsWhatTheTextLeansOn() throws {
        // Given
        let library = """
        name: Lib
        types:
          Account:
            struct: { cents: Int }
            procedures:
              audit: { access: public, parameters: [ of: Account ], returns: Int, result: 0 }
        """
        let sut = try sut.leaning(on: [.text(library)])

        // When
        let document = try sut.document(from: """
        name: Bank
        types:
          Account: { struct: { cents: Int } }
        extensions:
          Account:
            procedures:
              audit: { parameters: [ of: Account ], returns: Int, result: { ref: of.cents } }
        procedures:
          entry:
            parameters: [ held: Account ]
            returns: Int
            result: { call: { procedure: Account.audit, arguments: [ { ref: held } ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Bank.Account:
            struct:
              cents: Int
        extensions:
          Bank.Account:
            procedures:
              audit:
                parameters: [ { name: of, type: Bank.Account } ]
                returns: Int
                body: [ { value: { return: { ref: of.cents } } } ]
        procedures:
          Bank.entry:
            parameters: [ { name: held, type: Bank.Account } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.Account.audit, arguments: [ { ref: held } ] } } } } ]
        """)
    }

    @Test("a member an extension under an applied head gives one of the text's types shadows a leaned-on member of its short name")
    func anExtendedMemberUnderAnAppliedHeadShadowsWhatTheTextLeansOn() throws {
        // Given
        let library = """
        name: Lib
        types:
          Box:
            typeParameters: [ T ]
            struct: { item: some T }
            procedures:
              audit: { access: public, returns: Int, result: 0 }
        """
        let sut = try sut.leaning(on: [.text(library)])

        // When
        let document = try sut.document(from: """
        name: Bank
        types:
          Box: { typeParameters: [ T ], struct: { item: some T } }
        extensions:
          Box<Int>:
            procedures:
              audit: { parameters: [ of: Box<Int> ], returns: Int, result: { ref: of.item } }
        procedures:
          entry:
            parameters: [ held: Box<Int> ]
            returns: Int
            result: { call: { procedure: Box.audit, arguments: [ { ref: held } ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Bank.Box:
            typeParameters: [ T ]
            struct:
              item: some T
        extensions:
          Bank.Box<Int>:
            procedures:
              audit:
                parameters: [ { name: of, type: "Bank.Box<Int>" } ]
                returns: Int
                body: [ { value: { return: { ref: of.item } } } ]
        procedures:
          Bank.entry:
            parameters: [ { name: held, type: "Bank.Box<Int>" } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.Box.audit, arguments: [ { ref: held } ] } } } } ]
        """)
    }

    @Test("a procedure of one of the text's contracts is reached by the contract's short name and its own")
    func aContractsProcedureIsTheTextsOwn() throws {
        // Given / When
        let document = try sut.document(from: """
        name: App
        contracts:
          Shape:
            procedures:
              area: { parameters: [ of: Self ], returns: Int }
        types:
          Square:
            struct: { side: Int }
            satisfies: [ Shape ]
            procedures:
              area:
                parameters: [ of: Square ]
                returns: Int
                result: { ref: of.side }
        procedures:
          entry:
            parameters: [ held: Square ]
            returns: Int
            result: { call: { procedure: Shape.area, arguments: [ { ref: held } ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          App.Square:
            procedures:
              area:
                parameters: [ { name: of, type: App.Square } ]
                returns: Int
                body: [ { value: { return: { ref: of.side } } } ]
            struct:
              side: Int
            satisfies: [ App.Shape ]
        contracts:
          App.Shape:
            procedures:
              area: { parameters: [ { name: of, type: Self } ], returns: Int }
        procedures:
          App.entry:
            parameters: [ { name: held, type: App.Square } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: App.Shape.area, arguments: [ { ref: held } ] } } } } ]
        """)
    }

    @Test("a contract claimed short and full under one type is written full twice, and the load refuses the second")
    func aContractClaimedTwiceIsWrittenTwice() throws {
        // Given
        let text = """
        name: Sheet
        types:
          Token:
            struct: { kind: String }
            satisfies: [Printable, Sheet.Printable]
            procedures:
              line:
                parameters: [ of: Token ]
                returns: String
                result: { ref: of.kind }
        contracts:
          Printable:
            procedures:
              line: { parameters: [ of: Self ], returns: String }
        """

        // When / Then
        try expectDocument(try sut.document(from: text), is: """
        warp: 1
        imports: []
        types:
          Sheet.Token:
            procedures:
              line:
                parameters: [ { name: of, type: Sheet.Token } ]
                returns: String
                body: [ { value: { return: { ref: of.kind } } } ]
            struct:
              kind: String
            satisfies: [ Sheet.Printable, Sheet.Printable ]
        contracts:
          Sheet.Printable:
            procedures:
              line: { parameters: [ { name: of, type: Self } ], returns: String }
        """)
    }

    @Test("a place under satisfies is followed back to the key the text wrote")
    func aClaimIsFollowedBackToTheText() throws {
        // Given
        let text = """
        name: Sheet
        contracts:
          Printable:
            procedures:
              line: { parameters: [ of: Self ], returns: String }
        types:
          Token:
            struct: { kind: String }
            satisfies: [Printable]
            procedures:
              line:
                parameters: [ of: Token ]
                returns: String
                result: { ref: of.kind }
        """

        // When. The document names the claim by the full type, under the
        // struct's declaration
        let reading = try sut.document(from: text).origin.reading(["types", "Sheet.Token", "satisfies"])

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 9)
    }

    @Test("a key the text wrote full is followed back as it was written")
    func aFullKeyIsFollowedBackAsWritten() throws {
        // Given. `Bank.audit` is written full under `name: Bank`, and stays
        // so; a place naming it points at the key the text wrote and not at
        // a short one it never did
        let text = """
        name: Bank
        procedures:
          Bank.audit:
            result: 1
          entry:
            result: 2
        """

        // When
        let reading = try sut.document(from: text).origin.reading(["procedures", "Bank.audit"])

        // Then
        #expect(reading.exact)
        #expect(reading.position.line == 3)
    }

    @Test("a declaration written short and full is refused where it was written")
    func aDeclarationWrittenTwiceIsRefusedWithItsPlace() {
        // Given / When / Then
        #expect {
            try sut.document(from: """
            name: Bank
            types:
              Account: { struct: { n: Int } }
              Bank.Account: { struct: { n: Int } }
            procedures:
              entry:
                result: 1
            """)
        } throws: { error in
            guard let position = (error as? AuthoringError)?.position else { return false }

            return "\(error)".contains("once short and once full") && position.line == 4
        }
    }

    @Test("one type extended under two spellings is refused, not read twice")
    func aTypeExtendedTwiceIsRefused() {
        // Given / When / Then
        #expect {
            try sut.document(from: """
            name: Sheet
            types:
              Token: { struct: { kind: String } }
            contracts:
              Printable:
                procedures:
                  line: { parameters: [ of: Self ], returns: String }
            extensions:
              Token: { satisfies: [Printable] }
              Sheet.Token: { satisfies: [Printable] }
            """)
        } throws: { error in
            "\(error)".contains("twice")
        }
    }

    @Test("an extension under a head applying one of the text's types reads it full, and is followed back to the key the text wrote")
    func aHeadOnTheTextsOwnTypeIsTheTextsOwn() throws {
        // Given. `Box` is the text's own type, applied in the head to what
        // conforms to `Hashable`
        let text = """
        name: Sheet
        types:
          Box: { struct: { item: some T }, typeParameters: [T] }
        contracts:
          Printable:
            procedures:
              line: { parameters: [ of: Self ], returns: String }
        extensions:
          "Box<some T: Hashable>":
            satisfies: [Printable]
            procedures:
              line:
                parameters: [ of: Box<some T> ]
                returns: String
                result: box
        """

        // When
        let document = try sut.document(from: text)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Sheet.Box:
            struct:
              item: "some T"
            typeParameters: [ T ]
        contracts:
          Sheet.Printable:
            procedures:
              line: { parameters: [ { name: of, type: Self } ], returns: String }
        extensions:
          "Sheet.Box<some T: Hashable>":
            procedures:
              line:
                parameters: [ { name: of, type: "Sheet.Box<some T>" } ]
                returns: String
                body: [ { value: { return: box } } ]
            satisfies: [ Sheet.Printable ]
        """)

        let reading = document.origin.reading(["extensions", "Sheet.Box<some T: Hashable>", "satisfies"])

        #expect(reading.exact)
        #expect(reading.position.line == 10)
    }

    @Test("a struct literal's field is data, whatever it is called")
    func aDataStructIsData() throws {
        // Given / When. `type` is a field of this struct and `Token` its value, and
        // neither is a type slot: what is a type is the reader's to know, not
        // a key's name to guess
        let document = try sut.document(from: """
        name: Sheet
        types:
          Token: { struct: { kind: String } }
        procedures:
          entry:
            returns: String
            body:
              - let: described
                value: { struct: { kind: number, type: Token } }
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: Token
                    body: []
            parameters: [ names: Array<String> ]
            result: { ref: described.type }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.count, Standard.Comparable.lessThan ]
        types:
          Sheet.Token:
            struct:
              kind: String
        procedures:
          Sheet.entry:
            parameters: [ { name: names, type: "Array<String>" } ]
            returns: String
            body:
              - { let: described, value: { struct: { type: Token, kind: number } } }
              - value:
                  conditional:
                    then:
                      - { let: Token, value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            body: [ { let: Token, value: { ref: "Token[walk.index]" } } ]
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: Token } ] } }
                    when: true
              - { value: { return: { ref: described.type } } }
        """)
    }

    @Test("a dotted declaration on the text's own type is mentioned the way it is declared", arguments: [
        ("name: Flow", "Flow."),
        ("", "")
    ])
    func aDottedDeclarationIsMentionedAsDeclared(named: String, prefix: String) throws {
        // Given. `Fetch.parse` takes the prefix because `Fetch` is the
        // text's own type, so a call to it and its operator read full too
        let document = try sut.document(from: """
        \(named)
        types:
          Fetch: { struct: { url: String } }
        procedures:
          Fetch.parse:
            parameters: [ of: String ]
            returns: String
            result: { ref: of }
          entry:
            access: public
            parameters: [ url: String ]
            returns: String
            body:
              - let: called
                value: { call: { procedure: Fetch.parse, arguments: [ { ref: url } ] } }
              - let: spelled
                value: { Fetch.parse: { ref: called } }
            result: { ref: spelled }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          \(prefix)Fetch: { struct: { url: String } }
        procedures:
          \(prefix)Fetch.parse:
            parameters: [ { name: of, type: String } ]
            returns: String
            body: [ { value: { return: { ref: of } } } ]
          \(prefix)entry:
            access: public
            parameters: [ { name: url, type: String } ]
            returns: String
            body:
              - { let: called, value: { call: { procedure: \(prefix)Fetch.parse, arguments: [ { ref: url } ] } } }
              - { let: spelled, value: { call: { procedure: \(prefix)Fetch.parse, arguments: [ { ref: called } ] } } }
              - { value: { return: { ref: spelled } } }
        """)
    }

    @Test("a name the text does not declare is left as written")
    func anUndeclaredNameIsLeftAlone() throws {
        // Given / When. `count` is a procedure the text never declared, and
        // `Array<Int>` names nothing of the text's
        let document = try sut.document(from: """
        name: App
        procedures:
          entry:
            parameters: [ items: Array<Int> ]
            returns: Int
            result: { call: { procedure: Standard.Collection.count, arguments: [ { ref: items } ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.count ]
        procedures:
          App.entry:
            parameters: [ { name: items, type: "Array<Int>" } ]
            returns: Int
            body:
              - value: { return: { call: { procedure: Standard.Collection.count, arguments: [ { ref: items } ] } } }
        """)
    }

    // MARK: - Public
    // MARK: - Private
    // What a procedure's body returns last, as the document writes it.
}
