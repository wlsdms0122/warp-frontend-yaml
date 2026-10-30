//
//  BinaryWriterTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("A tree written as the binary")
struct BinaryWriterTests {
    // MARK: - Property
    private let sut = BinaryWriter()

    // MARK: - Initializer
    // MARK: - Test
    @Test("the golden dictionary's tree is written as ENCODING.md lays it out")
    func theGoldenDictionaryIsWritten() throws {
        // Given. `ENCODING.md`'s golden dictionary but its bytes entry, which
        // no tree holds
        let tree: Tree = ["c": "hi", "a": 1, "d": 1.5, "b": [true, nil]]

        // When
        let written = try sut.write(tree)

        // Then
        #expect(written == Self.bytes("""
        57 41 52 50 01
        07 04
        05 01 61 03 02
        05 01 62 06 02 02 00
        05 01 63 05 02 68 69
        05 01 64 04 3F F8 00 00 00 00 00 00
        """))
    }

    @Test("a key led by a byte order mark keeps it and sorts by its bytes, as its case holds")
    func aKeyLedByAByteOrderMarkSortsByItsBytes() throws {
        // Given
        let tree: Tree = ["\u{FEFF}a": 2, "b": 1]

        // When
        let written = try sut.write(tree)

        // Then
        #expect(written == (try Self.caseBytes("a-key-led-by-a-byte-order-mark-sorts-by-its-bytes")))
    }

    @Test("an integer is zigzagged, then written seven bits a byte", arguments: [
        (0, "00"),
        (-1, "01"),
        (1, "02"),
        (64, "80 01"),
        (Int.max, "FE FF FF FF FF FF FF FF FF 01"),
        (Int.min, "FF FF FF FF FF FF FF FF FF 01")
    ])
    func anIntegerIsZigzagged(value: Int, payload: String) throws {
        // Given / When
        let written = try sut.write(.int(value))

        // Then
        #expect(written == Self.bytes("57 41 52 50 01 03 \(payload)"))
    }

    @Test("a tree as deep as the bound is written, and one deeper refuses")
    func theDepthBoundIsExact() throws {
        // Given
        let deepest = (1..<128).reduce(Tree.array([])) { inner, _ in .array([inner]) }
        let deeper = Tree.dictionary(["a": deepest])

        // When / Then
        #expect(try sut.write(deepest).count == 5 + 128 * 2)
        #expect(throws: AuthoringError.self) { try sut.write(deeper) }
    }

    @Test("a number that is not finite refuses")
    func aNumberNotFiniteRefuses() {
        // Given / When / Then
        #expect(throws: AuthoringError.self) { try sut.write(.double(.infinity)) }
        #expect(throws: AuthoringError.self) { try sut.write(.array([.double(.nan)])) }
    }

    // MARK: - Public
    // MARK: - Private
    private static func bytes(_ hex: String) -> Data {
        let digits = hex.filter(\.isHexDigit)

        return Data(stride(from: 0, to: digits.count, by: 2).compactMap { offset in
            let start = digits.index(digits.startIndex, offsetBy: offset)

            return UInt8(digits[start...digits.index(after: start)], radix: 16)
        })
    }

    // The `(bytes x"…")` a conformance case holds.
    private static func caseBytes(_ name: String) throws -> Data {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../warp/spec/conformance/\(name).test.warpt")
            .standardized
        let text = try String(contentsOf: file, encoding: .utf8)
        let hex = try #require(text.firstMatch(of: /\(bytes x"([0-9a-fA-F]*)"\)/)?.1)

        return bytes(String(hex))
    }
}
