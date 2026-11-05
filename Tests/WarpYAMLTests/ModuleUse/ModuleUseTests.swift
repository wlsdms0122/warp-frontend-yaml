//
//  ModuleUseTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// A text reads the declarations of its own module, of `Standard` and of the
// modules it names under `uses:`, and a name none of them declares is
// refused where it is written.
@Suite("A text uses the modules it names")
struct ModuleUseTests {
    // MARK: - Property
    // A module giving a procedure of its own and a member of `Int`.
    private static let library = """
    name: Lib
    extensions:
      Int: { procedures: { describe: { access: public, parameters: [ of: Int ], returns: String, result: "int" } } }
    procedures:
      make: { access: public, returns: Int, result: 1 }
    """

    // MARK: - Initializer
    // MARK: - Test
    @Test("a text using a module reads its names, a member it gives a type the language names among them")
    func aTextReadsTheModulesItUses() throws {
        // Given
        let sut = try YAMLFrontend().depending(on: [.text(Self.library, module: "Lib")])

        // When
        let document = try sut.document(from: """
        uses: [ Lib ]
        procedures:
          entry:
            returns: "Array<Any>"
            result: [ { call: { procedure: make } }, { call: { procedure: Int.describe, arguments: [ 2 ] } } ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Int.describe, Lib.make ]
        procedures:
          entry:
            returns: "Array<Any>"
            body:
              - value: { return: [ { call: { procedure: Lib.make } }, { call: { procedure: Int.describe, arguments: [ 2 ] } } ] }
        """)
    }

    @Test("the text's own declaration shadows one of a module it uses, its signature among it")
    func theTextsOwnShadowsAModulesDeclaration() throws {
        // Given
        let sut = try YAMLFrontend().depending(on: [.text(Self.library, module: "Lib")])

        // When
        let document = try sut.document(from: """
        uses: [ Lib ]
        extensions:
          Int: { procedures: { describe: { parameters: [ of: Int, loud: Bool ], returns: String, result: "own" } } }
        procedures:
          entry:
            returns: String
            result: { call: { procedure: Int.describe, arguments: { of: 2, loud: true } } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        extensions:
          Int:
            procedures:
              describe:
                parameters: [ { name: of, type: Int }, { name: loud, type: Bool } ]
                returns: String
                body: [ { value: { return: own } } ]
        procedures:
          entry:
            returns: String
            body: [ { value: { return: { call: { procedure: Int.describe, arguments: [ 2, true ] } } } } ]
        """)
    }

    @Test("a name no module the text uses declares is refused where it is written, naming the module that declares it", arguments: [
        ("{ call: { procedure: Lib.make } }", "no module the text uses declares 'Lib.make'. Lib declares it: write Lib under uses"),
        ("{ call: { procedure: make } }", "no module the text uses declares 'make'. Lib declares it: write Lib under uses"),
        (
            "{ call: { procedure: Int.describe, arguments: [ 2 ] } }",
            "no module the text uses declares 'Int.describe'. Lib declares it: write Lib under uses"
        ),
        (
            "{ call: { procedure: Int.describe, arguments: { of: 2 } } }",
            "no module the text uses declares 'Int.describe'. Lib declares it: write Lib under uses"
        ),
        ("{ make: [] }", "no module the text uses declares 'make'. Lib declares it: write Lib under uses"),
        ("{ of: 2, Int.describe: [] }", "no module the text uses declares 'Int.describe'. Lib declares it: write Lib under uses")
    ])
    func aNameAModuleNotUsedDeclaresRefuses(expression: String, message: String) throws {
        // Given
        let sut = try YAMLFrontend().depending(on: [.text(Self.library, module: "Lib")])

        // When
        let error = refusal {
            try sut.document(from: """
            procedures:
              entry:
                returns: Any
                result: \(expression)
            """)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position?.line == 4)
    }

    @Test("a one-key mapping under a statement's value that is no construct is a call, refused where nothing declares it")
    func aKeyNoConstructIsAnUndeclaredCall() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let error = refusal {
            try sut.document(from: """
            procedures:
              entry:
                body:
                  - value:
                      unless: { when: false, body: [] }
            """)
        }

        // Then
        #expect(
            error?.message == "no module the text uses declares 'unless'."
                + " A mapping keyed by a name calls it, and a dictionary is written under `dictionary`"
        )
        #expect(error?.position?.line == 5)
    }

    @Test("a callee a mapping's key names that no module declares is refused saying how a dictionary is written", arguments: [
        (
            "{ topic: hi }",
            "no module the text uses declares 'topic'. A mapping keyed by a name calls it, and a dictionary is written under `dictionary`",
            15
        ),
        (
            "{ of: 1, topic: 2 }",
            "no module the text uses declares 'topic'. A mapping keyed by a name calls it, and a dictionary is written under `dictionary`",
            22
        ),
        ("{ call: { procedure: topic } }", "no module the text uses declares 'topic'", 23)
    ])
    func aKeyNoModuleDeclaresRefuses(expression: String, message: String, column: Int) throws {
        // Given
        let sut = try YAMLFrontend().depending(on: [.text(Self.library, module: "Lib")])

        // When
        let error = refusal {
            try sut.document(from: """
            procedures:
              entry:
                returns: Any
                result: \(expression)
            """)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: 4, column: column))
    }

    @Test("a name several modules the text does not use declare is refused naming each of them")
    func aNameSeveralModulesNotUsedDeclareRefuses() throws {
        // Given
        let sut = try YAMLFrontend().depending(on: [
            .text(Self.library, module: "Lib"),
            .text("name: Other\nprocedures: { make: { access: public, returns: Int, result: 2 } }", module: "Other")
        ])

        // When
        let error = refusal {
            try sut.document(from: """
            procedures:
              entry:
                returns: Any
                result: { call: { procedure: make } }
            """)
        }

        // Then
        #expect(error?.message == "no module the text uses declares 'make'. Lib, Other declare it: write one of them under uses")
        #expect(error?.position?.line == 4)
    }

    @Test("a name no module declares is refused where it is written")
    func aNameNoModuleDeclaresRefuses() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let error = refusal {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ { name: point, type: Geometry.Point } ]
                body: []
            """)
        }

        // Then
        #expect(error?.message == "no module the text uses declares 'Geometry.Point'")
        #expect(error?.position == Origin.Position(line: 3, column: 34))
    }

    @Test("Standard is used whether or not the text names it", arguments: ["", "uses: [ Standard ]\n"])
    func standardIsAlwaysUsed(uses: String) throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let document = try sut.document(from: uses + """
        procedures:
          entry:
            returns: Int
            result: { call: { procedure: plus, arguments: [ 1, 2 ] } }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Numeric.plus ]
        procedures:
          entry:
            returns: Int
            body: [ { value: { return: { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } } } } ]
        """)
    }

    @Test("the texts spent together are one module, each reading the others with no uses")
    func textsSpentTogetherAreOneModule() throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let spent = try sut.document(from: [
            "name: Lib\nprocedures:\n  make: { access: public, returns: Int, result: 1 }",
            "procedures:\n  entry: { returns: Int, result: { call: { procedure: make } } }"
        ])

        // Then
        try expectDocument(spent, is: """
        warp: 1
        imports: []
        procedures:
          Lib.make:
            access: public
            returns: Int
            body: [ { value: { return: 1 } } ]
          entry:
            returns: Int
            body: [ { value: { return: { call: { procedure: Lib.make } } } } ]
        """)
    }

    @Test("every part handed under one name is one module")
    func partsUnderOneNameAreOneModule() throws {
        // Given
        let declared = Data("(interface 1)\n(procedure Lib.fetch (returns String))".utf8)
        let sut = try YAMLFrontend().depending(on: [
            .text(Self.library, module: "Lib"),
            .interface(declared, module: "Lib")
        ])

        // When
        let document = try sut.document(from: """
        uses: [ Lib ]
        procedures:
          entry:
            returns: "Array<Any>"
            result: [ { call: { procedure: make } }, { call: { procedure: fetch } } ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Lib.fetch, Lib.make ]
        procedures:
          entry:
            returns: "Array<Any>"
            body: [ { value: { return: [ { call: { procedure: Lib.make } }, { call: { procedure: Lib.fetch } } ] } } ]
        """)
    }

    @Test("a module the front end does not depend on is refused where the text names it, with the modules it does")
    func aModuleNotHandedRefuses() throws {
        // Given
        let sut = try YAMLFrontend()
        let handed = try sut.depending(on: [
            .text("name: Other\nprocedures: {}", module: "Other"),
            .text(Self.library, module: "Lib")
        ])

        // When
        let error = refusal {
            try sut.document(from: "uses: [ Native ]\nprocedures: {}")
        }
        let besideHanded = refusal {
            try handed.document(from: "uses: [ Native ]\nprocedures: {}")
        }

        // Then
        #expect(error?.message == "no module 'Native' is handed to the front end. It is handed none")
        #expect(error?.position == Origin.Position(line: 1, column: 9))
        #expect(besideHanded?.message == "no module 'Native' is handed to the front end. It is handed Lib, Other")
    }

    @Test("uses that is no list of identifiers is refused where it is written", arguments: [
        ("uses: Lib", "'uses' is a list of the modules the text uses", 1, 1),
        ("uses: [ Lib.Sub ]", "a module is named by an identifier", 1, 9),
        ("uses: [ 1 ]", "a module is named by an identifier", 1, 9)
    ])
    func aUsesThatDoesNotReadRefuses(text: String, message: String, line: Int, column: Int) throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let error = refusal { try sut.document(from: text) }

        // Then
        #expect(error?.message == message)
        #expect(error?.position == Origin.Position(line: line, column: column))
    }

    @Test("a module is named by an identifier that is not Standard's", arguments: [
        ("Lib.Sub", "a module is named by an identifier"),
        ("Standard", "'Standard' is the language's module, which every text uses")
    ])
    func aModuleNameThatDoesNotReadRefuses(module: String, message: String) throws {
        // Given
        let sut = try YAMLFrontend()

        // When
        let error = refusal {
            try sut.depending(on: [.text(Self.library, module: try Name(module))])
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.text == 0)
    }

    // MARK: - Public
    // MARK: - Private
}
