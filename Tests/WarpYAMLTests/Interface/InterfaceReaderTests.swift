//
//  InterfaceReaderTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("An interface text reads into its tree")
struct InterfaceReaderTests {
    // MARK: - Property
    // Type nodes and the string each writes in the tree, from the text's
    // table of types, and nodes the load refuses that the text writes.
    private static let typeNodes: [(node: String, string: String)] = [
        ("Self.Item", "Self.Item"),
        ("(array T)", "Array<T>"),
        ("(dictionary K V)", "Dictionary<K, V>"),
        ("(named App.Box Int String)", "App.Box<Int, String>"),
        ("(optional T)", "T?"),
        ("(optional (procedure (const)))", "(const Procedure)?"),
        ("(optional (some W App.Named))", "(some W: App.Named)?"),
        ("(composition A B)", "A & B"),
        ("(some T App.Named Hashable)", "some T: App.Named & Hashable"),
        ("(some T.Item)", "some T.Item"),
        ("(inout T)", "inout T"),
        ("(var T)", "var T"),
        ("(procedure (const) (isolated) (parameters A (inout B)) (failing x) (returns R))", "const isolated (A, inout B) throws(x) -> R"),
        ("(procedure (parameters) (failing (anything)) (returns Int))", "() throws -> Int"),
        ("(procedure (parameters) (failing) (returns Int))", "() throws() -> Int"),
        ("(procedure (const))", "const Procedure"),
        ("(procedure (isolated) (const))", "isolated const Procedure"),
        ("(named Dictionary Int)", "Dictionary<Int>"),
        ("(some Self)", "some Self")
    ]

    // Type nodes whose string reads back as another node, or that write no
    // type.
    private static let refusedTypeNodes = [
        "(named Array Int)",
        "(composition A)",
        "(named App.Box)",
        "(optional (inout T))",
        "(procedure)",
        "(procedure (parameters A))",
        "(procedure (returns R) (parameters))",
        "a>b",
        "(array Int Int)",
        "\"Int\""
    ]

    // Texts refused, each with the line and column the refusal names.
    private static let refusals: [(text: String, line: Int, column: Int)] = [
        ("(interface 1)\n(const seven 7)", 2, 1),
        ("(interface 1)\n(var count (type Int) 0)", 2, 1),
        ("(interface 1)\n(procedure App.g\n  (body (return 1)))", 3, 3),
        ("(interface 1)\n(procedure App.g (access public))", 2, 18),
        ("(warp 1)", 1, 1),
        ("(interface 2)\n(procedure App.g)", 1, 1),
        ("(interface 1)\n(procedure App.g (returns Int) (returns Int))", 2, 32),
        ("(interface 1)\n(procedure App.g)\n(procedure App.g)", 3, 1),
        ("(interface 1)\n(struct App.Box (field x Int) (field x Int))", 2, 31),
        ("(interface 1)\r\n(type App.Ratio 1.50)", 2, 17),
        ("(interface 1)\r(import \"a\u{0001}\")", 2, 11),
        ("(interface 1)\n(import \"\\u000a\")", 2, 10),
        ("(interface 1)\n(import App\"x\")", 2, 12),
        ("(interface 1)\n(import `é`x)", 2, 12),
        ("(interface 1)\n(import x\"0G\")", 2, 9),
        ("(interface 1)\n(import +1)", 2, 9),
        ("(interface 1)\n(import 9223372036854775808)", 2, 9),
        ("(interface 1)\n(import App.Point)\n)", 3, 1),
        ("(interface 1)\nApp", 2, 1),
        ("(interface 1)\n(import App.Point: Hashable)", 2, 9),
        ("(interface 1)\n(type App.T (array Int Int))", 2, 13)
    ]

    // MARK: - Initializer
    // MARK: - Test
    @Test("the text's example interface reads into its tree")
    func theExampleInterfaceReads() throws {
        // Given
        let sut = InterfaceReader()
        let text = """
        (interface 1)
        (import Standard.Comparable)
        (struct App.Range (field low Int) (field high Int))
        (contract App.Named (procedure name (parameter of (type Self)) (returns String)))
        (extension (head Int) (satisfies App.Named) (procedure name (parameter of (type Int)) (returns String)))
        (procedure App.largest (parameter of (type (array (some T Standard.Comparable)))) (returns (optional (some T))))
        """

        // When
        let tree = try sut.read(Data(text.utf8))

        // Then
        let name: Tree = ["parameters": [["name": "of", "type": "Self"]], "returns": "String"]
        let member: Tree = ["parameters": [["name": "of", "type": "Int"]], "returns": "String"]

        #expect(
            tree == [
                "interface": 1,
                "imports": ["Standard.Comparable"],
                "types": ["App.Range": ["struct": ["low": "Int", "high": "Int"]]],
                "contracts": ["App.Named": ["procedures": ["name": name]]],
                "extensions": ["Int": ["satisfies": ["App.Named"], "procedures": ["name": member]]],
                "procedures": [
                    "App.largest": [
                        "parameters": [["name": "of", "type": "Array<some T: Standard.Comparable>"]],
                        "returns": "some T?"
                    ]
                ]
            ]
        )
    }

    @Test("declarations and a signature read each node into its key")
    func declarationNodesRead() throws {
        // Given
        let sut = InterfaceReader()
        let text = """
        (interface 1)
        (import App.Point Hashable)
        (type App.Id Int)
        (struct App.Box
          (typeParameter K App.Named Hashable)
          (typeParameter V)
          (satisfies App.Named App.Other)
          (field balance (var Int))
          (type Item K)
          (procedure area (parameter box (type (named App.Box K V))) (returns Int)))
        (contract App.Named
          (type Item Hashable)
          (type Key)
          (procedure name (const) (parameter self (type Self)) (returns String)))
        (extension (head (array Int))
          (satisfies App.Named)
          (type Item Int)
          (procedure name (parameter of (type (array Int))) (returns String)))
        (procedure App.g
          (const)
          (isolated)
          (parameter f)
          (parameter of (type (some C App.Container)))
          (returns Int)
          (failing aborted cast_refused)
          (bound C.Item Hashable App.Named)
          (sameType C.Key Int))
        (procedure App.h (failing (anything)))
        """

        // When
        let tree = try sut.read(Data(text.utf8))

        // Then
        #expect(tree["imports"] == ["App.Point: Hashable"])
        #expect(tree["types"]?["App.Id"] == "Int")
        #expect(
            tree["types"]?["App.Box"] == [
                "struct": ["balance": "var Int"],
                "typeParameters": ["K: App.Named & Hashable", "V"],
                "satisfies": ["App.Named", "App.Other"],
                "types": ["Item": "K"],
                "procedures": ["area": ["parameters": [["name": "box", "type": "App.Box<K, V>"]], "returns": "Int"]]
            ]
        )
        #expect(tree["contracts"]?["App.Named"]?["types"] == ["Item: Hashable", "Key"])
        #expect(tree["contracts"]?["App.Named"]?["procedures"]?["name"]?["const"] == true)
        #expect(tree["extensions"]?["Array<Int>"]?["types"] == ["Item": "Int"])
        #expect(
            tree["procedures"]?["App.g"] == [
                "const": true,
                "isolated": true,
                "parameters": [["name": "f"], ["name": "of", "type": "some C: App.Container"]],
                "returns": "Int",
                "failing": ["aborted", "cast_refused"],
                "bounds": ["C.Item": "Hashable & App.Named"],
                "sameTypes": ["C.Key": "Int"]
            ]
        )
        #expect(tree["procedures"]?["App.h"] == ["failing": "anything"])
    }

    @Test("a type node writes the string the tree holds for it", arguments: typeNodes)
    func aTypeNodeWritesItsString(_ node: String, _ string: String) throws {
        // Given
        let sut = InterfaceReader()

        // When
        let tree = try sut.read(Data("(interface 1)\n(type App.T \(node))".utf8))

        // Then
        #expect(tree["types"]?["App.T"] == .string(string))
    }

    @Test("a type node with no tree is refused at the node", arguments: refusedTypeNodes)
    func aTypeNodeWithNoTreeIsRefused(_ node: String) {
        // Given
        let sut = InterfaceReader()

        // When
        let refusal = #expect(throws: AuthoringError.self) {
            try sut.read(Data("(interface 1)\n(type App.T \(node))".utf8))
        }

        // Then
        #expect(refusal?.position?.line == 2)
    }

    @Test("a text the interface does not read is refused at its line and column", arguments: refusals)
    func aRefusalNamesItsPlace(_ text: String, _ line: Int, _ column: Int) {
        // Given
        let sut = InterfaceReader()

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut.read(Data(text.utf8)) }

        // Then
        #expect(refusal?.position == Origin.Position(line: line, column: column), "\(refusal?.message ?? "")")
    }

    @Test("bytes that are no UTF-8 are refused as a whole")
    func noUTF8IsRefusedAsAWhole() {
        // Given
        let sut = InterfaceReader()

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut.read(Data([0x28, 0xff, 0x29])) }

        // Then
        #expect(refusal?.position == nil)
    }

    @Test("lists nest at most 257 deep")
    func listsNestAtMost257Deep() throws {
        // Given
        let sut = InterfaceReader()
        let deepest = "(interface 1)\n(type App.T " + String(repeating: "(x ", count: 256) + String(repeating: ")", count: 257)
        let deeper = "(interface 1)\n(type App.T " + String(repeating: "(x ", count: 257) + String(repeating: ")", count: 258)

        // When
        let reachedLayer = #expect(throws: AuthoringError.self) { try sut.read(Data(deepest.utf8)) }
        let refusal = #expect(throws: AuthoringError.self) { try sut.read(Data(deeper.utf8)) }

        // Then
        #expect(reachedLayer?.message.contains("257") == false)
        #expect(refusal?.message.contains("257") == true)
        #expect(refusal?.position == Origin.Position(line: 2, column: 13 + 3 * 256))
    }

    @Test("a type's nodes nest at most 128 levels")
    func typeNodesNestAtMost128Levels() async throws {
        // Given
        let sut = InterfaceReader()
        let deepest = String(repeating: "(array ", count: 128) + "Int" + String(repeating: ")", count: 128)

        // When
        let read = await onALargeStack { try sut.read(Data("(interface 1)\n(type App.T \(deepest))".utf8)) }
        let deeper = await onALargeStack { try sut.read(Data("(interface 1)\n(type App.T (array \(deepest)))".utf8)) }
        let tree = try read.get()
        let refusal = #expect(throws: AuthoringError.self) { try deeper.get() }

        // Then
        #expect(tree["types"]?["App.T"]?.stringValue?.hasSuffix("<Int" + String(repeating: ">", count: 128)) == true)
        #expect(refusal?.message.contains("128") == true)
    }

    @Test("a name, a string and a number read in their one spelling, layout free")
    func atomsReadInTheirOneSpelling() throws {
        // Given
        let sut = InterfaceReader()
        let text = "(interface 1)\t\r\n  (import `App.a b` )\n(import\n`App.\\`q\\``)\n(import null`)"

        // When
        let refusal = #expect(throws: AuthoringError.self) { try sut.read(Data(text.utf8)) }
        let tree = try sut.read(Data("(interface 1)\t\r\n  (import `App.a b` )\n(import\n`App.\\`q\\``)".utf8))

        // Then
        #expect(refusal?.position == Origin.Position(line: 5, column: 13))
        #expect(tree["imports"] == ["App.a b", "App.`q`"])
    }

    @Test("Standard's interface reads")
    func standardsInterfaceReads() throws {
        // Given
        let sut = InterfaceReader()
        let text = try Data(contentsOf: Self.standardInterface)

        // When
        let tree = try sut.read(text)

        // Then
        #expect(tree["interface"] == 1)
        #expect(tree["contracts"]?.dictionaryValue?.keys.sorted() == ["Standard.Collection", "Standard.Comparable", "Standard.Numeric"])
        #expect(tree["extensions"]?.dictionaryValue?.keys.sorted() == ["Array", "Dictionary", "Double", "Int", "String"])
        #expect(
            tree["procedures"]?["Standard.Collection.map"]?["parameters"] == [
                ["name": "array", "type": "Array<some Element>"],
                ["name": "transform", "type": "const isolated (some Element) -> some Result"]
            ]
        )
        #expect(
            tree["procedures"]?["Standard.Concurrent.all"]?["parameters"] == [
                ["name": "pieces", "type": "Array<isolated () throws -> some Result>"]
            ]
        )
    }

    // MARK: - Public
    // MARK: - Private
    private static var standardInterface: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../warp/lib/standard/interface/standard.interface.warpt")
            .standardized
    }
}
