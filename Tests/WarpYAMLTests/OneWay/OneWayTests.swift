//
//  OneWayTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A spent tree finished the one way, with its version and its imports")
struct OneWayTests {
    // MARK: - Property
    private let parser = YAMLParser()
    private let sut = OneWay()

    // MARK: - Initializer
    // MARK: - Test
    @Test("a parameter written Any writes no type, a declaration's and a closure's alike")
    func anyIsLeftOut() throws {
        // Given
        let text = try parser.parse("""
        warp: 1
        imports: []
        procedures:
          f:
            parameters: [ { name: a, type: Any }, { name: b, type: Int } ]
            body:
              - value: { closure: { parameters: [ { name: c, type: Any } ], body: [] } }
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])

        // Then
        #expect(written == (try parser.parse("""
        warp: 1
        imports: []
        procedures:
          f:
            parameters: [ { name: a }, { name: b, type: Int } ]
            body:
              - value: { closure: { parameters: [ { name: c } ], body: [] } }
        """)))
    }

    @Test("what a declaration satisfies, what a procedure fails with and a contract's types stand in name order")
    func listsStandInNameOrder() throws {
        // Given. A contract's type is read up to its bound
        let text = try parser.parse("""
        warp: 1
        imports: []
        types:
          App.Card: { struct: {}, satisfies: [ Lib.Shape, App.Named ] }
        extensions:
          App.Card: { satisfies: [ Lib.Sized, Lib.Drawn ] }
        contracts:
          App.Named: { types: [ "Item2", "Item: Hashable" ] }
        procedures:
          f:
            failing: [ Lib.Late, App.Bad ]
            body:
              - value: { closure: { failing: [ Z, A ], body: [] } }
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])

        // Then
        #expect(written == (try parser.parse("""
        warp: 1
        imports: [ Lib.Drawn, Lib.Shape, Lib.Sized ]
        types:
          App.Card: { struct: {}, satisfies: [ App.Named, Lib.Shape ] }
        extensions:
          App.Card: { satisfies: [ Lib.Drawn, Lib.Sized ] }
        contracts:
          App.Named: { types: [ "Item: Hashable", "Item2" ] }
        procedures:
          f:
            failing: [ App.Bad, Lib.Late ]
            body:
              - value: { closure: { failing: [ A, Z ], body: [] } }
        """)))
    }

    @Test("a document says its version and what it uses and does not declare, in name order")
    func theVersionAndTheImportsAreWritten() throws {
        // Given. A send to the document's own procedure, a type's or a
        // contract's, a name the language declares and one `Self` names are
        // not imported, and what a procedure fails with names no type
        let text = try parser.parse("""
        types:
          App.Card: { struct: { size: Lib.Size, tags: "Array<Lib.Tag>" }, satisfies: [ Lib.Shape ], procedures: { make: {} } }
        extensions:
          "Lib.Box<some T: Lib.Named>": { procedures: { open: { returns: "Self.Item?" } } }
        contracts:
          App.Named: { types: [ "Item: Lib.Hashed" ], procedures: { name: { parameters: [ { name: of, type: Self } ] } } }
        const:
          seed: { call: { procedure: Lib.seed } }
        procedures:
          App.f:
            parameters: [ { name: x, type: "Dictionary<String, Int>" } ]
            failing: [ Lib.Bad ]
            body:
              - { let: y, type: Lib.Point, value: { as: { of: { ref: x }, type: Lib.Cast } } }
              - value: { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } }
              - value: { call: { procedure: App.f, arguments: [ { ref: x } ] } }
              - value: { call: { procedure: App.Card.make } }
              - value: { call: { procedure: App.Named.name, arguments: [ { ref: y } ] } }
              - value: { closure: { parameters: [ { name: z, type: Lib.Input } ], returns: Never, body: [] } }
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])

        // Then
        #expect(written["warp"] == 1)
        #expect(written["imports"]?.arrayValue?.compactMap(\.stringValue) == [
            "Lib.Box", "Lib.Cast", "Lib.Hashed", "Lib.Input", "Lib.Named", "Lib.Point", "Lib.Shape", "Lib.Size", "Lib.Tag",
            "Lib.seed", "Standard.Numeric.plus"
        ])
    }

    @Test("a type member after an applied type lists the type and the type member's spelling")
    func anAppliedTypesMemberListsBothNames() throws {
        // Given
        let text = try parser.parse("""
        procedures:
          App.echo:
            parameters: [ { name: x, type: "Lib.Wrapper<String>.Item" } ]
            returns: "Array<Lib.Box<Int>.Key>.Element?"
            body: []
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])

        // Then
        #expect(written["imports"] == ["Array.Element", "Lib.Box", "Lib.Box.Key", "Lib.Wrapper", "Lib.Wrapper.Item"])
    }

    @Test("a type member's spelling the document gives is not listed, given in a declaration or an extension")
    func aTypeMemberTheDocumentGivesIsNotListed() throws {
        // Given
        let text = try parser.parse("""
        types:
          App.Box: { struct: { item: Int }, types: { Item: Int } }
          App.Wrapper: { typeParameters: [ T ], struct: { item: some T }, types: { Item: some T } }
        extensions:
          Lib.Card: { types: { Key: String } }
        procedures:
          App.take:
            parameters: [ { name: a, type: App.Box.Item }, { name: b, type: Lib.Card.Key } ]
            returns: "App.Wrapper<Int>.Item"
            body: []
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])

        // Then
        #expect(written["imports"] == ["Lib.Card"])
    }

    @Test("the claims a document imports stand by the type and then by the contract, apart from the names")
    func importedClaimsStandInOrder() throws {
        // Given
        let text = try parser.parse("""
        procedures: { f: { body: [ { value: { call: { procedure: T.Card.make } } } ] } }
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [
            ImportedClaims.Claim("T.Card", "App.Describable"),
            ImportedClaims.Claim("T.Card", "App.Comparable"),
            ImportedClaims.Claim("App.Box", "Lib.Shown")
        ])

        // Then
        #expect(written["imports"] == ["T.Card.make"])
        #expect(written["importedClaims"] == [
            ["App.Box", "Lib.Shown"],
            ["T.Card", "App.Comparable"],
            ["T.Card", "App.Describable"]
        ])
    }

    @Test("a document importing no claim writes none, and what is made stands at the document")
    func whatIsMadeStandsAtTheDocument() throws {
        // Given
        let text = try parser.parse("""
        procedures: { f: { body: [ { value: { call: { procedure: Lib.used } } } ] } }
        """)

        // When
        let written = try sut.written(text, importing: try Imports(of: text).names, claiming: [])
        let version = written["warp"]

        // Then
        #expect(written["imports"] == ["Lib.used"])
        #expect(written["importedClaims"] == nil)
        #expect(version == 1)
        #expect(version?.position == written.position)
        #expect(version?.isImplicit == true)
    }
}
