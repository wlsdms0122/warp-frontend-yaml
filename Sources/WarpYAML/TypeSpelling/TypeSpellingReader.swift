//
//  TypeSpellingReader.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The type grammar over one string, in the one spelling's spacing: a string
// spaced another way, `Array< Int>`, reads as no type. The order of a
// procedure type's modifiers, a composition's names and a throws clause's
// failures is read as written.
struct TypeSpellingReader {
    // MARK: - Property
    // How deep a type may be written inside another within the string, which
    // bounds this reader's recursion. The document's bound counts on from the
    // containers around the string, and the load holds it.
    private static let depthBound = 128

    // What a name ends at.
    private static let cuts: Set<Unicode.Scalar> = [" ", "<", ">", ",", "(", ")", "?", "&", ":"]

    private let string: String
    private let scalars: [Unicode.Scalar]
    private var index = 0

    // MARK: - Initializer
    init(_ string: String) {
        self.string = string
        self.scalars = Array(string.unicodeScalars)
    }

    // MARK: - Public
    mutating func read() throws(AuthoringError) -> TypeSpelling {
        let type = try self.type(depth: 0)

        guard index == scalars.count else { throw refusal }

        return type
    }

    // MARK: - Private
    private var refusal: AuthoringError {
        AuthoringError("'\(string)' does not read as a type")
    }

    private mutating func type(depth: Int) throws(AuthoringError) -> TypeSpelling {
        guard depth <= Self.depthBound else {
            throw AuthoringError("'\(string)' nests deeper than \(Self.depthBound) types")
        }

        if consume("inout ") { return .inout(try type(depth: depth + 1)) }
        if consume("var ") { return .variable(try type(depth: depth + 1)) }
        if consume("some ") { return try parameter() }

        let modifiers = self.modifiers()

        guard modifiers.isEmpty else {
            guard !isAt("(") else {
                return try procedure(modifiers, parameters: try listed(depth: depth), depth: depth)
            }
            guard try self.name() == "Procedure" else { throw refusal }

            return .unsaidProcedure(modifiers: modifiers)
        }

        guard !isAt("(") else { return try parenthesized(depth: depth) }

        let name = try self.name()

        guard !consume(" & ") else {
            return optionals(.composition(try [name, self.name()] + self.names(joinedBy: " & ")))
        }
        guard consume("<") else { return optionals(.named(name, arguments: [])) }

        let arguments = try types(depth: depth, closedBy: ">")

        return switch (name, arguments.count) {
        case ("Array", 1): optionals(.array(arguments[0]))
        case ("Dictionary", 2): optionals(.dictionary(key: arguments[0], value: arguments[1]))
        default: optionals(.named(name, arguments: arguments))
        }
    }

    // A procedure type's parameters, or a type grouped in parentheses before
    // its `?`.
    private mutating func parenthesized(depth: Int) throws(AuthoringError) -> TypeSpelling {
        let listed = try self.listed(depth: depth)

        guard isAt("?") else { return try procedure([], parameters: listed, depth: depth) }
        guard listed.count == 1, listed[0].isGrouped else { throw refusal }

        return optionals(listed[0])
    }

    // What follows a procedure type's parameters: its throws clause and what
    // it returns.
    private mutating func procedure(
        _ modifiers: [ProcedureModifier],
        parameters: [TypeSpelling],
        depth: Int
    ) throws(AuthoringError) -> TypeSpelling {
        let failing = try self.throwsClause()

        guard consume(" -> ") else { throw refusal }

        return .procedure(
            modifiers: modifiers,
            parameters: parameters,
            failing: failing,
            returns: try type(depth: depth + 1)
        )
    }

    private mutating func throwsClause() throws(AuthoringError) -> ThrowsClause? {
        guard consume(" throws") else { return nil }
        guard consume("(") else { return .anything }
        guard !consume(")") else { return .names([]) }

        let listed = try [name()] + names(joinedBy: ", ")

        guard consume(")") else { throw refusal }

        return .names(listed)
    }

    // The types between parentheses, none or more.
    private mutating func listed(depth: Int) throws(AuthoringError) -> [TypeSpelling] {
        index += 1

        guard !consume(")") else { return [] }

        return try types(depth: depth, closedBy: ")")
    }

    private mutating func parameter() throws(AuthoringError) -> TypeSpelling {
        let name = try self.name()

        guard consume(": ") else { return optionals(.parameter(name, bounds: [])) }

        return .parameter(name, bounds: try [self.name()] + names(joinedBy: " & "))
    }

    private mutating func modifiers() -> [ProcedureModifier] {
        var modifiers: [ProcedureModifier] = []

        while let modifier = [ProcedureModifier.const, .isolated].first(where: { modifier in
            !modifiers.contains(modifier) && isAt("\(modifier.rawValue) ")
        }) {
            index += modifier.rawValue.unicodeScalars.count + 1
            modifiers.append(modifier)
        }

        return modifiers
    }

    // Types parted by `, ` up to the closing scalar, at least one, each a
    // level deeper than the type holding them.
    private mutating func types(depth: Int, closedBy close: String) throws(AuthoringError) -> [TypeSpelling] {
        var types = [try self.type(depth: depth + 1)]

        while consume(", ") {
            types.append(try self.type(depth: depth + 1))
        }

        guard consume(close) else { throw refusal }

        return types
    }

    // The names after the first, each after `separator`.
    private mutating func names(joinedBy separator: String) throws(AuthoringError) -> [String] {
        var names: [String] = []

        while consume(separator) {
            names.append(try self.name())
        }

        return names
    }

    private mutating func name() throws(AuthoringError) -> String {
        let start = index

        while index < scalars.count, !Self.cuts.contains(scalars[index]) {
            index += 1
        }

        guard index > start else { throw refusal }

        return String(String.UnicodeScalarView(scalars[start..<index]))
    }

    private mutating func optionals(_ type: TypeSpelling) -> TypeSpelling {
        var type = type

        while consume("?") {
            type = .optional(type)
        }

        return type
    }

    private func isAt(_ text: String) -> Bool {
        let expected = Array(text.unicodeScalars)

        return scalars.count - index >= expected.count && Array(scalars[index..<index + expected.count]) == expected
    }

    private mutating func consume(_ text: String) -> Bool {
        guard isAt(text) else { return false }

        index += text.unicodeScalars.count

        return true
    }
}
