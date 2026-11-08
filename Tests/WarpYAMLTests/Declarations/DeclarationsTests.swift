//
//  DeclarationsTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("Declarations name what a text uses by short names and match its arguments")
struct DeclarationsTests {
    // MARK: - Property
    // A module a text uses: a struct with a member, a contract with a
    // requirement, members given under heads, a procedure spelled under the
    // struct and one spelled under the contract.
    private static let library = """
    (interface 1)
    (struct Lib.Card
      (field title String)
      (procedure describe (parameter of (type Lib.Card)) (returns String)))
    (contract Lib.Named
      (procedure name (parameter of (type Self)) (returns String)))
    (extension (head Int) (procedure doubled (parameter of (type Int)) (returns Int)))
    (extension (head (array (some T))) (procedure size (parameter of (type (array (some T)))) (returns Int)))
    (extension (head (optional Int)) (procedure orZero (parameter of (type (optional Int))) (returns Int)))
    (procedure Lib.Card.make (parameter title (type String)) (returns Lib.Card))
    (procedure Lib.Named.greet (parameter of (type Lib.Named)) (returns String))
    (procedure Lib.shout
      (parameter text (type String))
      (parameter times (type (optional Int)))
      (parameter suffix)
      (returns String))
    (procedure Lib.Card (returns Lib.Card))
    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a short name stands for a type in the type space and a procedure in the procedure space")
    func shortNamesStandBySpace() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When
        let type = try sut.qualified("Card", in: .type)
        let procedure = try sut.qualified("Card", in: .procedure)
        let contract = try sut.qualified("Named", in: .type)

        // Then
        #expect(type == "Lib.Card")
        #expect(procedure == "Lib.Card")
        #expect(contract == "Lib.Named")
        #expect(try sut.qualified("shout", in: .procedure) == "Lib.shout")
        #expect(try sut.qualified("shout", in: .type) == nil)
    }

    @Test("a member and a procedure spelled under a type its document declares take the type's short name")
    func aMemberTakesItsOwnersShortName() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When
        let names = try ["Card.describe", "Card.make", "Int.doubled", "Array.size", "Optional.orZero"].map { name in
            try sut.qualified(Name(name), in: .procedure)
        }

        // Then
        #expect(names == ["Lib.Card.describe", "Lib.Card.make", "Int.doubled", "Array.size", "Optional.orZero"])
        #expect(sut.signature(of: "Lib.Card.describe")?.returns == .named("String", arguments: []))
        #expect(try sut.qualified("describe", in: .procedure) == nil)
    }

    @Test("a type member's spelling takes its type's short name and is an alias of the type it gives")
    func aTypeMemberTakesItsOwnersShortName() throws {
        // Given
        let sut = try Self.declarations("""
        (interface 1)
        (struct Lib.Card
          (field title String)
          (type Item (procedure (parameters Int) (returns Int))))
        (extension (head Int) (type Unit String))
        """)

        // When
        let short = try sut.qualified("Card.Item", in: .type)
        let full = try sut.qualified("Lib.Card.Item", in: .type)
        let given = try sut.qualified("Int.Unit", in: .type)

        // Then
        #expect(short == "Lib.Card.Item")
        #expect(full == "Lib.Card.Item")
        #expect(given == "Int.Unit")
        #expect(try sut.qualified("Item", in: .type) == nil)
        #expect(sut.alias(.named("Lib.Card.Item", arguments: [])) == (try TypeSpelling("(Int) -> Int")))
        #expect(sut.alias(.named("Int.Unit", arguments: [])) == .named("String", arguments: []))
    }

    @Test("a contract's requirement and a procedure spelled under a contract take their last identifier")
    func aContractsProcedureTakesItsLastIdentifier() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When
        let requirement = try sut.qualified("name", in: .procedure)
        let spelledUnder = try sut.qualified("greet", in: .procedure)

        // Then
        #expect(requirement == "Lib.Named.name")
        #expect(spelledUnder == "Lib.Named.greet")
        #expect(try sut.qualified("Named.greet", in: .procedure) == nil)
        #expect(sut.signature(of: "Lib.Named.name")?.parameters.map(\.type) == [.named("Self", arguments: [])])
    }

    @Test("a private procedure has no short name, and its signature is kept by its full name")
    func aPrivateProcedureHasNoShortName() throws {
        // Given
        let document: Tree = [
            "warp": 1,
            "imports": [],
            "procedures": [
                "App.hidden": ["access": "private", "returns": "Int"],
                "App.open": ["access": "public", "returns": "Int"]
            ]
        ]

        // When
        let sut = try Declarations().adding(document)

        // Then
        #expect(try sut.qualified("hidden", in: .procedure) == nil)
        #expect(try sut.qualified("open", in: .procedure) == "App.open")
        #expect(sut.signature(of: "App.hidden")?.access == .private)
    }

    @Test("a name that is a declaration's full name stands for it before any short name is read")
    func aFullNameIsReadFirst() throws {
        // Given
        let sut = try Self.declarations(
            Self.library,
            """
            (interface 1)
            (struct Card (field title String))
            (procedure shout (parameter text (type String)) (returns String))
            (procedure Card.describe (parameter of (type Card)) (returns String))
            """
        )

        // When
        let type = try sut.qualified("Card", in: .type)
        let procedure = try sut.qualified("shout", in: .procedure)
        let member = try sut.qualified("Card.describe", in: .procedure)

        // Then
        #expect(type == "Card")
        #expect(procedure == "shout")
        #expect(member == "Card.describe")
        #expect(sut.declarations(named: "Card", in: .type) == ["Card", "Lib.Card"])
    }

    @Test("two declarations of one short name are named by neither, and the refusal lists both")
    func twoDeclarationsRefuse() throws {
        // Given
        let other = "(interface 1)\n(procedure Other.shout (parameter text (type String)) (returns String))"
        let sut = try Self.declarations(Self.library, other)

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut.qualified("shout", in: .procedure) }

        // Then
        #expect(refusal?.message == "'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full")
        #expect(sut.declarations(named: "shout", in: .procedure) == ["Lib.shout", "Other.shout"])
    }

    @Test("arguments are matched by name in the callee's order, an Optional left out handed null")
    func argumentsAreMatchedByName() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When
        let arguments = try #require(try sut.arguments(["suffix": "!", "text": "hi"], to: "Lib.shout"))

        // Then
        #expect(arguments.map(\.parameter) == ["text", "times", "suffix"])
        #expect(arguments.map(\.argument) == ["hi", nil, "!"])
    }

    @Test("a name the callee does not take is refused at what it hands")
    func anUnknownNameIsRefusedAtItsArgument() throws {
        // Given
        let sut = try Self.declarations(Self.library)
        let handed = Tree(.bool(true), at: Origin.Position(line: 3, column: 7))

        // When
        let refusal = #expect(throws: AuthoringError.self) {
            try sut.arguments(["text": "hi", "loudly": handed], to: "Lib.shout")
        }

        // Then
        #expect(refusal?.message == "'Lib.shout' takes no 'loudly'. It takes text, times, suffix")
        #expect(refusal?.position == Origin.Position(line: 3, column: 7))
    }

    @Test("a parameter that is no Optional, left out, is refused with its type's one spelling")
    func aNonOptionalLeftOutIsRefused() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When
        let typed = #expect(throws: AuthoringError.self) { try sut.arguments(["suffix": "!"], to: "Lib.shout") }
        let untyped = #expect(throws: AuthoringError.self) { try sut.arguments(["text": "hi"], to: "Lib.shout") }

        // Then
        #expect(typed?.message == "'Lib.shout' takes text, String, which this call does not name")
        #expect(untyped?.message == "'Lib.shout' takes suffix, Any, which this call does not name")
    }

    @Test("a callee the table does not declare matches nothing")
    func anUndeclaredCalleeMatchesNothing() throws {
        // Given
        let sut = try Self.declarations(Self.library)

        // When / Then
        #expect(try sut.arguments(["text": "hi"], to: "Lib.whisper") == nil)
    }

    // MARK: - Public
    // MARK: - Private
    private static func declarations(_ interfaces: String...) throws -> Declarations {
        try interfaces.reduce(Declarations()) { declarations, interface in
            try declarations.adding(InterfaceReader().read(Data(interface.utf8)))
        }
    }
}
