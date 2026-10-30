//
//  OperatorSpelling.swift
//  WarpYAML
//
//  Created by JSilver on 9/22/26.
//

import Foundation

// A call written as an operator. `{ of: <expression>, <operator>: <expression> }`
// calls the operator's procedure with the subject first and the operand
// second, and `{ <operator>: <expression> }` calls it with what is written
// under the key alone. A connective takes a list of expressions, and a
// spelling against a fixed operand takes its expression alone. Read wherever
// an expression is, and spent before a document is written.
//
// A key the table does not hold is sent as written beside a subject:
// `{ of: x, Standard.Text.contains: y }`. Alone, a mapping of one key is a
// spelling where the key is one this notation names or a procedure the text
// or a document it leans on declares. Whether the procedure exists is the
// build's to say.
struct OperatorSpelling {
    // MARK: - Property
    // The subject beside an operator key, handed first whatever the
    // procedure calls it.
    static let subjectKey = "of"

    // Which operator keys reach a procedure here, and what each reaches.
    let operators: [Name: Spelling]

    // MARK: - Initializer
    init(operators: [Name: Spelling]) {
        self.operators = operators
    }

    // MARK: - Public
    // Whether a mapping of this one key is an operator mapping whatever a
    // text declares: the subject, which is never alone, or a key the table
    // holds, which alone is the table's.
    func claims(_ key: String) -> Bool {
        guard let name = try? Name(key) else { return false }

        return key == Self.subjectKey || operators[name] != nil
    }

    // The call an operator mapping spells, at the operator key, and nothing
    // for a mapping this does not claim: one carrying no subject and holding
    // another key than one the table holds or one that names a declared
    // procedure by `naming`.
    func call(of mapping: Tree, reading naming: Naming) throws -> Tree? {
        guard let entries = mapping.dictionaryValue else { return nil }

        let subject = entries[Self.subjectKey]

        if subject == nil {
            guard entries.count == 1, let only = entries.first, let key = try? Name(only.key) else { return nil }

            // A key two declarations share is claimed, and refused below.
            let named: Bool

            do {
                named = try naming.declared(key, in: .procedure) != nil
            } catch {
                named = true
            }

            guard operators[key] != nil || named else { return nil }
        }

        let found = entries.keys.filter { key in key != Self.subjectKey }.sorted()

        guard found.count == 1, let written = found.first, let operand = entries[written] else {
            throw AuthoringError(
                "an operator mapping is one operator, with or without its subject."
                    + " { of: <expression>, <operator>: <expression> } or { <operator>: <expression> };"
                    + " found: \(found)",
                at: mapping
            )
        }

        guard let key = try? Name(written) else {
            throw AuthoringError("'\(written)' cannot be an operator's procedure", at: operand)
        }

        let spelling: Spelling

        do {
            spelling = try self.spelling(of: key, subject: subject != nil, reading: naming)
        } catch {
            throw AuthoringError(error, at: mapping)
        }

        // The subject first where the text writes one, then the operand.
        let given = [subject, operand].compactMap { tree in tree }
        let arguments: [Tree] = switch spelling.form {
        case .connective:
            [try Self.deferred(operand, by: key)]

        case let .against(value):
            [operand, operand.making(value)]

        case .flipped:
            given.reversed()

        case .unary, .binary, .either:
            given
        }

        return mapping.holding(
            .dictionary([
                "call": operand.making(
                    .dictionary(["procedure": .string(spelling.procedure.spelling), "arguments": .array(arguments)])
                )
            ])
        )
    }

    // MARK: - Private
    // What the key reaches, read off `naming` as `spelling(of:subject:in:at:)`
    // reads it off a notation.
    private func spelling(of key: Name, subject: Bool, reading naming: Naming) throws(AuthoringError) -> Spelling {
        let declared: Name?

        do {
            declared = try naming.declared(key, in: .procedure)
        } catch {
            guard operators[key] == nil else { return try formed(operators[key], of: key, subject: subject) }

            throw error
        }

        if let declared, declared != operators[key]?.procedure {
            guard operators[key]?.form.yieldsToTheText ?? true else {
                throw AuthoringError("\(key) is this notation's spelling. Write the declared '\(declared)' by its full name")
            }

            guard subject || operators[key] == nil else {
                throw AuthoringError(
                    "'\(key)' alone is this notation's operator, and '\(declared)' is declared"
                        + " by that name too. Call the declared one with `call`, or write the operator beside `of`"
                )
            }

            return try formed(Spelling(procedure: declared, form: .either), of: key, subject: subject)
        }

        return try formed(operators[key], of: key, subject: subject)
    }

    // The spelling, or the key sent as written where there is none, held to
    // whether its form takes a subject.
    private func formed(_ spelling: Spelling?, of key: Name, subject: Bool) throws(AuthoringError) -> Spelling {
        let spelling = spelling ?? Spelling(procedure: key, form: .either)

        switch (spelling.form.subject, subject) {
        case (.required, false):
            throw AuthoringError("\(key) needs a subject. { of: <expression>, \(key): <expression> }")

        case (.refused, true):
            throw AuthoringError("`of` does not accompany \(key). It takes what is written under it, not a subject")

        default:
            return spelling
        }
    }

    // Each side of a connective as a closure returning it. The closure's
    // signature is its slot's, which the closures' pass writes.
    private static func deferred(_ sides: Tree, by key: Name) throws -> Tree {
        guard let elements = sides.arrayValue else {
            throw AuthoringError("\(key) takes a list of expressions", at: sides)
        }

        return sides.holding(.array(elements.map(deferring)))
    }

    private static func deferring(_ side: Tree) -> Tree {
        let statement: Tree = .dictionary(["value": .dictionary(["return": side])])

        return side.making(.dictionary(["closure": .dictionary(["body": .array([statement])])]))
    }
}
