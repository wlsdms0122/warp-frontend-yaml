//
//  ExpressionSugar.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The shorthands a text writes where a value is wanted, spent into what
// they stand for: an empty mapping into an empty dictionary, a template, and
// an operator mapping into the call the operator table names. A mapping
// holding one of the document's own keys is the document's form, and is left
// as written.
struct ExpressionSugar {
    // MARK: - Property
    // The keys an expression is written under in the document.
    private static let forms: Set<String> = ["ref", "struct", dictionaryKey, "call", "closure", "as", "as?"]
    private static let dictionaryKey = "dictionary"

    private static let operators = OperatorSpelling(operators: OperatorTable.spellings)
    private let naming: Naming

    // MARK: - Initializer
    // `naming` says which procedure a key names, the text's own first.
    init(reading naming: Naming) {
        self.naming = naming
    }

    // MARK: - Public
    // Whether a mapping of this one key, where a value is wanted, is this
    // notation's own and not a call to a procedure of that name: the
    // document's form, a template or an operator mapping.
    static func claims(_ key: String) -> Bool {
        forms.contains(key) || Template.keys.contains(key) || operators.claims(key)
    }

    func spent(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document, rewritten)
    }

    // A node at a position of `kind`, spent where it is an expression
    // written as a shorthand.
    func rewritten(_ node: Tree, as kind: Grammar.Kind) throws -> Tree {
        guard
            kind == .expression,
            let keys = node.dictionaryValue?.keys,
            Self.forms.isDisjoint(with: keys)
        else {
            return node
        }

        if keys.isEmpty {
            return node.holding(.dictionary([Self.dictionaryKey: node.making(Tree(.array([])))]))
        }

        // A mapping writing a template's key and no subject is a template,
        // whatever a key of it would name as an operator.
        if !keys.contains(OperatorSpelling.subjectKey), !Template.keys.isDisjoint(with: keys) {
            return node.holding(try Template(of: node).spent().content)
        }

        return try Self.operators.call(of: node, reading: naming) ?? node
    }

    // MARK: - Private
}
