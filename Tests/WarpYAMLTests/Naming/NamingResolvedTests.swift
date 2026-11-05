//
//  NamingResolvedTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("The names a text's callees, types, contracts and heads write, resolved to declarations")
struct NamingResolvedTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a short name is written in full, a full name and a name nothing declares stand")
    func aShortNameIsWrittenInFull() throws {
        // Given
        let library = try parser.parse("""
        types: { Lib.Box: { struct: {} } }
        contracts: { Lib.Shape: {} }
        procedures: { Lib.shout: {}, Other.shout: {} }
        """)
        let text = try parser.parse("""
        name: App
        types:
          Card: { struct: { box: Box }, typeParameters: ["T: Shape & Named"], satisfies: [Shape, Named] }
        contracts:
          Named: { types: ["Item: Shape"] }
        extensions:
          Box: { procedures: { open: {} } }
        procedures:
          greet:
            parameters: [ { name: card, type: "Array<Card>?" } ]
            bounds: { T.Item: Shape }
            body:
              - value: { call: { procedure: greet } }
              - value: { call: { procedure: Lib.shout } }
              - value: { call: { procedure: nowhere } }
              - value: { as: { of: 1, type: "Dictionary<String, Box>" } }
        """)
        let sut = try Naming(of: text, reading: Declarations().adding(library))

        // When
        let resolved = try sut.resolved(try sut.prefixed(text))

        // Then
        #expect(resolved == (try parser.parse("""
        types:
          App.Card:
            struct: { box: Lib.Box }
            typeParameters: ["T: Lib.Shape & App.Named"]
            satisfies: [Lib.Shape, App.Named]
        contracts:
          App.Named: { types: ["Item: Lib.Shape"] }
        extensions:
          Lib.Box: { procedures: { open: {} } }
        procedures:
          App.greet:
            parameters: [ { name: card, type: "Array<App.Card>?" } ]
            bounds: { T.Item: Lib.Shape }
            body:
              - value: { call: { procedure: App.greet } }
              - value: { call: { procedure: Lib.shout } }
              - value: { call: { procedure: nowhere } }
              - value: { as: { of: 1, type: "Dictionary<String, Lib.Box>" } }
        """)))
    }

    @Test("an enum takes the prefix, its fields' types and its members read as a struct's do")
    func anEnumIsNamedAsAStructIs() throws {
        // Given
        let library = try parser.parse("""
        types: { Lib.Box: { struct: {} } }
        """)
        let text = try parser.parse("""
        name: App
        types:
          Target:
            enum: { local: {}, remote: { box: "Box?", next: "Array<Target>", item: some T } }
            typeParameters: ["T: Named"]
            satisfies: [Named]
            types: { Item: Box }
            procedures:
              describe: { parameters: [ { name: of, type: "Target<some T>" } ] }
        contracts:
          Named: {}
        procedures:
          main:
            body:
              - value: { call: { procedure: Target.describe } }
              - value: { as: { of: { case: { local: {} } }, type: "Target<Box>" } }
        """)
        let sut = try Naming(of: text, reading: Declarations().adding(library))

        // When
        let resolved = try sut.resolved(try sut.prefixed(text))

        // Then
        #expect(resolved == (try parser.parse("""
        types:
          App.Target:
            enum: { local: {}, remote: { box: "Lib.Box?", next: "Array<App.Target>", item: some T } }
            typeParameters: ["T: App.Named"]
            satisfies: [App.Named]
            types: { Item: Lib.Box }
            procedures:
              describe: { parameters: [ { name: of, type: "App.Target<some T>" } ] }
        contracts:
          App.Named: {}
        procedures:
          App.main:
            body:
              - value: { call: { procedure: App.Target.describe } }
              - value: { as: { of: { case: { local: {} } }, type: "App.Target<Lib.Box>" } }
        """)))
    }

    @Test("a short name two declarations share is refused where it is written")
    func aSharedShortNameIsRefused() throws {
        // Given
        let library = try parser.parse("procedures: { Lib.shout: {}, Other.shout: {} }")
        let text = try parser.parse("""
        procedures:
          f: { body: [ { value: { call: { procedure: shout } } } ] }
        """)
        let sut = try Naming(of: text, reading: Declarations().adding(library))

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.resolved(text)
        }

        // Then
        #expect(error?.message == "'shout' is declared by Lib.shout and Other.shout. Write the one you mean in full")
        #expect(error?.position == Origin.Position(line: 2, column: 35))
    }

    @Test("two extension heads that name one type are refused at the second")
    func twoHeadsOfOneTypeAreRefused() throws {
        // Given
        let library = try parser.parse("types: { Lib.Box: { struct: {} } }")
        let text = try parser.parse("""
        extensions:
          Lib.Box: {}
          Box: {}
        """)
        let sut = try Naming(of: text, reading: Declarations().adding(library))

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.resolved(text)
        }

        // Then
        #expect(error?.message == "'Lib.Box' is written twice under extensions, once short and once full")
        #expect(error?.position == Origin.Position(line: 3, column: 3))
    }
}
