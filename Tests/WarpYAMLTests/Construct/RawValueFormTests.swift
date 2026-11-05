//
//  RawValueFormTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/2/26.
//

import Foundation
import Testing
@testable import WarpYAML

// An enum written with raw values, spent as cases carrying nothing and the
// procedures the raw values are written as.
@Suite("The raw values an enum's cases write")
struct RawValueFormTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("raw values are a member returning a case's by a switch and a procedure returning the case of one")
    func rawValuesAreWrittenAsProcedures() throws {
        // Given / When. The text calls both directions by their short names
        let document = try sut.document(from: """
        name: App
        types:
          Level:
            enum: { low: "l", high: "h" }
            satisfies: [Hashable]
        procedures:
          entry:
            access: public
            parameters: [ raw: String ]
            returns: String
            body:
              - let: found
                value: { call: { procedure: Level.fromRawValue, arguments: [ { ref: raw } ] } }
            result: { Level.rawValue: { case: { high: {} } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Logic.equal ]
        types:
          App.Level:
            enum: { high: {}, low: {} }
            satisfies: [ Hashable ]
            procedures:
              rawValue:
                parameters: [ { name: of, type: App.Level } ]
                returns: String
                body:
                  - value:
                      switch:
                        of: { ref: of }
                        cases:
                          high: { then: [ { value: { return: h } } ] }
                          low: { then: [ { value: { return: l } } ] }
        procedures:
          App.Level.fromRawValue:
            parameters: [ { name: of, type: String } ]
            returns: "App.Level?"
            body:
              - value:
                  conditional:
                    when: { call: { procedure: Standard.Logic.equal, arguments: [ { ref: of }, l ] } }
                    then: [ { value: { return: { case: { low: {} } } } } ]
              - value:
                  conditional:
                    when: { call: { procedure: Standard.Logic.equal, arguments: [ { ref: of }, h ] } }
                    then: [ { value: { return: { case: { high: {} } } } } ]
              - value: { return: null }
          App.entry:
            access: public
            parameters: [ { name: raw, type: String } ]
            returns: String
            body:
              - { let: found, value: { call: { procedure: App.Level.fromRawValue, arguments: [ { ref: raw } ] } } }
              - value: { return: { call: { procedure: App.Level.rawValue, arguments: [ { case: { high: {} } } ] } } }
        """)
    }

    @Test("every raw value is of the type its scalar is read as, which the procedures take and return", arguments: [
        ("{ low: 1, high: 2 }", "Int"),
        ("{ low: 0.5, high: 1.5 }", "Double"),
        ("{ low: false, high: true }", "Bool"),
        ("{ low: \"1\", high: no }", "String")
    ])
    func aRawValueIsOfItsScalarsType(cases: String, type: String) throws {
        // Given
        let text = try YAMLParser().parse("types: { Level: { enum: \(cases), procedures: { label: {} } } }")

        // When
        let spent = try RawValueForm().spent(text)

        // Then. A member the text writes stands beside the one made
        let members = spent["types"]?["Level"]?["procedures"]

        #expect(spent["types"]?["Level"]?["enum"] == ["low": [:], "high": [:]])
        #expect(members?["label"] == [:])
        #expect(members?["rawValue"]?["returns"] == .string(type))
        #expect(spent["procedures"]?["Level.fromRawValue"]?["parameters"] == [["name": "of", "type": .string(type)]])
        #expect(spent["procedures"]?["Level.fromRawValue"]?["returns"] == "Level?")
    }

    @Test("an enum whose cases are mappings is written as the text writes it")
    func anEnumWithoutRawValuesStands() throws {
        // Given. A case written as nothing is no raw value
        let text = try YAMLParser().parse("types: { Target: { enum: { local: {}, remote: { port: Int }, none: null } } }")

        // When
        let spent = try RawValueForm().spent(text)

        // Then
        #expect(spent == text)
    }

    @Test("raw values that do not read are refused at the case, and a procedure the text writes at what it writes", arguments: [
        ("enum: { low: 1, high: h }", "", "'high' has a raw value of type String, and the enum's raw values are of one type, Int", 3, 28),
        ("enum: { low: 1, high: 1.5 }", "", "'high' has a raw value of type Double, and the enum's raw values are of one type, Int", 3, 28),
        (
            "enum: { low: l, remote: { port: Int } }",
            "",
            "'remote' is written as no raw value beside cases written as raw values: an enum with raw values writes every"
                + " case as its raw value, a String, an Int, a Double or a Bool",
            3,
            28
        ),
        (
            "enum: { low: l, none: null }",
            "",
            "'none' is written as no raw value beside cases written as raw values: an enum with raw values writes every"
                + " case as its raw value, a String, an Int, a Double or a Bool",
            3,
            28
        ),
        ("enum: { low: l, high: l }", "", "'high' has the raw value 'low' has, and no two cases share one", 3, 28),
        (
            "typeParameters: [T], enum: { low: l }",
            "",
            "an enum with raw values takes no type parameters: its cases carry nothing one stands in",
            3,
            12
        ),
        (
            "enum: { low: l }, procedures: { rawValue: {} }",
            "",
            "'rawValue' is made from the enum's raw values, so the text does not write it",
            3,
            44
        ),
        (
            "enum: { low: l }",
            "procedures: { Level.fromRawValue: {} }",
            "'Level.fromRawValue' is made from the enum's raw values, so the text does not write it",
            4,
            15
        ),
        (
            "enum: { low: l }",
            "procedures: { App.Level.fromRawValue: {} }",
            "'App.Level.fromRawValue' is made from the enum's raw values, so the text does not write it",
            4,
            15
        )
    ])
    func rawValuesThatDoNotReadAreRefused(
        declaration: String,
        procedures: String,
        message: String,
        line: Int,
        column: Int
    ) throws {
        // Given
        let text = "name: App\ntypes:\n  Level: { \(declaration) }\n\(procedures)\n"

        // When
        let error = refusal {
            try sut.document(from: text)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: line, column: column))
    }

    @Test("an enum with raw values in a dependency text gives both procedures short names")
    func aDependencysEnumRawValuesAreNamedShort() throws {
        // Given
        let sut = try sut.depending(on: [.text("name: Lib\ntypes: { Level: { enum: { low: 1, high: 2 } } }\n", module: "Lib")])

        // When
        let document = try sut.document(from: """
        procedures:
          entry:
            returns: Int?
            result: { call: { procedure: Level.rawValue, arguments: { of: { call: { procedure: Level.fromRawValue, arguments: [ 2 ] } } } } }
        uses: [ Lib ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.Level.fromRawValue, Lib.Level.rawValue ]
        procedures:
          entry:
            returns: "Int?"
            body:
              - value:
                  return:
                    call:
                      procedure: Lib.Level.rawValue
                      arguments: [ { call: { procedure: Lib.Level.fromRawValue, arguments: [ 2 ] } } ]
        """)
    }

    @Test("a node made from raw values reads the position of its case, or of the enum key, and is not exact")
    func aMadeNodeReadsItsCase() throws {
        // Given
        let origin = try sut.document(from: """
        name: App
        types:
          Level:
            enum:
              low: 1
              high: 2
        """).origin
        let member: [Origin.Step] = ["types", "App.Level", "procedures", "rawValue"]
        let procedure: [Origin.Step] = ["procedures", "App.Level.fromRawValue"]

        // When
        let returns = origin.reading(member + ["returns"])
        let arm = origin.reading(member + ["body", 0, "value", "switch", "cases", "high", "then", 0])
        let conditional = origin.reading(procedure + ["body", 0, "value", "conditional", "when"])
        let made = origin.reading(["types", "App.Level", "enum", "high"])

        // Then
        #expect(!returns.exact)
        #expect(returns.position == Origin.Position(line: 4, column: 5))
        #expect(!arm.exact)
        #expect(arm.position == Origin.Position(line: 6, column: 7))
        #expect(!conditional.exact)
        #expect(conditional.position == Origin.Position(line: 5, column: 7))
        #expect(!made.exact)
        #expect(made.position == Origin.Position(line: 6, column: 7))
    }
}
