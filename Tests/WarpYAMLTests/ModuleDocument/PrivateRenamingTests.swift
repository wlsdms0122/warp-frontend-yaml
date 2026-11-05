//
//  PrivateRenamingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/4/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A text's private procedure is its own. Where another text of the module
// declares or names its spelling, the module's document gives it one
// nothing else has, the text's calls reach it there, and the origin reads
// the spelling back as the one the text wrote.
@Suite("The private procedures of one module's texts, held apart")
struct PrivateRenamingTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("two texts keeping one name private each reach their own")
    func twoTextsKeepOnePrivateNameApart() throws {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  secret: { access: private, returns: Int, result: 1 }\n  pay: \(calling("secret"))",
            "name: Bank\nprocedures:\n  secret: { access: private, returns: Int, result: 2 }\n  owe: \(calling("secret"))"
        ]

        // When
        let spent = try sut.document(from: texts)
        let second = spent.origin.reading(["procedures", "Bank.secret_2"])

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        procedures:
          Bank.owe:
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.secret_2 } } } } ]
          Bank.pay:
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.secret_1 } } } } ]
          Bank.secret_1:
            access: private
            returns: Int
            body: [ { value: { return: 1 } } ]
          Bank.secret_2:
            access: private
            returns: Int
            body: [ { value: { return: 2 } } ]
        """)
        #expect(second.exact)
        #expect(second.text == 1)
        #expect(spent.origin.demangled("'Bank.secret_2' takes nothing") == "'Bank.secret' takes nothing")
    }

    @Test("a private name another text declares internal is renamed in its own text alone")
    func aPrivateNameBesideAnotherTextsInternalOne() throws {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  secret: { access: private, returns: Int, result: 1 }\n  pay: \(calling("secret"))",
            "name: Bank\nprocedures:\n  secret: { returns: Int, result: 2 }\n  owe: \(calling("secret"))"
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        procedures:
          Bank.owe:
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.secret } } } } ]
          Bank.pay:
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.secret_1 } } } } ]
          Bank.secret:
            returns: Int
            body: [ { value: { return: 2 } } ]
          Bank.secret_1:
            access: private
            returns: Int
            body: [ { value: { return: 1 } } ]
        """)
    }

    @Test("another text's call into a module it uses stays that module's, and no reached name is given")
    func aNameAnotherTextUsesFromAModuleReachesThatModule() throws {
        // Given
        let sut = try sut.depending(on: [
            .text("name: Lib\nprocedures:\n  secret: { returns: Int, result: 2 }\n  secret_1: { result: 3 }", module: "Lib")
        ])
        let texts = [
            "procedures:\n  Lib.secret: { access: private, returns: Int, result: 1 }\n  pay: \(calling("Lib.secret"))",
            "uses: [ Lib ]\nprocedures:\n  owe: \(calling("Lib.secret"))"
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: [ Lib.secret ]
        procedures:
          Lib.secret_2:
            access: private
            returns: Int
            body: [ { value: { return: 1 } } ]
          owe:
            returns: Int
            body: [ { value: { return: { call: { procedure: Lib.secret } } } } ]
          pay:
            returns: Int
            body: [ { value: { return: { call: { procedure: Lib.secret_2 } } } } ]
        """)
    }

    @Test("a private member two texts give one type is held apart under the type")
    func aPrivateMemberIsRenamedUnderItsType() throws {
        // Given
        let texts = [
            """
            name: Bank
            types:
              Account:
                struct: { cents: Int }
                procedures:
                  audit: { access: private, parameters: [ of: Account ], returns: Int, result: 1 }
            """,
            """
            name: Bank
            extensions:
              Account:
                procedures:
                  audit: { access: private, parameters: [ of: Account ], returns: Int, result: 2 }
            """
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        types:
          Bank.Account:
            struct:
              cents: Int
            procedures:
              audit_1:
                access: private
                parameters: [ { name: of, type: Bank.Account } ]
                returns: Int
                body: [ { value: { return: 1 } } ]
              audit_2:
                access: private
                parameters: [ { name: of, type: Bank.Account } ]
                returns: Int
                body: [ { value: { return: 2 } } ]
        """)
        #expect(spent.origin.demangled("'Bank.Account.audit_2'") == "'Bank.Account.audit'")
    }

    @Test("a spelling the module already has is passed over")
    func aSpellingTakenIsPassedOver() throws {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  secret: { access: private, returns: Int, result: 1 }",
            """
            name: Bank
            procedures:
              secret: { access: private, returns: Int, result: 2 }
              secret_1: { returns: Int, result: 3 }
            """
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        procedures:
          Bank.secret_1:
            returns: Int
            body: [ { value: { return: 3 } } ]
          Bank.secret_2:
            access: private
            returns: Int
            body: [ { value: { return: 1 } } ]
          Bank.secret_3:
            access: private
            returns: Int
            body: [ { value: { return: 2 } } ]
        """)
        #expect(spent.origin.demangled("'Bank.secret_1'") == "'Bank.secret_1'")
    }

    @Test("a private name no other text declares or names keeps the spelling its text wrote")
    func aPrivateNameNoOtherTextHoldsIsKept() throws {
        // Given
        let texts = [
            "name: Bank\nprocedures:\n  secret: { access: private, returns: Int, result: 1 }\n  pay: \(calling("secret"))",
            "name: Bank\nprocedures:\n  owe: { returns: Int, result: 2 }"
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        procedures:
          Bank.owe:
            returns: Int
            body: [ { value: { return: 2 } } ]
          Bank.pay:
            returns: Int
            body: [ { value: { return: { call: { procedure: Bank.secret } } } } ]
          Bank.secret:
            access: private
            returns: Int
            body: [ { value: { return: 1 } } ]
        """)
    }

    @Test("a contract's procedure is what the contract asks, and keeps its spelling")
    func aContractsProcedureKeepsItsSpelling() throws {
        // Given
        let texts = [
            """
            name: Shape
            contracts:
              Shown:
                procedures:
                  shown: { access: private, parameters: [ of: Self ], returns: String }
            """,
            """
            name: Shape
            procedures:
              show: { parameters: [ of: Int ], returns: String, result: { call: { procedure: Shape.Shown.shown, arguments: [ { ref: of } ] } } }
            """
        ]

        // When
        let spent = try sut.document(from: texts)

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        contracts:
          Shape.Shown:
            procedures:
              shown: { access: private, parameters: [ { name: of, type: Self } ], returns: String }
        procedures:
          Shape.show:
            parameters: [ { name: of, type: Int } ]
            returns: String
            body: [ { value: { return: { call: { procedure: Shape.Shown.shown, arguments: [ { ref: of } ] } } } } ]
        """)
    }

    // MARK: - Public
    // MARK: - Private
    // A procedure returning what a call to `procedure` returns.
    private func calling(_ procedure: String) -> String {
        "{ returns: Int, result: { call: { procedure: \(procedure) } } }"
    }
}
