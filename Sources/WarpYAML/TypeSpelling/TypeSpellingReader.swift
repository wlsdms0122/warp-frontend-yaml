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
        let type = try self.type()

        guard index == scalars.count else { throw refusal }

        return type
    }

    // MARK: - Private
    private var refusal: AuthoringError {
        AuthoringError("'\(string)' does not read as a type")
    }

    private mutating func type() throws(AuthoringError) -> TypeSpelling {
        if consume("inout ") { return .inout(try type()) }
        if consume("var ") { return .variable(try type()) }
        if consume("some ") { return try parameter() }

        let modifiers = self.modifiers()

        guard modifiers.isEmpty else {
            guard !isAt("(") else {
                return try procedure(modifiers, parameters: try listed())
            }
            guard try self.name() == "Procedure" else { throw refusal }

            return .unsaidProcedure(modifiers: modifiers)
        }

        guard !isAt("(") else { return try parenthesized() }

        let name = try self.name()

        guard !consume(" & ") else {
            return optionals(.composition(try [name, self.name()] + self.names(joinedBy: " & ")))
        }
        guard consume("<") else { return optionals(.named(name, arguments: [])) }

        let arguments = try types(closedBy: ">")
        let applied: TypeSpelling = switch (name, arguments.count) {
        case ("Array", 1): .array(arguments[0])
        case ("Dictionary", 2): .dictionary(key: arguments[0], value: arguments[1])
        default: .named(name, arguments: arguments)
        }

        return optionals(try member(of: applied))
    }

    // A type member's name after an applied type's closing bracket, one
    // identifier ending the name, and the applied type itself where no dot
    // follows.
    private mutating func member(of applied: TypeSpelling) throws(AuthoringError) -> TypeSpelling {
        guard consume(".") else { return applied }

        let name = try self.name()

        guard !name.contains(".") else { throw refusal }

        return .member(applied, name: name)
    }

    // A procedure type's parameters, or a type grouped in parentheses before
    // its `?`.
    private mutating func parenthesized() throws(AuthoringError) -> TypeSpelling {
        let listed = try self.listed()

        guard isAt("?") else { return try procedure([], parameters: listed) }
        guard listed.count == 1, listed[0].isGrouped else { throw refusal }

        return optionals(listed[0])
    }

    // What follows a procedure type's parameters: its throws clause and what
    // it returns.
    private mutating func procedure(
        _ modifiers: [ProcedureModifier],
        parameters: [TypeSpelling]
    ) throws(AuthoringError) -> TypeSpelling {
        let failing = try self.throwsClause()

        guard consume(" -> ") else { throw refusal }

        return .procedure(
            modifiers: modifiers,
            parameters: parameters,
            failing: failing,
            returns: try type()
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
    private mutating func listed() throws(AuthoringError) -> [TypeSpelling] {
        index += 1

        guard !consume(")") else { return [] }

        return try types(closedBy: ")")
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

    // Types parted by `, ` up to the closing scalar, at least one.
    private mutating func types(closedBy close: String) throws(AuthoringError) -> [TypeSpelling] {
        var types = [try self.type()]

        while consume(", ") {
            types.append(try self.type())
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
