//
//  Name.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A name as the specification holds one: written, so never empty, and in
// Unicode normal form C, so one name has one byte spelling and a
// declaration and a reference meet only by being the same bytes. Names are
// ordered by their UTF-8 bytes. Canonical equivalence between two strings
// in normal form C is byte equality, so a name is equal and hashed by its
// spelling.
public struct Name: Sendable, Hashable, Comparable, CustomStringConvertible {
    // MARK: - Property
    public let spelling: String

    // An identifier as every encoding writes one bare: an ASCII letter or
    // `_`, then ASCII letters, digits and `_`.
    public var isIdentifier: Bool {
        guard let first = spelling.utf8.first, Self.isLetter(first) else { return false }

        return spelling.utf8.allSatisfy { byte in Self.isLetter(byte) || (0x30...0x39).contains(byte) }
    }

    public var description: String { spelling }

    // MARK: - Initializer
    public init(_ spelling: String) throws(AuthoringError) {
        guard !spelling.isEmpty else {
            throw AuthoringError("a name is written, and this one is empty")
        }

        // ASCII is its own normal form.
        guard
            spelling.utf8.allSatisfy({ byte in byte < 0x80 })
                || spelling.precomposedStringWithCanonicalMapping.utf8.elementsEqual(spelling.utf8)
        else {
            throw AuthoringError("the name '\(spelling)' is not in normal form C")
        }

        self.spelling = spelling
    }

    // MARK: - Public
    public static func < (lhs: Name, rhs: Name) -> Bool {
        lhs.spelling.utf8.lexicographicallyPrecedes(rhs.spelling.utf8)
    }

    // MARK: - Private
    private static func isLetter(_ byte: UInt8) -> Bool {
        (0x41...0x5A).contains(byte) || (0x61...0x7A).contains(byte) || byte == 0x5F
    }
}
