//
//  TypeSpellingTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A type reads by the type grammar and writes its one spelling")
struct TypeSpellingTests {
    // MARK: - Property
    // Strings in the one spelling, from the type grammar's table, one of each
    // part, and some the grammar reads that the load refuses.
    private static let spellings = [
        "Int",
        "Any",
        "Procedure",
        "Self.Item",
        "App.Point",
        "Array<Int>",
        "Dictionary<String, Int>",
        "App.Box<Int, String>",
        "App.Box.Item",
        "App.Wrapper<String>.Item",
        "App.Wrapper<String>.Item?",
        "Array<Int>.Element",
        "Dictionary<String, Int>.Key",
        "App.Wrapper<some T>.Item",
        "App.Box<App.Wrapper<Int>.Item>",
        "Array<Int, String>",
        "Int?",
        "Int??",
        "A & B",
        "A & B?",
        "some T",
        "some T.Item",
        "some W?",
        "some T: Describable & Standard.Comparable",
        "(some W: P)?",
        "App.Box<some T: Hashable>",
        "Dictionary<some Key: Hashable, Any>",
        "inout Int?",
        "var Int",
        "(Int, String) -> Bool",
        "(inout Int) -> Int",
        "(Int) -> Int?",
        "((Int) -> Int)?",
        "() -> Null",
        "(Int) throws -> Bool",
        "(Int) throws(aborted, cast_refused) -> Bool",
        "(Int) throws() -> Bool",
        "const isolated (A, inout B) throws(x) -> R",
        "isolated const Procedure",
        "const Procedure",
        "(const Procedure)?"
    ]

    // Strings in no spelling the grammar reads.
    private static let refused = [
        "",
        " Int",
        "Int ",
        "Array< Int>",
        "Dictionary<String,Int>",
        "Array<>",
        "Int ?",
        "(Int)?",
        "(A & B)?",
        "(Int)",
        "(Int)->Int",
        "const Procedure?",
        "some T: P?",
        "const const Procedure",
        "A &",
        "App.Box<Int",
        "App.Wrapper<String>.Item<Int>",
        "App.Wrapper<String>.Item.Key",
        "App.Wrapper<String> .Item",
        "App.Wrapper<String>. Item",
        "App.Wrapper<String>.",
        "App.Box<App.Wrapper<Int>.Item<Int>>",
        "Int?.Item",
        "(App.Wrapper<String>.Item)?"
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("a type in its one spelling writes the same string back", arguments: spellings)
    func oneSpellingRoundTrips(_ spelling: String) throws {
        // Given
        let sut = try TypeSpelling(spelling)

        // When
        let written = sut.spelling

        // Then
        #expect(written == spelling)
    }

    @Test("a string in no spelling of a type is refused", arguments: refused)
    func anotherSpellingIsRefused(_ string: String) {
        // Given
        let sut = { () throws(AuthoringError) in try TypeSpelling(string) }

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut() }

        // Then
        #expect(refusal?.message.contains("'\(string)'") == true)
    }

    @Test("a type is read part by part")
    func aTypeIsReadPartByPart() throws {
        // Given
        let spelling = "const (inout Array<some T: Hashable>, Dictionary<String, App.Box<Int>>?) throws(x) -> A & B"

        // When
        let sut = try TypeSpelling(spelling)

        // Then
        #expect(
            sut == .procedure(
                modifiers: [.const],
                parameters: [
                    .inout(.array(.parameter("T", bounds: ["Hashable"]))),
                    .optional(.dictionary(
                        key: .named("String", arguments: []),
                        value: .named("App.Box", arguments: [.named("Int", arguments: [])])
                    ))
                ],
                failing: .names(["x"]),
                returns: .composition(["A", "B"])
            )
        )
    }

    @Test("an Optional is told apart from a type holding one")
    func anOptionalIsToldApart() throws {
        // Given
        let optional = try TypeSpelling("((Int) -> Int)?")
        let returningOne = try TypeSpelling("(Int) -> Int?")
        let inPlace = try TypeSpelling("inout Int?")

        // When
        let sut = [optional, returningOne, inPlace].map(\.isOptional)

        // Then
        #expect(sut == [true, false, false])
    }

    @Test("a type's names of types and contracts are rewritten, a type parameter's and a failure's kept")
    func typeNamesAreRewritten() throws {
        // Given
        let sut = try TypeSpelling("(Box<Point>, some T: Named & Hashable, A & B) throws(x) -> Point?")

        // When
        let rewritten = sut.mapTypeNames { name in "App.\(name)" }

        // Then
        #expect(
            rewritten.spelling
                == "(App.Box<App.Point>, some T: App.Named & App.Hashable, App.A & App.B) throws(x) -> App.Point?"
        )
    }

    @Test("a type member's name after an applied type is read as the type member of that type")
    func aTypeMemberAfterAnAppliedTypeIsRead() throws {
        // Given
        let spelling = "Dictionary<App.Wrapper<some T>.Item, Array<Int>.Element>"

        // When
        let sut = try TypeSpelling(spelling)

        // Then
        #expect(
            sut == .dictionary(
                key: .member(.named("App.Wrapper", arguments: [.parameter("T", bounds: [])]), name: "Item"),
                value: .member(.array(.named("Int", arguments: [])), name: "Element")
            )
        )
    }

    @Test("a type member's spelling written bare is read as a name")
    func aBareTypeMembersSpellingIsAName() throws {
        // Given
        let spelling = "App.Box.Item"

        // When
        let sut = try TypeSpelling(spelling)

        // Then
        #expect(sut == .named("App.Box.Item", arguments: []))
    }

    @Test("a `?` after a type member's name writes its Optional")
    func anOptionalOfATypeMemberIsRead() throws {
        // Given
        let spelling = "App.Wrapper<String>.Item?"

        // When
        let sut = try TypeSpelling(spelling)

        // Then
        #expect(
            sut == .optional(.member(.named("App.Wrapper", arguments: [.named("String", arguments: [])]), name: "Item"))
        )
    }

    @Test("an applied type's names are rewritten and the type member's name after it kept")
    func aTypeMembersNameIsKept() throws {
        // Given
        let sut = try TypeSpelling("Wrapper<Point>.Item")

        // When
        let rewritten = sut.mapTypeNames { name in "App.\(name)" }

        // Then
        #expect(rewritten.spelling == "App.Wrapper<App.Point>.Item")
    }

    @Test("a head of a type member after an applied type extends the type member's spelling")
    func aTypeMembersHeadExtendsItsSpelling() throws {
        // Given
        let sut = try TypeSpelling("App.Wrapper<String>.Item")

        // When
        let extended = sut.extendedType

        // Then
        #expect(extended == "App.Wrapper.Item")
    }

    @Test("a type names the spelling of each type member it names after an applied type")
    func aTypeNamesItsTypeMembersSpellings() throws {
        // Given
        let sut = try TypeSpelling("(App.Wrapper<Array<Int>.Element>.Item, App.Box.Item) -> Int")

        // When
        let spellings = sut.typeMemberSpellings

        // Then
        #expect(spellings == ["App.Wrapper.Item", "Array.Element"])
    }

    // MARK: - Public
    // MARK: - Private
}
