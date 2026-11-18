//
//  NameTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
import WarpYAML

@Suite("A name is written, in normal form C, and ordered by its bytes")
struct NameTests {
    // MARK: - Property
    // MARK: - Initializer
    // MARK: - Test
    @Test("a spelling with nothing in it, or not in normal form C, is no name", arguments: [
        ("", "a name is written, and this one is empty"),
        ("caf\u{65}\u{301}", "the name 'caf\u{65}\u{301}' is not in normal form C")
    ])
    func aSpellingThatIsNoNameIsRefused(spelling: String, message: String) {
        // Given / When
        let error = #expect(throws: AuthoringError.self) { try Name(spelling) }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == nil)
    }

    @Test("a name in normal form C is its spelling, and names order by their UTF-8 bytes")
    func namesOrderByTheirBytes() throws {
        // Given
        let sut = try ["b", "café", "B", "a_1"].map { spelling in try Name(spelling) }

        // When
        let ordered = sut.sorted()

        // Then
        #expect(ordered.map(\.spelling) == ["B", "a_1", "b", "café"])
    }

    @Test("an identifier is ASCII letters, digits and `_`, beginning with no digit", arguments: [
        ("App", true),
        ("_x1", true),
        ("1x", false),
        ("App.entry", false),
        ("café", false)
    ])
    func anIdentifierIsASCII(spelling: String, isIdentifier: Bool) throws {
        // Given
        let sut = try Name(spelling)

        // When / Then
        #expect(sut.isIdentifier == isIdentifier)
    }

    // MARK: - Public
    // MARK: - Private
}
