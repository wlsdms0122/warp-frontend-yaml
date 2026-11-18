//
//  RawValueForm.swift
//  WarpYAML
//
//  Created by JSilver on 11/2/26.
//

import Foundation

// An enum with raw values, written with every case a scalar, its raw value,
// in the place of the fields it carries. Every raw value is of one type,
// `String`, `Int`, `Double` or `Bool`, no two cases share one, and the enum
// takes no type parameters, since its cases carry nothing one stands in:
//
//     types:
//       Level:
//         enum: { low: "l", high: "h" }
//
// The document has no raw value (WARP-93), so the cases carry nothing and
// the raw values are written as two procedures, the way WARP-93's notes say
// a source language's raw values are written:
//
//     types:
//       Level:
//         enum: { low: {}, high: {} }
//         procedures:
//           rawValue:                    the member, by a switch over `of`
//             parameters: [ of: Level ]
//             returns: String
//       procedures:
//         Level.fromRawValue:            the case whose raw value `of` is,
//           parameters: [ of: String ]   else null
//           returns: Level?
//
// A member takes a value of its type first (WARP-58), so `fromRawValue` is
// declared under the document's `procedures`, spelled under the enum's key.
struct RawValueForm {
    // MARK: - Property
    private static let rawValueKey = "rawValue"
    private static let fromRawValueKey = "fromRawValue"

    private static let typesKey = "types"
    private static let enumKey = "enum"
    private static let proceduresKey = "procedures"
    private static let typeParametersKey = "typeParameters"
    private static let parameterName = "of"
    private static let equal = "Standard.Logic.equal"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // A text's tree with each enum written with raw values spent, before its
    // names are read, so the procedures it makes are the text's own and take
    // its `name:` prefix. An enum whose cases are all mappings, and a case
    // table that is no mapping, are left as written.
    func spent(_ document: Tree) throws -> Tree {
        guard var entries = document.dictionaryValue, let types = entries[Self.typesKey]?.dictionaryValue else {
            return document
        }

        var declared = types
        var made: [String: Tree] = [:]
        var madeAt: Tree?

        for (key, declaration) in Self.ordered(types) {
            guard
                var fields = declaration.dictionaryValue,
                let table = fields[Self.enumKey],
                let cases = table.dictionaryValue,
                cases.values.contains(where: { written in Self.rawType(of: written) != nil })
            else {
                continue
            }

            if let typeParameters = fields[Self.typeParametersKey] {
                throw AuthoringError(
                    "an enum with raw values takes no type parameters: its cases carry nothing one stands in",
                    at: typeParameters
                )
            }

            let ordered = Self.ordered(cases)
            let rawType = try Self.rawType(of: ordered)
            let spelling = "\(key).\(Self.fromRawValueKey)"
            let rawValue = Self.rawValue(ordered, of: key, as: rawType, at: table)

            try Self.refuseWritten(Self.rawValueKey, in: fields[Self.proceduresKey]?.dictionaryValue)
            try Self.refuseWritten(spelling, in: entries[Self.proceduresKey]?.dictionaryValue)

            if let prefix = entries[Naming.key]?.stringValue {
                try Self.refuseWritten("\(prefix).\(spelling)", in: entries[Self.proceduresKey]?.dictionaryValue)
            }

            fields[Self.enumKey] = table.holding(.dictionary(cases.mapValues { written in
                written.making(.dictionary([:]))
            }))

            if let members = fields[Self.proceduresKey], var given = members.dictionaryValue {
                given[Self.rawValueKey] = rawValue
                fields[Self.proceduresKey] = members.holding(.dictionary(given))
            } else if fields[Self.proceduresKey] == nil {
                fields[Self.proceduresKey] = table.making(.dictionary([Self.rawValueKey: rawValue]))
            }

            declared[key] = declaration.holding(.dictionary(fields))
            made[spelling] = Self.fromRawValue(ordered, of: key, as: rawType, at: table)
            madeAt = madeAt ?? table
        }

        guard let madeAt else { return document }

        entries[Self.typesKey] = entries[Self.typesKey]?.holding(.dictionary(declared))

        if let procedures = entries[Self.proceduresKey] {
            if let written = procedures.dictionaryValue {
                entries[Self.proceduresKey] = procedures.holding(.dictionary(written.merging(made) { written, _ in written }))
            }
        } else {
            entries[Self.proceduresKey] = madeAt.making(.dictionary(made))
        }

        return document.holding(.dictionary(entries))
    }

    // MARK: - Private
    // The one type an enum's raw values are of. A case written as no raw
    // value, a raw value of another type than the first case's, and a raw
    // value an earlier case has are refused at the case.
    private static func rawType(of cases: [(key: String, value: Tree)]) throws -> String {
        var type: String?
        var seen: [Tree.Content: String] = [:]

        for (name, written) in cases {
            guard let read = rawType(of: written) else {
                throw AuthoringError(
                    "'\(name)' is written as no raw value beside cases written as raw values: an enum with raw"
                        + " values writes every case as its raw value, a String, an Int, a Double or a Bool",
                    at: written
                )
            }

            if let type, read != type {
                throw AuthoringError(
                    "'\(name)' has a raw value of type \(read), and the enum's raw values are of one type, \(type)",
                    at: written
                )
            }

            if let earlier = seen[written.content] {
                throw AuthoringError("'\(name)' has the raw value '\(earlier)' has, and no two cases share one", at: written)
            }

            type = read
            seen[written.content] = name
        }

        return type ?? ""
    }

    // The type of a raw value a case writes, and nothing for a case written
    // as no scalar of those types.
    private static func rawType(of written: Tree) -> String? {
        switch written.content {
        case .string:
            "String"

        case .int:
            "Int"

        case .double:
            "Double"

        case .bool:
            "Bool"

        case .null, .array, .dictionary:
            nil
        }
    }

    // The member returning a value's raw value: a switch over the value, an
    // arm per case returning its raw value, made at the case.
    private static func rawValue(
        _ cases: [(key: String, value: Tree)],
        of enumeration: String,
        as rawType: String,
        at table: Tree
    ) -> Tree {
        var arms: [String: Tree] = [:]

        for (name, written) in cases {
            arms[name] = written.making(.dictionary(["then": .array([returning(written)])]))
        }

        let switched: Tree = .dictionary([
            "value": .dictionary([
                "switch": .dictionary([
                    "of": .dictionary(["ref": .string(parameterName)]),
                    "cases": .dictionary(arms)
                ])
            ])
        ])

        return table.making(.dictionary([
            "parameters": .array([.dictionary(["name": .string(parameterName), "type": .string(enumeration)])]),
            "returns": .string(rawType),
            "body": .array([switched])
        ]))
    }

    // The procedure returning the case whose raw value it is handed: a
    // conditional per case, made at the case, returning its case literal
    // where the value is its raw value, and `null` past them.
    private static func fromRawValue(
        _ cases: [(key: String, value: Tree)],
        of enumeration: String,
        as rawType: String,
        at table: Tree
    ) -> Tree {
        let conditionals = cases.map { name, written in
            let when: Tree = .dictionary([
                "call": .dictionary([
                    "procedure": .string(equal),
                    "arguments": .array([.dictionary(["ref": .string(parameterName)]), written])
                ])
            ])
            let literal: Tree = .dictionary(["case": .dictionary([name: .dictionary([:])])])

            return written.making(.dictionary([
                "value": .dictionary([
                    "conditional": .dictionary(["when": when, "then": .array([returning(literal)])])
                ])
            ]))
        }

        return table.making(.dictionary([
            "parameters": .array([.dictionary(["name": .string(parameterName), "type": .string(rawType)])]),
            "returns": .string("\(enumeration)?"),
            "body": .array(conditionals + [returning(.null)])
        ]))
    }

    // `{ value: { return: <returned> } }`.
    private static func returning(_ returned: Tree) -> Tree {
        .dictionary(["value": .dictionary(["return": returned])])
    }

    // A procedure the text writes under the name of one this form makes,
    // refused at what it writes.
    private static func refuseWritten(_ name: String, in procedures: [String: Tree]?) throws {
        guard let written = procedures?[name] else { return }

        throw AuthoringError(
            "'\(name)' is made from the enum's raw values, so the text does not write it",
            at: written
        )
    }

    // A mapping's entries in the order the text writes them.
    private static func ordered(_ entries: [String: Tree]) -> [(key: String, value: Tree)] {
        entries.sorted { lhs, rhs in
            let left = lhs.value.position.map { position in [position.line, position.column] } ?? []
            let right = rhs.value.position.map { position in [position.line, position.column] } ?? []

            return left == right ? lhs.key < rhs.key : left.lexicographicallyPrecedes(right)
        }
    }
}
