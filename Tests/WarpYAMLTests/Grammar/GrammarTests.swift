//
//  GrammarTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A document tree's positions, each by its kind")
struct GrammarTests {
    // MARK: - Property
    private let sut = Grammar()

    // MARK: - Initializer
    // MARK: - Test
    @Test("each position of a document is handed to the rewrite as its kind")
    func eachPositionIsHandedAsItsKind() throws {
        // Given
        let document = try YAMLParser().parse("""
        types:
          App.Point: { struct: { x: Int }, satisfies: [Standard.Equatable], procedures: { norm: { returns: Int } } }
          App.Size: Int
        extensions:
          Array<some T>: { procedures: { second: {} } }
        contracts:
          App.Shape: { procedures: { area: { parameters: [{ name: shape, type: Self }] } } }
        const: { limit: 3 }
        var: { count: { type: Int, value: 0 } }
        procedures:
          App.main:
            parameters: [{ name: n, type: Int }]
            returns: Int
            body:
              - { let: a, type: Int, value: { ref: n } }
              - { set: count, value: { call: { procedure: App.f, arguments: [1, { ref: a }] } } }
              - value: { conditional: { when: true, then: [{ value: { return: 1 } }], else: [] } }
              - value: { loop: { while: false, body: [{ value: { break: null } }] } }
              - value: { call: { procedure: { ref: g }, arguments: { by: { as: { of: 1, type: Int } } } } }
              - value: { closure: { parameters: [{ name: y }], body: [{ value: { return: null } }] } }
        """)
        var handed: [(Grammar.Kind, Tree)] = []

        // When
        let walked = try sut.rewriting(document) { node, kind in
            handed.append((kind, node))

            return node
        }

        // Then
        let kinds = handed.map(\.0)
        let trees = { (kind: Grammar.Kind) in handed.filter { $0.0 == kind }.map(\.1) }

        #expect(walked == document)
        #expect(kinds.first == .document)
        #expect(kinds.contains(.procedure(.type("App.Point"), key: "norm")))
        #expect(kinds.contains(.procedure(.extension("Array<some T>"), key: "second")))
        #expect(kinds.contains(.procedure(.contract("App.Shape"), key: "area")))
        #expect(kinds.contains(.procedure(.document, key: "App.main")))
        #expect(kinds.filter { $0 == .closure }.count == 1)
        #expect(kinds.filter { $0 == .parameter }.count == 3)
        #expect(Set(trees(.type)) == ["Int", "Self"])
        #expect(trees(.type).count == 9)
        #expect(trees(.contract) == ["Standard.Equatable"])
        #expect(Set(trees(.path)) == ["n", "a", "count", "g"])
        #expect(trees(.callee) == ["App.f"])
        #expect(trees(.body).count == 5)
        #expect(trees(.statement).count == 9)
        #expect(Set(trees(.expression)).isSuperset(of: [3, 0, 1, true, false, ["ref": "a"], ["as": ["of": 1, "type": "Int"]]]))
    }

    @Test("a bound, a same type and a listed type parameter are handed as their kinds")
    func boundsAndTypeParametersAreHanded() throws {
        // Given
        let document = try YAMLParser().parse("""
        types:
          App.Box: { struct: { item: some T }, typeParameters: ["T: Hashable", U] }
        contracts:
          App.Bag: { types: [Item] }
        procedures:
          App.f:
            parameters: [{ name: x, type: "some T: Collection" }]
            bounds: { T.Element: Hashable & App.Named }
            sameTypes: { T.Index: Int }
        """)
        var handed: [(Grammar.Kind, Tree)] = []

        // When
        _ = try sut.rewriting(document) { node, kind in
            handed.append((kind, node))

            return node
        }

        // Then
        let trees = { (kind: Grammar.Kind) in handed.filter { $0.0 == kind }.map(\.1) }

        #expect(trees(.bound) == ["Hashable & App.Named"])
        #expect(Set(trees(.typeParameter)) == ["T: Hashable", "U", "Item"])
        #expect(Set(trees(.type)) == ["some T", "some T: Collection", "Int"])
    }

    @Test("the walk goes into what a rewrite gives, by its kind")
    func theWalkGoesIntoWhatARewriteGives() throws {
        // Given. A statement no document writes, rewritten into a return of
        // a path
        let document = try YAMLParser().parse("""
        procedures: { f: { body: [{ value: { shout: x } }] } }
        """)
        var paths: [Tree] = []

        // When
        let walked = try sut.rewriting(document) { node, kind in
            switch kind {
            case .statement where node["value"]?["shout"] != nil:
                return node.making(.dictionary(["value": ["return": ["ref": node["value"]?["shout"] ?? nil]]]))

            case .path:
                paths.append(node)

                return node

            default:
                return node
            }
        }

        // Then
        #expect(walked == ["procedures": ["f": ["body": [["value": ["return": ["ref": "x"]]]]]]])
        #expect(paths == ["x"])
    }

    @Test("a node the grammar does not write at its position is not walked into, and keeps its position")
    func aNodeTheGrammarDoesNotWriteIsNotWalked() throws {
        // Given. A mapping of two keys is no expression
        let document = try YAMLParser().parse("""
        const: { pair: { ref: a, call: b } }
        """)
        var kinds: [Grammar.Kind] = []

        // When
        let walked = try sut.rewriting(document) { node, kind in
            kinds.append(kind)

            return node
        }

        // Then
        #expect(kinds == [.document, .expression])
        #expect(walked["const"]?["pair"]?.position == document["const"]?["pair"]?.position)
        #expect(walked["const"]?.position == document["const"]?.position)
    }

    @Test("a procedure's full name is read off its owner", arguments: [
        (Grammar.Owner.document, "App.f"),
        (.type("App.Point"), "App.Point.f"),
        (.contract("App.Shape"), "App.Shape.f"),
        (.extension("Array<some T>"), "Array.f"),
        (.extension("App.Box<Int>?"), "Optional.f")
    ])
    func aProceduresFullNameIsReadOffItsOwner(owner: Grammar.Owner, name: String) {
        // Given / When
        let key = owner == .document ? "App.f" : "f"

        // Then
        #expect(owner.name(of: key) == name)
    }

    @Test("a head that names no type gives no procedure a name")
    func aHeadThatNamesNoTypeGivesNoName() {
        // Given / When / Then
        #expect(Grammar.Owner.extension("Array<").name(of: "f") == nil)
        #expect(Grammar.Owner.extension("some T").name(of: "f") == nil)
    }

    // MARK: - Public
    // MARK: - Private
}
