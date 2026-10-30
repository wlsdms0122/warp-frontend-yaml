//
//  CasesForm.swift
//  WarpYAML
//
//  Created by JSilver on 9/22/26.
//

import Foundation

// A conditional with more than one way through, written flat: the arms in
// order, each a `when` and its `then`, and an `else` arm last for what runs
// when no `when` held. The document has one conditional with one `else`, so
// this is that conditional nested once per arm, and it is spent here.
//
//     cases:
//       - when: <expression>
//         then: [<statements>]
//       - when: <expression>
//         then: [<statements>]
//       - else: [<statements>]
struct CasesForm {
    // The keys an arm is written with.
    private enum Key: String, CaseIterable {
        case when
        case then
        case `else`
    }

    // MARK: - Property
    static let key = "cases"

    // The containers each arm after the first nests its conditional below
    // the one before: the `else` list, its statement, the statement's
    // value and the conditional's parts.
    private static let containersPerArm = 4

    // MARK: - Initializer
    // MARK: - Public
    // A statement whose `value` holds `cases`, with the conditional the arms
    // are nested into in its place: each arm's conditional at the arm, and
    // the next arm's in its `else`. The statement keeps its other keys, so a
    // name on it is the load's to refuse.
    static func spent(_ statement: Tree, holding cases: Tree) throws -> Tree {
        guard let arms = cases.arrayValue else {
            throw AuthoringError("cases is a list of cases, each a `when` and its `then`, or an `else` alone", at: cases)
        }

        var branches: [(arm: Tree, when: Tree, then: Tree)] = []
        var otherwise: Tree?

        for (position, arm) in arms.enumerated() {
            guard let fields = arm.dictionaryValue else {
                throw AuthoringError(Self.armShape, at: arm)
            }

            if let unknown = AuthoringError(keysOf: arm, outside: Set(Key.allCases.map(\.rawValue)), in: "a case") {
                throw unknown
            }

            if let body = fields[Key.else.rawValue] {
                guard fields.count == 1 else { throw AuthoringError(Self.armShape, at: arm) }
                guard otherwise == nil else { throw AuthoringError("cases holds one `else` arm", at: arm) }

                otherwise = body

                continue
            }

            guard
                let when = fields[Key.when.rawValue],
                let then = fields[Key.then.rawValue]
            else {
                throw AuthoringError(Self.armShape, at: arm)
            }

            guard otherwise == nil else {
                throw AuthoringError("the `else` arm comes last, and case \(position) follows it", at: arm)
            }
            // Counted from the statement holding the cases, so a case
            // refused here nests past the bound wherever the statement
            // stands.
            guard branches.count < BinaryWriter.depthBound / Self.containersPerArm else {
                throw AuthoringError(
                    "case \(position) nests its conditional deeper than \(BinaryWriter.depthBound) containers",
                    at: arm
                )
            }

            branches.append((arm, when, then))
        }

        guard let first = branches.first else {
            throw AuthoringError("cases holds at least one case, a `when` and its `then`", at: cases)
        }

        var nested = otherwise

        for branch in branches.dropFirst().reversed() {
            nested = branch.arm.making(
                .array([.dictionary(["value": conditional(branch.when, then: branch.then, else: nested, at: branch.arm)])])
            )
        }

        guard var fields = statement.dictionaryValue, let value = fields["value"] else { return statement }

        fields["value"] = value.holding(conditional(first.when, then: first.then, else: nested, at: first.arm).content)

        return statement.holding(.dictionary(fields))
    }

    // MARK: - Private
    private static let armShape = "a case is a `when` and its `then`, or an `else` alone"

    // `{ conditional: { when, then, else } }` at an arm.
    private static func conditional(_ when: Tree, then: Tree, else otherwise: Tree?, at arm: Tree) -> Tree {
        var parts = ["when": when, "then": then]
        parts["else"] = otherwise

        return arm.making(.dictionary(["conditional": .dictionary(parts)]))
    }
}
