//
//  DeclarationCollectorTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A text's declarations are collected into the tree Declarations reads")
struct DeclarationCollectorTests {
    // MARK: - Property
    private let sut: DeclarationCollector

    // MARK: - Initializer
    init() throws {
        self.sut = DeclarationCollector(leaningOn: try Declarations.standard())
    }

    // MARK: - Test
    @Test("a text's declarations are its prefixed keys, each signature with its types in full")
    func aTextsDeclarationsAreCollected() throws {
        // Given
        let text = try YAMLParser().parse("""
        name: Shop
        types:
          Item:
            struct: { price: Int }
            procedures:
              describe:
                description: What the item is called
                parameters: [ of: Item ]
                returns: String
        contracts:
          Priced:
            procedures:
              price: { parameters: [ of: Self ], returns: Int }
        extensions:
          Item:
            procedures:
              cheaper: { parameters: [ of: Item, than: Int ], returns: Bool }
          "Array<some T: Comparable>":
            procedures:
              smallest: { parameters: [ of: "Array<some T>" ], returns: Int }
        procedures:
          total:
            access: public
            parameters:
              - items: Array<Item>
              - discount: { type: Int, default: 0, hint: percent }
              - note: {}
            returns: Int
            failing: [ empty ]
          sorted:
            access: private
            const: true
            parameters: [ { name: of, type: "some T: Comparable" } ]
            returns: some T
        """)

        // When
        let collected = try sut.collected(text)

        // Then
        let expected: Tree = [
            "types": [
                "Shop.Item": [
                    "procedures": [
                        "describe": ["parameters": [["name": "of", "type": "Shop.Item"]], "returns": "String"]
                    ]
                ]
            ],
            "contracts": [
                "Shop.Priced": [
                    "procedures": ["price": ["parameters": [["name": "of", "type": "Self"]], "returns": "Int"]]
                ]
            ],
            "extensions": [
                "Shop.Item": [
                    "procedures": [
                        "cheaper": [
                            "parameters": [["name": "of", "type": "Shop.Item"], ["name": "than", "type": "Int"]],
                            "returns": "Bool"
                        ]
                    ]
                ],
                "Array<some T: Standard.Comparable>": [
                    "procedures": [
                        "smallest": ["parameters": [["name": "of", "type": "Array<some T>"]], "returns": "Int"]
                    ]
                ]
            ],
            "procedures": [
                "Shop.total": [
                    "access": "public",
                    "parameters": [
                        ["name": "items", "type": "Array<Shop.Item>"],
                        ["name": "discount", "type": "Int?"],
                        ["name": "note"]
                    ],
                    "returns": "Int",
                    "failing": ["empty"]
                ],
                "Shop.sorted": [
                    "access": "private",
                    "const": true,
                    "parameters": [["name": "of", "type": "some T: Standard.Comparable"]],
                    "returns": "some T"
                ]
            ]
        ]

        #expect(collected == expected)
    }

    @Test("a defaulted parameter written with no type is declared as an Optional of anything")
    func aDefaultedParameterWithNoTypeIsAnyOptional() throws {
        // Given
        let text = try YAMLParser().parse("""
        procedures:
          greet:
            parameters: [ { who: { default: world } } ]
            returns: String
        """)

        // When
        let collected = try sut.collected(text)

        // Then
        #expect(collected["procedures"]?["greet"]?["parameters"] == [["name": "who", "type": "Any?"]])
    }

    @Test("a declaration whose key is no name is left out, for the load to refuse")
    func aKeyThatIsNoNameIsLeftOut() throws {
        // Given. A name is written, and in normal form C
        let text = try YAMLParser().parse("""
        name: Shop
        types:
          "": { struct: { price: Int } }
          Item: { struct: { price: Int } }
        contracts:
          "": { procedures: { price: { parameters: [ of: Self ], returns: Int } } }
        procedures:
          "cafe\\u0301": { parameters: [ of: Int ], returns: Int }
          total: { returns: Int }
        """)

        // When
        let collected = try sut.collected(text)

        // Then
        let expected: Tree = [
            "types": ["Shop.Item": [:]],
            "contracts": [:],
            "procedures": ["Shop.total": ["returns": "Int"]]
        ]

        #expect(collected == expected)
    }

    @Test("a short name two declarations share in a type is refused, so the text is not collected")
    func anAmbiguousTypeIsRefused() throws {
        // Given
        let sut = DeclarationCollector(leaningOn: Declarations().adding(types: ["A.Card", "B.Card"]))
        let text = try YAMLParser().parse("""
        procedures:
          show: { parameters: [ of: Card ], returns: String }
        """)

        // When / Then
        #expect(throws: AuthoringError.self) { try sut.collected(text) }
    }

    @Test("a declaration that does not read is refused where it is written, before any call to it is matched")
    func aDeclarationThatDoesNotReadIsRefusedWhereItIsWritten() throws {
        // Given. The probe's text: `pair` is called by name beside a
        // declaration whose type does not read
        let text = try YAMLParser().parse("""
        name: App
        procedures:
          broken:
            parameters: [ a: "Array<" ]
          pair:
            parameters: [ a: Int, b: Int ]
          entry:
            body:
              - value: { call: { procedure: pair, arguments: { b: 2, a: 1 } } }
        """)

        // When
        let error = #expect(throws: AuthoringError.self) {
            try sut.collected(text)
        }

        // Then
        #expect(error?.message == "'Array<' does not read as a type")
        #expect(error?.position == Origin.Position(line: 4, column: 19))
    }

    // MARK: - Public
    // MARK: - Private
}
