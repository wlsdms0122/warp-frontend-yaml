//
//  Grammar.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What each position of a document tree is, by `DOCUMENT.md`,
// `PROCEDURE.md`, `STATEMENT.md` and `EXPRESSION.md`. A pass rewrites the
// positions of one kind: the walk hands each node to the rewrite first, then
// walks into what the rewrite gave by the grammar of that kind. A node that
// is not what the grammar writes at its position is not walked into, and is
// left for the load to refuse.
struct Grammar {
    // What a position holds.
    enum Kind: Equatable {
        // The document's own dictionary.
        case document
        // A procedure declared by its key under an owner's `procedures`.
        case procedure(Owner, key: String)
        // A procedure written where a value is wanted.
        case closure
        // One entry of a procedure's `parameters`.
        case parameter
        // A type's spelling.
        case type
        // A contract's name, among what a type or an extension satisfies.
        case contract
        // Contracts joined with `&`, what a signature's `bounds` holds an
        // associated type to.
        case bound
        // A name a struct's `typeParameters` or a contract's `types` lists,
        // with its bound beside it where it has one, `"K: Hashable"`.
        case typeParameter
        // A list of statements.
        case body
        case statement
        case expression
        // A name and the segments read through it, a `ref`'s or a `set`'s.
        case path
        // A call's `procedure` written as a string: the declaration called.
        case callee
    }

    // What a procedure is declared under, by the key the text wrote.
    enum Owner: Equatable {
        // The document's own `procedures`.
        case document
        // A type under `types`, by its key.
        case type(String)
        // An extension under `extensions`, by its head.
        case `extension`(String)
        // A contract under `contracts`, by its key.
        case contract(String)

        // MARK: - Property
        // MARK: - Initializer
        // MARK: - Public
        // The full name of the procedure declared under this by `key`, and
        // nothing under a head that names no type.
        func name(of key: String) -> String? {
            switch self {
            case .document:
                key

            case let .type(owner), let .contract(owner):
                "\(owner).\(key)"

            case let .extension(head):
                (try? TypeSpelling(head))?.extendedType.map { type in "\(type).\(key)" }
            }
        }

        // MARK: - Private
    }

    typealias Rewrite = (Tree, Kind) throws -> Tree

    // MARK: - Property
    // The keys a statement's `value` holds a construct under.
    static let constructs: [String: [String: Kind]] = [
        "conditional": ["when": .expression, "then": .body, "else": .body],
        "loop": ["while": .expression, "body": .body],
        "try": ["body": .body, "catch": .body],
        "unwrap": ["of": .expression, "then": .body, "else": .body]
    ]
    // The leaving constructs, which hold no body: `return` an expression or
    // null, `break` and `continue` a loop's statement name or null.
    static let leaving: Set<String> = ["return", "break", "continue"]

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // Whether a statement's `value` holding this one key holds a construct,
    // read as the construct and not as an expression.
    static func claims(_ key: String) -> Bool {
        constructs[key] != nil || leaving.contains(key)
    }

    func rewriting(_ document: Tree, _ rewrite: Rewrite) throws -> Tree {
        try walk(document, as: .document, rewrite)
    }

    // The document walked once by several rewrites, each node handed to
    // each in order before the walk goes into what the last gave. Passes
    // that rewrite positions of different kinds walk together where each
    // writes what the other reads: a closure an operator mapping holds is
    // a closure once the mapping is a call.
    func rewriting(_ document: Tree, _ rewrites: [Rewrite]) throws -> Tree {
        try walk(document, as: .document) { node, kind in
            try rewrites.reduce(node) { rewritten, rewrite in try rewrite(rewritten, kind) }
        }
    }

    // MARK: - Private
    private func walk(_ tree: Tree, as kind: Kind, _ rewrite: Rewrite) throws -> Tree {
        let node = try rewrite(tree, kind)

        switch kind {
        case .document:
            return try document(node, rewrite)

        case .procedure, .closure:
            return try walk(node, under: ["returns": .type, "body": .body], rewrite) { key, value in
                switch key {
                case "parameters":
                    try walkElements(of: value, as: .parameter, rewrite)

                case "bounds":
                    try walkValues(of: value, as: .bound, rewrite)

                case "sameTypes":
                    try walkValues(of: value, as: .type, rewrite)

                default:
                    nil
                }
            }

        case .parameter:
            return try walk(node, under: ["type": .type], rewrite)

        case .body:
            return try walkElements(of: node, as: .statement, rewrite)

        case .statement:
            return try statement(node, rewrite)

        case .expression:
            return try expression(node, rewrite)

        case .type, .contract, .bound, .typeParameter, .path, .callee:
            return node
        }
    }

    // `procedures`, and each type's, extension's and contract's; a struct's
    // fields, type members and what a type satisfies; constants and
    // variables.
    private func document(_ node: Tree, _ rewrite: Rewrite) throws -> Tree {
        guard var entries = node.dictionaryValue else { return node }

        if let procedures = entries["procedures"] {
            entries["procedures"] = try declared(procedures, under: .document, rewrite)
        }

        for (table, owner) in [("types", Owner.type), ("extensions", Owner.extension), ("contracts", Owner.contract)] {
            guard let owners = entries[table]?.dictionaryValue else { continue }

            var walked: [String: Tree] = [:]

            for (key, declaration) in owners {
                walked[key] = try owned(declaration, under: owner(key), rewrite)
            }

            entries[table] = entries[table]?.holding(.dictionary(walked))
        }

        if let constants = entries["const"] {
            entries["const"] = try walkValues(of: constants, as: .expression, rewrite)
        }

        if let variables = entries["var"] {
            entries["var"] = try walkValues(of: variables) { declared in
                try variable(declared, rewrite)
            }
        }

        return node.holding(.dictionary(entries))
    }

    // A type, an extension or a contract: its procedures, the type it is
    // when it is one, its struct's fields and type parameters, its type
    // members or a contract's associated types, and what it satisfies.
    private func owned(_ declaration: Tree, under owner: Owner, _ rewrite: Rewrite) throws -> Tree {
        if declaration.stringValue != nil {
            return try walk(declaration, as: .type, rewrite)
        }

        return try walk(declaration, under: [:], rewrite) { key, value in
            switch key {
            case "procedures":
                try declared(value, under: owner, rewrite)

            case "struct":
                try walkValues(of: value, as: .type, rewrite)

            case "types" where value.dictionaryValue != nil:
                try walkValues(of: value, as: .type, rewrite)

            case "types", "typeParameters":
                try walkElements(of: value, as: .typeParameter, rewrite)

            case "satisfies":
                try walkElements(of: value, as: .contract, rewrite)

            default:
                nil
            }
        }
    }

    private func declared(_ procedures: Tree, under owner: Owner, _ rewrite: Rewrite) throws -> Tree {
        guard let declared = procedures.dictionaryValue else { return procedures }

        var walked: [String: Tree] = [:]

        for (key, procedure) in declared {
            walked[key] = try walk(procedure, as: .procedure(owner, key: key), rewrite)
        }

        return procedures.holding(.dictionary(walked))
    }

    // An expression, or `{ type, value }` where the variable says what it
    // holds.
    private func variable(_ node: Tree, _ rewrite: Rewrite) throws -> Tree {
        guard
            let entries = node.dictionaryValue,
            entries["value"] != nil,
            Set(entries.keys).isSubset(of: ["type", "value"])
        else {
            return try walk(node, as: .expression, rewrite)
        }

        return try walk(node, under: ["type": .type, "value": .expression], rewrite)
    }

    // Its declared type, the path a `set` writes, and its `value`: a
    // construct under its key, or an expression.
    private func statement(_ node: Tree, _ rewrite: Rewrite) throws -> Tree {
        try walk(node, under: ["type": .type, "set": .path], rewrite) { key, value in
            guard key == "value" else { return nil }

            guard
                let entries = value.dictionaryValue,
                entries.count == 1,
                let construct = entries.first,
                Self.claims(construct.key)
            else {
                return try walk(value, as: .expression, rewrite)
            }

            if let kinds = Self.constructs[construct.key] {
                return value.holding(.dictionary([construct.key: try walk(construct.value, under: kinds, rewrite)]))
            }

            guard construct.key == "return", construct.value.content != .null else { return value }

            return value.holding(.dictionary([construct.key: try walk(construct.value, as: .expression, rewrite)]))
        }
    }

    // By its one key: a path, a struct's fields, a dictionary's entries, a
    // call, a closure or a cast. An array's elements are expressions.
    private func expression(_ node: Tree, _ rewrite: Rewrite) throws -> Tree {
        if node.arrayValue != nil {
            return try walkElements(of: node, as: .expression, rewrite)
        }

        guard let entries = node.dictionaryValue, entries.count == 1, let form = entries.first else {
            return node
        }

        let held = form.value
        let walked: Tree = switch form.key {
        case "ref":
            try walk(held, as: .path, rewrite)

        case "struct":
            try walkValues(of: held, as: .expression, rewrite)

        case "dictionary":
            try walkElements(of: held) { entry in
                try walkElements(of: entry, as: .expression, rewrite)
            }

        case "call":
            try call(held, rewrite)

        case "closure":
            try walk(held, as: .closure, rewrite)

        case "as", "as?":
            try walk(held, under: ["of": .expression, "type": .type], rewrite)

        default:
            held
        }

        return node.holding(.dictionary([form.key: walked]))
    }

    // The callee, by its spelling or as a value, and the arguments, by
    // position or by name.
    private func call(_ node: Tree, _ rewrite: Rewrite) throws -> Tree {
        try walk(node, under: [:], rewrite) { key, value in
            switch key {
            case "procedure":
                try walk(value, as: value.stringValue == nil ? .expression : .callee, rewrite)

            case "arguments" where value.dictionaryValue != nil:
                try walkValues(of: value, as: .expression, rewrite)

            case "arguments":
                try walkElements(of: value, as: .expression, rewrite)

            default:
                nil
            }
        }
    }

    // A dictionary with the entries under `kinds` walked as those kinds, and
    // each other entry as `other` walks it, or left where it gives nothing.
    private func walk(
        _ node: Tree,
        under kinds: [String: Kind],
        _ rewrite: Rewrite,
        other: (String, Tree) throws -> Tree? = { _, _ in nil }
    ) throws -> Tree {
        guard let entries = node.dictionaryValue else { return node }

        var walked: [String: Tree] = [:]

        for (key, value) in entries {
            if let kind = kinds[key] {
                walked[key] = try walk(value, as: kind, rewrite)
            } else {
                walked[key] = try other(key, value) ?? value
            }
        }

        return node.holding(.dictionary(walked))
    }

    private func walkElements(of node: Tree, as kind: Kind, _ rewrite: Rewrite) throws -> Tree {
        try walkElements(of: node) { element in
            try walk(element, as: kind, rewrite)
        }
    }

    private func walkElements(of node: Tree, _ each: (Tree) throws -> Tree) throws -> Tree {
        guard let elements = node.arrayValue else { return node }

        return node.holding(.array(try elements.map(each)))
    }

    private func walkValues(of node: Tree, as kind: Kind, _ rewrite: Rewrite) throws -> Tree {
        try walkValues(of: node) { value in
            try walk(value, as: kind, rewrite)
        }
    }

    private func walkValues(of node: Tree, _ each: (Tree) throws -> Tree) throws -> Tree {
        guard let entries = node.dictionaryValue else { return node }

        return node.holding(.dictionary(try entries.mapValues(each)))
    }
}
