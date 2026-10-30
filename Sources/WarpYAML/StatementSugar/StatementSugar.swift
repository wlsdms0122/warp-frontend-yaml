//
//  StatementSugar.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The shorthands a text writes for a procedure's parts, spent into the one
// spelling the document has: `result:` into a last `return`, a parameter
// written as a pair into `{ name, type }`, and `cases` and `each` into the
// constructs they stand for.
struct StatementSugar {
    // MARK: - Property
    // The key a procedure or a closure writes its return value under, beside
    // its body.
    private static let resultKey = "result"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // Whether a statement's `value` holding this one key is a shorthand for
    // a construct.
    static func claims(_ key: String) -> Bool {
        key == CasesForm.key || key == EachForm.key
    }

    func spent(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document, rewritten)
    }

    // A node at a position of `kind`, spent where it writes a shorthand.
    func rewritten(_ node: Tree, as kind: Grammar.Kind) throws -> Tree {
        switch kind {
        case .procedure, .closure:
            Self.returning(node)

        case .parameter:
            Self.paired(node)

        case .statement:
            try Self.constructed(node)

        case .document, .type, .contract, .bound, .typeParameter, .body, .expression, .path, .callee:
            node
        }
    }

    // MARK: - Private
    // A procedure with `result:` beside its body, as the body with a last
    // `return` of it, at the key. A body that is no list is left with the
    // key for the load.
    private static func returning(_ procedure: Tree) -> Tree {
        guard var fields = procedure.dictionaryValue, let returned = fields[resultKey] else { return procedure }

        let body = fields["body"] ?? returned.making(.array([]))

        guard let statements = body.arrayValue else { return procedure }

        fields[resultKey] = nil
        fields["body"] = body.holding(
            .array(statements + [returned.making(.dictionary(["value": .dictionary(["return": returned])]))])
        )

        return procedure.holding(.dictionary(fields))
    }

    // A parameter of one key, the name its body reads it by, holding its
    // type, or a mapping holding nothing where it writes none. One key is
    // always the pair, `name` included. A pair holding anything else is left
    // for the load.
    private static func paired(_ parameter: Tree) -> Tree {
        guard let entries = parameter.dictionaryValue, entries.count == 1, let pair = entries.first else {
            return parameter
        }

        let name = Tree(.string(pair.key), at: pair.value.position)

        if pair.value.stringValue != nil {
            return parameter.holding(.dictionary(["name": name, "type": pair.value]))
        }

        guard pair.value.dictionaryValue?.isEmpty == true else { return parameter }

        return parameter.holding(.dictionary(["name": name]))
    }

    // A statement whose `value` holds `cases` or `each` as its one key, as
    // the construct it stands for.
    private static func constructed(_ statement: Tree) throws -> Tree {
        guard
            let value = statement["value"]?.dictionaryValue,
            value.count == 1,
            let construct = value.first
        else {
            return statement
        }

        switch construct.key {
        case CasesForm.key:
            return try CasesForm.spent(statement, holding: construct.value)

        case EachForm.key:
            return try EachForm.spent(statement, holding: construct.value)

        default:
            return statement
        }
    }
}
