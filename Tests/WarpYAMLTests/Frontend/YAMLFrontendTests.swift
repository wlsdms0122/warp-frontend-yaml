//
//  YAMLFrontendTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 8/21/26.
//

import Foundation
import Testing
import WarpYAML

// What a person wrote becomes a document's bytes, compared here with a
// document written by hand. What a document does once it is loaded, built
// and run is the IR's, judged by whoever loads it.
@Suite("The YAML front end")
struct YAMLFrontendTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("what a person wrote becomes a document, from text or from bytes")
    func textBecomesADocument() throws {
        // Given
        let written = """
        name: Greeter
        procedures:
          greet:
            body:
              - let: said
                value: hello
            result: { ref: said }
        """

        // When
        let fromText = try sut.document(from: written)
        let fromData = try sut.document(from: Data(written.utf8))

        // Then. The same text is the same document
        #expect(fromText.document == fromData.document)
        try expectDocument(fromText, is: """
        warp: 1
        imports: []
        procedures:
          Greeter.greet:
            body: [ { let: said, value: hello }, { value: { return: { ref: said } } } ]
        """)
    }

    @Test("a name is a prefix on what the text declares, and reaches no key")
    func aNameIsAPrefixAndNotAKey() throws {
        // Given / When
        let document = try sut.document(from: """
        name: Bank
        types:
          Account: { struct: { balance: Int } }
        procedures:
          transfer:
            parameters:
              - to: Bank.Account
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Bank.Account:
            struct:
              balance: Int
        procedures:
          Bank.transfer:
            parameters: [ { name: to, type: Bank.Account } ]
        """)
    }

    @Test("a name that is not identifiers joined by dots is refused as a name")
    func aWrongNameIsRefusedAsOne() throws {
        // Given / When / Then. A prefix stands in front of a dot, so `Int` is
        // one: `Int.Point` is a type's name
        #expect(throws: Never.self) {
            try sut.document(from: "name: Int\ntypes: { Point: { struct: { x: Int } } }\nprocedures: { entry: {} }\n")
        }

        for text in [
            "name: \"\"\nprocedures: { entry: {} }\n",
            "name: 3\nprocedures: { entry: {} }\n",
            "name: 은행\nprocedures: { entry: {} }\n"
        ] {
            #expect("\(text)") {
                try sut.document(from: text)
            } throws: { error in
                "\(error)".contains("a name is identifiers joined by dots")
            }
        }
    }

    @Test("every spelling is spent before the document leaves")
    func everySpellingIsSpent() throws {
        // Given / When. `is` and a template: the two kinds of sugar this
        // notation offers
        let document = try sut.document(from: """
        procedures:
          entry:
            parameters:
              - procedure: String
            body:
              - var: pick
              - value:
                  conditional:
                    when: { of: { ref: procedure }, is: hey }
                    then:
                      - set: pick
                        value: yes
                    else:
                      - set: pick
                        value: no
              - let: line
                value: { format: "${procedure}!", with: { procedure: { ref: procedure } } }
            result: { ref: line }
        """)

        // Then. The document holds the calls they stand for, and none of the
        // spelled keys
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Logic.equal, Standard.Text.joined, Standard.Text.text ]
        procedures:
          entry:
            parameters: [ { name: procedure, type: String } ]
            body:
              - { var: pick }
              - value:
                  conditional:
                    else: [ { set: pick, value: "no" } ]
                    then: [ { set: pick, value: "yes" } ]
                    when: { call: { procedure: Standard.Logic.equal, arguments: [ { ref: procedure }, hey ] } }
              - let: line
                value:
                  call:
                    procedure: Standard.Text.joined
                    arguments:
                      - [ { call: { procedure: Standard.Text.text, arguments: [ { ref: procedure } ] } }, "!" ]
                      - ""
              - { value: { return: { ref: line } } }
        """)
    }

    @Test("a procedure's result is spent into a return after the body's last statement")
    func aResultIsSpentIntoATrailingReturn() throws {
        // Given / When. One `result:` after a body, one with no body that
        // carries nothing
        let document = try sut.document(from: """
        procedures:
          counted:
            returns: Int
            body:
              - let: n
                value: 1
            result: { ref: n }
          nothing:
            result: null
        """)

        // Then. Each body ends in the `return` its `result:` named, and the
        // document holds no `result`
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          counted:
            returns: Int
            body: [ { let: "n", value: 1 }, { value: { return: { ref: "n" } } } ]
          nothing:
            body: [ { value: { return: null } } ]
        """)
    }

    @Test("data named like this notation's own constructs is written as data")
    func dataNamedLikeAConstructTravels() throws {
        // Given / When. `each` is a key this front end reads as a construct,
        // and here a struct's field
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: Int
            body:
              - let: held
                value: { struct: { value: { struct: { each: 1 } } } }
            result: { ref: held.each }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            returns: Int
            body:
              - { let: held, value: { struct: { value: { struct: { each: 1 } } } } }
              - { value: { return: { ref: held.each } } }
        """)
    }

    @Test("the document says what it imports, because the front end computed it")
    func theDocumentCarriesItsImportsList() throws {
        // Given / When. An author does not write the imports list; a front end
        // owes one. `plus` is std's, read full
        let document = try sut.document(from: """
        procedures:
          entry:
            body:
              - let: sum
                value: { call: { procedure: plus, arguments: [ 1, 2 ] } }
            result: { ref: sum }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Numeric.plus ]
        procedures:
          entry:
            body:
              - { let: sum, value: { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } } }
              - { value: { return: { ref: sum } } }
        """)
    }

    @Test("a claim the author imports is kept, and the names beside it are computed")
    func anImportedClaimIsKept() throws {
        // Given / When. The author writes the one thing a front end cannot
        // work out, a claim another document makes, and nothing else
        let document = try sut.document(from: """
        imports: [ "T.Card: App.Describable" ]
        procedures:
          entry:
            body:
              - let: sum
                value: { call: { procedure: plus, arguments: [ 1, 2 ] } }
            result: { ref: sum }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Numeric.plus, "T.Card: App.Describable" ]
        procedures:
          entry:
            body:
              - { let: sum, value: { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } } }
              - { value: { return: { ref: sum } } }
        """)
    }

    @Test("a contract's types, a type's type members and a signature's same types read under the text's name")
    func associatedTypesReadUnderTheName() throws {
        // Given / When. The type a contract asks and the type member giving it
        // are names of their own, and only what the text declares takes the
        // prefix
        let document = try sut.document(from: """
        name: Lib
        contracts:
          Container:
            types: [ Item ]
            procedures:
              first: { parameters: [ of: Self ], returns: Self.Item }
        types:
          Box:
            struct: { item: some T }
            typeParameters: [ T ]
            satisfies: [ Container ]
            types: { Item: some T }
            procedures:
              first: { parameters: [ of: Box<some T> ], returns: some T, result: { ref: of.item } }
        procedures:
          plusOne:
            sameTypes: { C.Item: Int }
            parameters: [ c: "some C: Container" ]
            returns: some C.Item
            result: 1
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          Lib.Box:
            types:
              Item: "some T"
            procedures:
              first:
                parameters: [ { name: of, type: "Lib.Box<some T>" } ]
                returns: "some T"
                body: [ { value: { return: { ref: of.item } } } ]
            struct:
              item: "some T"
            satisfies: [ Lib.Container ]
            typeParameters: [ T ]
        contracts:
          Lib.Container:
            types: [ Item ]
            procedures:
              first: { parameters: [ { name: of, type: Self } ], returns: Self.Item }
        procedures:
          Lib.plusOne:
            sameTypes:
              C.Item: Int
            parameters: [ { name: c, type: "some C: Lib.Container" } ]
            returns: "some C.Item"
            body: [ { value: { return: 1 } } ]
        """)
    }

    @Test("a declaration whose key is no name is written through, for the load to refuse")
    func aDeclarationKeyThatIsNoNameIsTheLoads() throws {
        // Given / When
        let document = try sut.document(from: "procedures:\n  \"\": { returns: Int, result: 1 }\n")

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          "": { returns: Int, body: [ { value: { return: 1 } } ] }
        """)
    }

    @Test("a version the author wrote is the author's")
    func theAuthorsOwnVersionIsKept() throws {
        // Given / When. An author who wrote the number keeps it, rather than
        // having it replaced by the one this front end targets; the load
        // refuses a version it does not read
        let document = try sut.document(from: """
        warp: 9999
        procedures:
          entry:
            result: hello
        """)

        // Then
        try expectDocument(document, is: """
        warp: 9999
        imports: []
        procedures:
          entry:
            body: [ { value: { return: hello } } ]
        """)

        // And the one this front end targets is the one it would have written
        #expect(
            try sut.document(from: "warp: 1\nprocedures:\n  entry:\n    result: hello\n").document
                == (try sut.document(from: "procedures:\n  entry:\n    result: hello\n").document)
        )
    }

    @Test("a program the load refuses is written as the text writes it")
    func aProgramTheLoadRefusesIsWrittenThrough() throws {
        // Given / When. `some Int` names no type parameter; the load refuses it
        let document = try sut.document(from: """
        name: Empty
        procedures: { entry: { parameters: [{ name: x, type: some Int }] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Empty.entry:
            parameters: [ { name: x, type: "some Int" } ]
        """)
    }

    @Test("a try's result is no spelling, and is written as the key the load refuses")
    func aTrysResultIsWrittenThrough() throws {
        // Given / When. What a try keeps is written to a variable by a `set`,
        // and a spelling of `result:` would declare a name the text never
        // wrote
        let document = try sut.document(from: """
        procedures:
          entry:
            body:
              - value:
                  try:
                    body: [{ let: n, value: 1 }]
                    result: { ref: n }
                    catch: [{ let: m, value: 2 }]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body:
              - value:
                  try: { body: [ { let: "n", value: 1 } ], catch: [ { let: m, value: 2 } ], result: { ref: "n" } }
        """)
    }

    @Test("a loop with no while is the document's loop that does not finish")
    func aLoopWithNoWhileDoesNotFinish() throws {
        // Given / When. A loop with no `while:` is written the way the
        // document writes it, and declares that it does not finish
        let document = try sut.document(from: """
        name: Serve
        procedures:
          entry:
            returns: Never
            body:
              - value:
                  loop:
                    body: [{ value: 1 }]
        """)

        // Then. The document holds the loop with no condition
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Serve.entry:
            returns: Never
            body: [ { value: { loop: { body: [ { value: 1 } ] } } } ]
        """)
    }

    @Test("an unwrap with no then is the document's unwrap, its payload named after it")
    func anUnwrapWithNoThenBindsAfterIt() throws {
        // Given / When. An unwrap is written the way the document writes it,
        // and with no `then:` its name holds the payload past it
        let document = try sut.document(from: """
        name: Find
        procedures:
          entry:
            parameters: [ found: Int? ]
            returns: Int
            body:
              - let: card
                value:
                  unwrap:
                    of: { ref: found }
                    else: [{ value: { return: 0 } }]
            result: { ref: card }
        """)

        // Then. The document holds the unwrap with no `then`, under the name
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Find.entry:
            parameters: [ { name: found, type: "Int?" } ]
            returns: Int
            body:
              - { let: card, value: { unwrap: { else: [ { value: { return: 0 } } ], of: { ref: found } } } }
              - { value: { return: { ref: card } } }
        """)
    }

    @Test("text that is not YAML fails as text, before it is anything else")
    func malformedTextFailsEarly() {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try sut.document(from: "procedures: [unclosed")
        }

        // Then
        #expect(error?.position == Origin.Position(line: 2, column: 1))
    }

    @Test("a struct and a dictionary are written the way the document writes them")
    func aStructAndADictionaryAreTheDocumentsForms() throws {
        // Given / When. A struct type under `types` and a struct literal under
        // `struct`, a dictionary literal under `dictionary`, read by brackets
        let document = try sut.document(from: """
        name: Lex
        types:
          Token: { struct: { kind: String, text: String } }
        const:
          digits: { dictionary: [["0", 0], ["1", 1], ["2", 2]] }
        procedures:
          tokens:
            access: public
            parameters: [ of: String ]
            returns: Array<Token>
            failing: [cast_refused]
            body:
              - let: chars
                value: { characters: { ref: of } }
              - var: tokens
                type: Array<Token>
                value: []
              - let: walk
                value:
                  each:
                    of: { ref: chars }
                    as: ch
                    body:
                      - value:
                          cases:
                            - when: { present: { ref: "digits?[ch]" } }
                              then:
                                - set: tokens
                                  value: { of: { ref: tokens }, appending: { as: { of: { struct: { kind: number, text: { ref: ch } } }, type: Token } } }
            result: { ref: tokens }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports:
          - Standard.Collection.appending
          - Standard.Collection.count
          - Standard.Comparable.lessThan
          - Standard.Logic.notEqual
          - Standard.Text.characters
        types:
          Lex.Token:
            struct:
              kind: String
              text: String
        procedures:
          Lex.tokens:
            access: public
            parameters: [ { name: of, type: String } ]
            returns: "Array<Lex.Token>"
            failing: [ cast_refused ]
            body:
              - { let: chars, value: { call: { procedure: Standard.Text.characters, arguments: [ { ref: of } ] } } }
              - { var: tokens, type: "Array<Lex.Token>", value: [] }
              - value:
                  conditional:
                    then:
                      - { let: ch, value: { ref: chars } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: ch, value: { ref: "ch[walk.index]" } }
                              - value:
                                  conditional:
                                    then:
                                      - set: tokens
                                        value:
                                          call:
                                            procedure: Standard.Collection.appending
                                            arguments:
                                              - { ref: tokens }
                                              - as:
                                                  type: Lex.Token
                                                  of: { struct: { kind: number, text: { ref: ch } } }
                                    when:
                                      call:
                                        procedure: Standard.Logic.notEqual
                                        arguments: [ { ref: "digits?[ch]" }, null ]
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: ch } ] } }
                    when: true
              - { value: { return: { ref: tokens } } }
        const:
          digits:
            dictionary: [ [ "0", 0 ], [ "1", 1 ], [ "2", 2 ] ]
        """)
    }

    @Test("a struct taking a type parameter is declared and applied by the names the text writes")
    func aStructTakingATypeParameterIsAppliedByTheTextsNames() throws {
        // Given / When. `Box` lists `T`, and `Box<some T>` and `Box<Int>` name
        // it the way the text declares it
        let document = try sut.document(from: """
        name: App
        types:
          Box: { struct: { item: some T }, typeParameters: [T] }
        procedures:
          wrap:
            parameters: [ x: some T ]
            returns: Box<some T>
            result: { struct: { item: { ref: x } } }
          entry:
            access: public
            returns: Int
            body:
              - let: b
                type: Box<Int>
                value: { call: { procedure: wrap, arguments: [ 3 ] } }
            result: { ref: b.item }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        types:
          App.Box:
            struct:
              item: "some T"
            typeParameters: [ T ]
        procedures:
          App.entry:
            access: public
            returns: Int
            body:
              - { let: b, type: "App.Box<Int>", value: { call: { procedure: App.wrap, arguments: [ 3 ] } } }
              - { value: { return: { ref: b.item } } }
          App.wrap:
            parameters: [ { name: x, type: "some T" } ]
            returns: "App.Box<some T>"
            body: [ { value: { return: { struct: { item: { ref: x } } } } } ]
        """)
    }

    @Test("a mapping written bare is no struct and no dictionary, and is written as the keys the load refuses")
    func aBareMappingIsWrittenThrough() throws {
        // Given / When. Under `types` and where a value is wanted
        let declared = try sut.document(from: "types: { Point: { x: Int } }\nprocedures: { entry: {} }\n")
        let returned = try sut.document(from: "procedures: { entry: { result: { x: 1, y: 2 } } }\n")

        // Then
        try expectDocument(declared, is: """
        warp: 1
        imports: []
        types:
          Point:
            x: Int
        procedures:
          entry: {}
        """)
        try expectDocument(returned, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body: [ { value: { return: { x: 1, "y": 2 } } } ]
        """)
    }

    @Test("what the language spells, a person may write")
    func theLanguagesOwnSpellingsTravel() throws {
        // Given / When. The language's own spellings: an Optional, the asking
        // cast, and the mark that reads past an absence. Each is written as
        // the text writes it
        let document = try sut.document(from: """
        name: Spellings
        procedures:
          entry:
            parameters:
              - payload: Any
              - task: "Dictionary<String, String>?"
            returns: String?
            body:
              - let: opened
                value: { "as?": { of: { ref: payload }, type: Int } }
              - let: named
                value: { ref: "task?.name" }
            result: { ref: named }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Spellings.entry:
            parameters: [ { name: payload }, { name: task, type: "Dictionary<String, String>?" } ]
            returns: "String?"
            body:
              - { let: opened, value: { "as?": { type: Int, of: { ref: payload } } } }
              - { let: named, value: { ref: "task?.name" } }
              - { value: { return: { ref: named } } }
        """)
    }

    @Test("a parameter written as one pair is that pair, whatever it is named")
    func aParameterIsOnePairWhateverItIsNamed() throws {
        // Given / When. `name` and `type` are keys of the struct a document
        // writes, and a pair under either is still the parameter it names
        let document = try sut.document(from: """
        name: Pairs
        procedures:
          entry:
            parameters:
              - name: String
              - type: Int
              - count: {}
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          Pairs.entry:
            parameters: [ { name: name, type: String }, { name: type, type: Int }, { name: count } ]
        """)
    }

    @Test("a pair holds the parameter's type or nothing, and a key written under it is refused", arguments: [
        "count: { type: Int }",
        "count: { name: total }"
    ])
    func aKeyUnderThePairIsRefused(parameter: String) {
        // Given / When / Then
        #expect(throws: AuthoringError.self) {
            try sut.document(from: """
            name: Pairs
            procedures:
              entry:
                parameters:
                  - \(parameter)
            """)
        }
    }

    @Test("texts that lean on each other name each other's declarations short, in any order")
    func textsLeaningOnEachOtherSpend() throws {
        // Given. `Shop` names `Bank`'s type and procedure short, and is handed
        // first
        let texts = [
            """
            name: Shop
            procedures:
              pay:
                access: public
                parameters: [ from: Account ]
                returns: Int
                result: { call: { procedure: balance, arguments: [ { ref: from } ] } }
            """,
            """
            name: Bank
            types:
              Account: { struct: { cents: Int } }
            procedures:
              balance:
                access: public
                parameters: [ of: Account ]
                returns: Int
                result: { ref: of.cents }
            """
        ]

        // When
        let documents = try sut.documents(from: texts)

        // Then
        try expectDocument(documents[0], is: """
        warp: 1
        imports: [ Bank.Account, Bank.balance ]
        procedures:
          Shop.pay:
            access: public
            parameters: [ { name: from, type: Bank.Account } ]
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.balance, arguments: [ { ref: from } ] } } } } ]
        """)
        try expectDocument(documents[1], is: """
        warp: 1
        imports: []
        types:
          Bank.Account:
            struct:
              cents: Int
        procedures:
          Bank.balance:
            access: public
            parameters: [ { name: of, type: Bank.Account } ]
            returns: Int
            body: [ { value: { return: { ref: of.cents } } } ]
        """)
    }

    @Test("two texts sending each other both spend, each importing the other")
    func textsSendingEachOtherBothSpend() throws {
        // Given
        let texts = [
            """
            name: Ping
            procedures:
              ping:
                access: public
                body:
                  - value: { call: { procedure: pong } }
            """,
            """
            name: Pong
            procedures:
              pong:
                access: public
                body:
                  - value: { call: { procedure: ping } }
            """
        ]

        // When
        let documents = try sut.documents(from: texts)

        // Then
        try expectDocument(documents[0], is: """
        warp: 1
        imports: [ Pong.pong ]
        procedures:
          Ping.ping:
            access: public
            body: [ { value: { call: { procedure: Pong.pong } } } ]
        """)
        try expectDocument(documents[1], is: """
        warp: 1
        imports: [ Ping.ping ]
        procedures:
          Pong.pong:
            access: public
            body: [ { value: { call: { procedure: Ping.ping } } } ]
        """)
    }

    @Test("each text spent among others is handed its own origin")
    func aTextAmongOthersHasAnOrigin() throws {
        // Given
        let texts = [
            """
            name: Bank
            types:
              Account: { struct: { cents: Int } }
            """,
            """
            name: Shop
            procedures:
              pay:
                parameters: [ from: Account ]
                returns: Int
                result: { ref: from.cents }
            """
        ]

        // When
        let documents = try sut.documents(from: texts)
        let account = documents[0].origin.reading(["types", "Bank.Account"])
        let parameter = documents[1].origin.reading(["procedures", "Shop.pay", "parameters", 0, "type"])
        let elsewhere = documents[0].origin.reading(["procedures", "Shop.pay"])

        // Then. Each reads its own text, and `Shop.pay` is no step of Bank's
        #expect(account.exact)
        #expect(account.position.line == 3)
        #expect(parameter.exact)
        #expect(parameter.position.line == 4)
        #expect(elsewhere.exact == false)
        #expect(elsewhere.followed == 0)
        #expect(elsewhere.position.line == 1)
    }

    @Test("a refusal among texts spent together says which text it stands in", arguments: [
        ("procedures:\n  pay:\n    body:\n      - value: { call: { procedure: nothing, arguments: { of: 1 } } }", 4),
        ("procedures: [ unclosed", nil)
    ])
    func aRefusalAmongTextsNamesItsText(written: String, line: Int?) {
        // Given
        let texts = ["name: Bank\ntypes:\n  Account: { struct: { cents: Int } }", written]

        // When / Then
        #expect {
            try sut.documents(from: texts)
        } throws: { error in
            guard let refusal = error as? AuthoringError, refusal.text == 1 else { return false }

            guard let line else { return true }

            guard let position = refusal.position else { return false }

            return position.line == line && refusal.description.hasPrefix("text 1, \(line):")
        }
    }

    @Test("a text whose declarations do not read is refused at its own position, before a call to it is matched")
    func aTextWhoseDeclarationsDoNotReadIsRefused() throws {
        // Given. The probe's texts: `pair` is called by name beside a
        // declaration whose type does not read, in the caller and in the
        // callee handed after it
        let alone = """
        name: App
        procedures:
          broken:
            parameters: [ a: "Array<" ]
          pair:
            parameters: [ a: Int, b: Int ]
          entry:
            body:
              - value: { call: { procedure: pair, arguments: { b: 2, a: 1 } } }
        """
        let caller = """
        name: Shop
        procedures:
          entry:
            body:
              - value: { call: { procedure: pair, arguments: { b: 2, a: 1 } } }
        """
        let callee = """
        name: App
        procedures:
          pair:
            access: public
            parameters: [ a: Int, b: Int ]
          broken:
            parameters: [ a: "Array<" ]
        """

        // When
        let spentAlone = #expect(throws: AuthoringError.self) { try sut.document(from: alone) }
        let spentTogether = #expect(throws: AuthoringError.self) { try sut.documents(from: [caller, callee]) }

        // Then
        #expect(spentAlone?.message == "'Array<' does not read as a type")
        #expect(spentAlone?.position == Origin.Position(line: 4, column: 19))
        #expect(spentTogether?.message == "'Array<' does not read as a type")
        #expect(spentTogether?.text == 1)
        #expect(spentTogether?.position == Origin.Position(line: 7, column: 19))
    }

    @Test("a one-key template stays a template beside a leaned-on procedure of its key's name, which shadows a key the notation reads")
    func aTemplateKeyIsNoCallOfALeanedOnProcedure() throws {
        // Given. The probe's texts: `Lib` declares `format`
        let library = """
        name: Lib
        procedures:
          format:
            access: public
            parameters: [ of: String ]
            returns: String
            result: X
        """
        let text = """
        procedures:
          entry:
            returns: String
            result: { format: hello }
        """
        let leaning = try sut.leaning(on: [.text(library)])

        // When
        let document = try leaning.document(from: text)

        // Then
        #expect(document.document == (try sut.document(from: text).document))
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            returns: String
            body: [ { value: { return: hello } } ]
        """)
        #expect(leaning.shadowing("format", as: .procedure).declarations == ["Lib.format"])
        #expect(leaning.shadowing("format", as: .procedure).isKeyword)
    }

    @Test("a `break` and a `continue` stay leaves beside leaned-on procedures of their keys' names")
    func aLeaveIsNoCallOfALeanedOnProcedure() throws {
        // Given
        let library = """
        name: Lib
        procedures:
          break: { access: public }
          continue: { access: public, parameters: [ of: String ] }
        """
        let text = """
        procedures:
          entry:
            body:
              - let: outer
                value:
                  loop:
                    while: true
                    body:
                      - value: { loop: { while: true, body: [ { value: { continue: outer } } ] } }
                      - value: { break: null }
        """
        let sut = try sut.leaning(on: [.text(library)])

        // When
        let document = try sut.document(from: text)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body:
              - let: outer
                value:
                  loop:
                    while: true
                    body:
                      - value: { loop: { while: true, body: [ { value: { continue: outer } } ] } }
                      - value: { break: null }
        """)
    }

    @Test("a declaration shadows what the documents it leans on name it by, and a procedure the key the notation reads", arguments: [
        ("run", Space.procedure, ["Lib.run", "Tool.run"], false),
        ("greet", .procedure, ["Lib.greet"], false),
        ("is", .procedure, [], true),
        ("count", .procedure, ["Standard.Collection.count"], true),
        ("Account", .type, ["Lib.Account"], false),
        ("secret", .procedure, [], false),
        ("Account", .procedure, [], false),
        ("is", .type, [], false),
        ("deploy", .procedure, [], false),
        ("of", .procedure, [], true),
        ("ref", .procedure, [], true),
        ("loop", .procedure, [], true),
        ("each", .procedure, [], true),
        ("break", .procedure, [], true),
        ("continue", .procedure, [], true)
    ] as [(String, Space, [String], Bool)])
    func aDeclarationShadows(name: String, space: Space, declarations: [String], isKeyword: Bool) throws {
        // Given
        let texts = [
            """
            name: Lib
            types:
              Account: { struct: { cents: Int } }
            procedures:
              run: { access: public }
              greet: { access: public }
              secret: { access: private }
            """,
            """
            name: Tool
            procedures:
              run: { access: public }
            """
        ]
        let sut = try sut.leaning(on: texts.map(Dependency.text))

        // When
        let shadowing = sut.shadowing(try Name(name), as: space)

        // Then
        #expect(shadowing.declarations == (try declarations.map { try Name($0) }))
        #expect(shadowing.isKeyword == isKeyword)
    }
}
