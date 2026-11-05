//
//  ModuleDocumentTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// The texts of one module are one document: what each declares is laid
// together, a name declared twice is refused, what a text keeps `private`
// the others do not name, and a claim a used module makes beside neither
// its type nor its contract is imported.
@Suite("The texts of one module, as its document")
struct ModuleDocumentTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("a name two texts declare is refused where the later one declares it", arguments: [
        ("procedures:\n  pay: { returns: Int, result: 1 }", "'Bank.pay' is declared twice in one module, first in text 0"),
        ("const:\n  limit: 1", "'limit' is declared twice in one module, first in text 0")
    ])
    func aNameDeclaredTwiceIsRefused(declared: String, message: String) {
        // Given
        let texts = ["name: Bank\n\(declared)", "name: Bank\n\(declared)"]

        // When
        let refused = refusal { try sut.document(from: texts) }

        // Then
        #expect(refused?.message == message)
        #expect(refused?.text == 1)
        #expect(refused?.position?.line == 3)
    }

    @Test("two texts extending one head give it what each gives")
    func extensionsOfOneHeadAreOne() throws {
        // Given
        let texts = [
            """
            name: Shape
            contracts:
              Shown:
                procedures:
                  shown: { parameters: [ of: Self ], returns: String }
            extensions:
              Int:
                satisfies: [ Shown ]
                procedures:
                  shown: { parameters: [ of: Int ], returns: String, result: "int" }
            """,
            """
            name: Shape
            extensions:
              Int:
                procedures:
                  twice: { parameters: [ of: Int ], returns: Int, result: { ref: of } }
            """
        ]

        // When
        let document = try sut.document(from: texts)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        contracts:
          Shape.Shown:
            procedures:
              shown: { parameters: [ { name: of, type: Self } ], returns: String }
        extensions:
          Int:
            satisfies: [ Shape.Shown ]
            procedures:
              shown:
                parameters: [ { name: of, type: Int } ]
                returns: String
                body: [ { value: { return: int } } ]
              twice:
                parameters: [ { name: of, type: Int } ]
                returns: Int
                body: [ { value: { return: { ref: of } } } ]
        """)
    }

    @Test("an extension of a struct another text of the module declares is given in the declaration")
    func anExtensionOfTheModulesStructIsDeclared() throws {
        // Given
        let texts = [
            "name: Bank\ntypes:\n  Account: { struct: { cents: Int } }",
            """
            name: Bank
            extensions:
              Account:
                procedures:
                  audit: { parameters: [ of: Account ], returns: Int, result: { ref: of.cents } }
            """
        ]

        // When
        let spent = try sut.document(from: texts)
        let audit = spent.origin.reading(["types", "Bank.Account", "procedures", "audit"])

        // Then. The member stands in the text that wrote it
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        types:
          Bank.Account:
            struct:
              cents: Int
            procedures:
              audit:
                parameters: [ { name: of, type: Bank.Account } ]
                returns: Int
                body: [ { value: { return: { ref: of.cents } } } ]
        """)
        #expect(audit.exact)
        #expect(audit.text == 1)
        #expect(audit.position.line == 5)
    }

    @Test("a name another text of the module keeps private is refused where it is written", arguments: [
        "{ call: { procedure: Bank.secret } }",
        "{ call: { procedure: Bank.secret, arguments: { cents: 1 } } }"
    ])
    func anotherTextsPrivateIsRefused(call: String) {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  secret: { access: private, parameters: [ cents: Int? ], returns: Int, result: 1 }",
            "name: Shop\nprocedures:\n  pay: { returns: Int, result: \(call) }"
        ]

        // When
        let refused = refusal { try sut.document(from: texts) }

        // Then
        #expect(refused?.message == "'Bank.secret' is private to another text of the module")
        #expect(refused?.text == 1)
        #expect(refused?.position?.line == 3)
    }

    @Test("a claim a used module makes beside neither its type nor its contract is imported, and no other")
    func anOrphanClaimIsImported() throws {
        // Given. `Ext` claims `Int: Lib.Shown` and declares neither; `Lib`
        // claims `Int: Lib.Named` beside the contract, and the interface
        // `Far` claims `Lib.Card: Lib.Named` beside neither
        let library = """
        name: Lib
        types:
          Card: { struct: { id: Int } }
        contracts:
          Shown: {}
          Named: {}
        extensions:
          Int: { satisfies: [ Named ] }
        """
        let extending = "name: Ext\nuses: [ Lib ]\nextensions:\n  Int: { satisfies: [ Lib.Shown ] }"
        let far = Data("(interface 1)\n(extension (head Lib.Card) (satisfies Lib.Named))".utf8)
        let sut = try sut.depending(on: [
            .text(library, module: "Lib"),
            .text(extending, module: "Ext"),
            .interface(far, module: "Far")
        ])

        // When
        let used = try sut.document(from: ["uses: [ Ext, Far ]\nprocedures:\n  entry: { result: 1 }"])
        let unused = try sut.document(from: "uses: [ Lib ]\nprocedures:\n  entry: { result: 1 }")

        // Then
        try expectDocument(used, is: """
        warp: 1
        imports: []
        importedClaims: [ [ Int, Lib.Shown ], [ Lib.Card, Lib.Named ] ]
        procedures:
          entry:
            body: [ { value: { return: 1 } } ]
        """)
        try expectDocument(unused, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body: [ { value: { return: 1 } } ]
        """)
    }

    // MARK: - Public
    // MARK: - Private
}
