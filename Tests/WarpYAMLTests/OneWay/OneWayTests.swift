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
        let written = try sut.written(text)

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
        let written = try sut.written(text)

        // Then
        #expect(written == (try parser.parse("""
        warp: 1
        imports: []
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
        let written = try sut.written(text)

        // Then
        #expect(written["warp"] == 1)
        #expect(written["imports"]?.arrayValue?.compactMap(\.stringValue) == [
            "Lib.Box", "Lib.Cast", "Lib.Hashed", "Lib.Input", "Lib.Named", "Lib.Point", "Lib.Shape", "Lib.Size", "Lib.Tag",
            "Lib.seed", "Standard.Numeric.plus"
        ])
    }

    @Test("an imports list writing claims and no name has the names filled in beside them")
    func claimsAloneHaveTheNamesFilledIn() throws {
        // Given
        let written = try sut.written(try parser.parse("""
        imports: [ "T.Card: App.Describable" ]
        procedures: { f: { body: [ { value: { call: { procedure: Lib.used } } } ] } }
        """))

        // When / Then
        #expect(written["imports"] == ["Lib.used", "T.Card: App.Describable"])
    }

    @Test("a version and imports the text writes stand, and what is made stands at the document")
    func whatTheTextWritesStands() throws {
        // Given
        let written = try sut.written(try parser.parse("""
        imports: [ Lib.Kept ]
        procedures: { f: { body: [ { value: { call: { procedure: Lib.used } } } ] } }
        """))

        // When
        let version = written["warp"]

        // Then
        #expect(written["imports"] == ["Lib.Kept"])
        #expect(version == 1)
        #expect(version?.position == written.position)
        #expect(version?.isImplicit == true)
    }
}
