//
//  BinaryWriter.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A tree as WARP-6's `.warp`: the magic, the format, then the tree as
// one value, each dictionary's keys in the key order.
struct BinaryWriter: Sendable {
    // MARK: - Property
    // "WARP", then the format version.
    private static let header: [UInt8] = [0x57, 0x41, 0x52, 0x50, 0x01]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    func write(_ tree: Tree) throws -> Data {
        var bytes = Self.header

        try append(tree, to: &bytes)

        return Data(bytes)
    }

    // MARK: - Private
    // A tag byte, then its payload.
    private func append(_ tree: Tree, to bytes: inout [UInt8]) throws {
        switch tree.content {
        case .null:
            bytes.append(0x00)

        case let .bool(value):
            bytes.append(value ? 0x02 : 0x01)

        case let .int(value):
            // ZigZag, then unsigned LEB128.
            bytes.append(0x03)
            append(UInt64(bitPattern: (Int64(value) << 1) ^ (Int64(value) >> 63)), to: &bytes)

        case let .double(value):
            guard value.isFinite else {
                throw AuthoringError("\(value) is not finite, and Warp numbers are finite", at: tree)
            }

            bytes.append(0x04)
            bytes.append(contentsOf: withUnsafeBytes(of: value.bitPattern.bigEndian, Array.init))

        case let .string(value):
            bytes.append(0x05)
            append(value, to: &bytes)

        case let .array(elements):
            bytes.append(0x06)
            append(UInt64(elements.count), to: &bytes)

            for element in elements {
                try append(element, to: &bytes)
            }

        case let .dictionary(entries):
            bytes.append(0x07)
            append(UInt64(entries.count), to: &bytes)

            for (key, value) in entries.sorted(by: { lhs, rhs in precedes(lhs.key, rhs.key) }) {
                bytes.append(0x05)
                append(key, to: &bytes)

                try append(value, to: &bytes)
            }
        }
    }

    // Unsigned LEB128: seven bits a byte, low bits first.
    private func append(_ value: UInt64, to bytes: inout [UInt8]) {
        var rest = value

        while rest >= 0x80 {
            bytes.append(UInt8(rest & 0x7F) | 0x80)
            rest >>= 7
        }

        bytes.append(UInt8(rest))
    }

    // Its length, then its UTF-8 bytes as written.
    private func append(_ string: String, to bytes: inout [UInt8]) {
        let utf8 = Array(string.utf8)

        append(UInt64(utf8.count), to: &bytes)
        bytes.append(contentsOf: utf8)
    }

    // The key order between two strings: the UTF-8 bytes of their composed
    // spellings.
    private func precedes(_ lhs: String, _ rhs: String) -> Bool {
        lhs.precomposedStringWithCanonicalMapping.utf8
            .lexicographicallyPrecedes(rhs.precomposedStringWithCanonicalMapping.utf8)
    }
}
