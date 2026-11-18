//
//  Recovery.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// A text read again one procedure body at a time, the unit a refused text
// is recovered at. A body reads the declarations and nothing of another
// body, so the text with every body emptied refuses what its declarations
// write, and the text holding one body alone refuses what that body
// writes.
struct Recovery {
    // MARK: - Property
    // The text with every procedure's body empty.
    let declarations: Tree

    // The text holding one procedure's body, the others empty, for each
    // procedure with a body.
    let bodies: [Tree]

    // MARK: - Initializer
    init(of text: Tree) throws {
        var held: [Grammar.Kind] = []

        _ = try Grammar().rewriting(text) { node, kind in
            if case .procedure = kind, Self.runs(node) {
                held.append(kind)
            }

            return node
        }

        self.declarations = try Self.text(text, holding: nil)
        self.bodies = try held.map { kept in try Self.text(text, holding: kept) }
    }

    // MARK: - Public
    // The text with the body of every procedure but `kept` empty, its
    // `result:` left out, and of every procedure where none is kept.
    static func text(_ text: Tree, holding kept: Grammar.Kind?) throws -> Tree {
        try Grammar().rewriting(text) { node, kind in
            guard case .procedure = kind, kind != kept, runs(node), var entries = node.dictionaryValue else {
                return node
            }

            entries["body"] = (entries["body"] ?? node).holding(.array([]))
            entries[StatementSugar.resultKey] = nil

            return node.holding(.dictionary(entries))
        }
    }

    // MARK: - Private
    // Whether a procedure writes what it runs: a body, or `result:`, which is
    // spent into one.
    private static func runs(_ procedure: Tree) -> Bool {
        procedure["body"] != nil || procedure[StatementSugar.resultKey] != nil
    }
}
