//
//  EachForm.swift
//  WarpYAML
//
//  Created by JSilver on 9/22/26.
//

import Foundation

// A walk over an array's elements, written as the walk: `of` is the array,
// `as` the element each round reads, `index` the position where the body
// wants it, and `body` runs once per element. It is spent here as an arm
// that always runs, reading the array once, and a loop over that value:
//
//     conditional when true
//         let <as> = <of>
//         let walk = loop
//             while: walk.index < count(<as>)
//             body:
//                 let <as> = <as>[walk.index]
//                 let <index> = walk.index      where the text names one
//                 <body>
//
// The array is held under the element's name, which each round's element
// shadows, so no name the text did not write is declared, and the arm keeps
// it from the statements after the walk.
struct EachForm {
    // The keys a walk is written with.
    private enum Key: String, CaseIterable {
        case of
        case `as`
        case index
        case body
    }

    // MARK: - Property
    static let key = "each"

    private static let count = "Standard.Collection.count"
    private static let lessThan = "Standard.Comparable.lessThan"

    // The field of a round that counts the rounds finished.
    private static let round = "index"

    // MARK: - Initializer
    // MARK: - Public
    // A statement whose `value` holds `each`, as the arm and the loop drawn
    // above: the arm at the walk, the array's binding
    // and the loop's condition where `of` is written, each round's element
    // and position where `as` and `index` are, and the loop under the
    // statement's own keys.
    static func spent(_ statement: Tree, holding walk: Tree) throws -> Tree {
        guard let fields = walk.dictionaryValue else {
            throw AuthoringError("each is a mapping of `of`, `as`, `index` and `body`", at: walk)
        }

        if let unknown = AuthoringError(keysOf: walk, outside: Set(Key.allCases.map(\.rawValue)), in: "each") {
            throw unknown
        }

        guard
            var keys = statement.dictionaryValue,
            let value = keys["value"],
            let array = fields[Key.of.rawValue],
            let element = fields[Key.as.rawValue],
            let body = fields[Key.body.rawValue]
        else {
            throw AuthoringError("each writes `of`, `as` and `body`", at: walk)
        }

        guard let statements = body.arrayValue else {
            throw AuthoringError("each's body is a list of statements", at: body)
        }

        guard let named = keys["let"] ?? keys["var"] else {
            throw AuthoringError("each is named: `let: <name>` binds the round the walk reads", at: value)
        }

        let index = fields[Key.index.rawValue]
        var read: [String] = []

        // The walk's, the element's and the position's names, in that order.
        for name in [named, element] + (index.map { index in [index] } ?? []) {
            guard let spelling = name.stringValue, Self.isValueName(spelling) else {
                throw AuthoringError(Self.valueNameRefusal(of: name), at: name)
            }

            guard !read.contains(spelling) else {
                throw AuthoringError(
                    "each binds the walk, the element and the position under separate names,"
                        + " and '\(spelling)' is two of them",
                    at: name
                )
            }

            read.append(spelling)
        }

        let reached = "\(read[0]).\(Self.round)"
        let position = walk.making(.dictionary(["ref": .string(reached)]))
        let condition = array.making(
            .dictionary([
                "call": .dictionary([
                    "procedure": .string(Self.lessThan),
                    "arguments": .array([
                        position,
                        .dictionary([
                            "call": .dictionary([
                                "procedure": .string(Self.count),
                                "arguments": .array([.dictionary(["ref": element])])
                            ])
                        ])
                    ])
                ])
            ])
        )
        var round = [
            element.making(
                .dictionary([
                    "let": element,
                    "value": .dictionary(["ref": .string("\(read[1])[\(reached)]")])
                ])
            )
        ]

        if let index {
            round.append(index.making(.dictionary(["let": index, "value": position])))
        }

        keys["value"] = value.holding(.dictionary([
            "loop": walk.making(.dictionary(["while": condition, "body": body.holding(.array(round + statements))]))
        ]))

        return walk.making(
            .dictionary([
                "value": .dictionary([
                    "conditional": .dictionary([
                        "when": .bool(true),
                        "then": .array([
                            array.making(.dictionary(["let": element, "value": array])),
                            statement.holding(.dictionary(keys))
                        ])
                    ])
                ])
            ])
        )
    }

    // MARK: - Private
    // Whether a name is one a path reads back as one name: no `.`, `[`, `]`
    // or `?` in it, and no white space at either end.
    private static func isValueName(_ spelling: String) -> Bool {
        guard let first = spelling.unicodeScalars.first, let last = spelling.unicodeScalars.last else { return false }

        return !spelling.contains { character in [".", "[", "]", "?"].contains(character) }
            && !CharacterSet.whitespacesAndNewlines.contains(first)
            && !CharacterSet.whitespacesAndNewlines.contains(last)
    }

    private static func valueNameRefusal(of name: Tree) -> String {
        guard let spelling = name.stringValue else { return "each binds names, written as strings" }

        return "'\(spelling)' is no name a path reads. A path is written with `.`, `[`, `]` and `?`,"
            + " so a name holding one, or white space at either end, is never the one it reaches"
    }
}
