//
//  NamingPrefixTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A text's name on the keys it declares")
struct NamingPrefixTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the prefix goes on the text's own keys, and the name key goes")
    func thePrefixGoesOnTheTextsOwnKeys() throws {
        // Given
        let text = try parser.parse("""
        name: Bank
        types:
          Account: { struct: { cents: Int }, procedures: { describe: {} } }
          Account.Kind: String
          Lib.Card: { struct: {} }
        contracts:
          Named: { procedures: { name: { parameters: [ of: Self ] } } }
        extensions:
          Account: { procedures: { audit: {} } }
          Int: { procedures: { cents: {} } }
        procedures:
          transfer: {}
          Account.open: {}
          Other.run: {}
        const: { limit: 3 }
        """)
        let sut = try Naming(of: text, leaningOn: Declarations())

        // When
        let prefixed = try sut.prefixed(text)

        // Then
        #expect(prefixed == (try parser.parse("""
        types:
          Bank.Account: { struct: { cents: Int }, procedures: { describe: {} } }
          Bank.Account.Kind: String
          Lib.Card: { struct: {} }
        contracts:
          Bank.Named: { procedures: { name: { parameters: [ of: Self ] } } }
        extensions:
          Bank.Account: { procedures: { audit: {} } }
          Int: { procedures: { cents: {} } }
        procedures:
          Bank.transfer: {}
          Bank.Account.open: {}
          Other.run: {}
        const: { limit: 3 }
        """)))
    }

    @Test("a text that writes no name is its tree as written")
    func aTextWithNoNameStands() throws {
        // Given
        let text = try parser.parse("procedures: { transfer: {} }")
        let sut = try Naming(of: text, leaningOn: Declarations())

        // When
        let prefixed = try sut.prefixed(text)

        // Then
        #expect(prefixed == text)
        #expect(sut.prefix == nil)
    }

    @Test("a name that is not identifiers joined by dots is refused at its key", arguments: [
        "name: Bank.",
        "name: 3d",
        "name: [Bank]",
        "name: Bank Two"
    ])
    func aNameNotJoinedByDotsIsRefused(written: String) throws {
        // Given
        let text = try parser.parse("procedures: { f: {} }\n\(written)")

        // When
        let error = #expect(throws: AuthoringError.self) {
            try Naming(of: text, leaningOn: Declarations())
        }

        // Then
        #expect(error?.message.hasPrefix("a name is identifiers joined by dots") == true)
        #expect(error?.position == Origin.Position(line: 2, column: 1))
    }

    @Test("a key written short and full is one declaration written twice")
    func aKeyWrittenShortAndFullIsRefused() throws {
        // Given
        let text = try parser.parse("""
        name: Bank
        procedures:
          transfer: {}
          Bank.transfer: {}
        """)
        let sut = try Naming(of: text, leaningOn: Declarations())

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.prefixed(text)
        }

        // Then
        #expect(error?.message == "'Bank.transfer' is written twice under procedures, once short and once full")
        #expect(error?.position == Origin.Position(line: 4, column: 3))
    }
}
