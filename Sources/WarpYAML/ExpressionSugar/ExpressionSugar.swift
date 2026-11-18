//
//  ExpressionSugar.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The shorthands a text writes where a value is wanted, spent into what
// they stand for: an empty mapping into an empty dictionary, a dictionary
// written as a mapping into its entries, each key a string, in key order, a
// case literal written as its case alone, `{ case: up }`, into the case
// carrying nothing, a template, and an operator mapping into the call the
// operator table names. Any other mapping holding one of the document's own
// keys is the document's form, and is left as written.
struct ExpressionSugar {
    // MARK: - Property
    // The keys an expression is written under in the document.
    private static let forms: Set<String> = ["ref", "struct", caseKey, dictionaryKey, "call", "closure", "as", "as?"]
    private static let dictionaryKey = "dictionary"
    private static let caseKey = "case"

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
        if kind == .expression, node.dictionaryValue?.count == 1, let held = node[Self.caseKey], let name = held.stringValue {
            return node.holding(.dictionary([Self.caseKey: held.holding(.dictionary([name: held.making(.dictionary([:]))]))]))
        }

        if kind == .expression, node.dictionaryValue?.count == 1, let held = node[Self.dictionaryKey], let entries = held.dictionaryValue {
            let pairs = entries.sorted { first, second in first.key < second.key }.map { key, value in
                value.making(.array([.string(key), value]))
            }

            return node.holding(.dictionary([Self.dictionaryKey: held.holding(.array(pairs))]))
        }

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
