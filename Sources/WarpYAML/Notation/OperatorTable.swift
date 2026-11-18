//
//  OperatorTable.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The operator keys a text writes, each the standard procedure it reaches
// and the form of the mapping it is written in. The table spells standard
// procedures that take one argument or two; a key it does not hold is sent
// as written, and a call it cannot spell is written as a `call`.
enum OperatorTable {
    static let spellings: [Name: Spelling] = [
        // Standard.Logic
        "all_of": Spelling(procedure: "Standard.Logic.and", form: .connective),
        "any_of": Spelling(procedure: "Standard.Logic.or", form: .connective),
        "try_all_of": Spelling(procedure: "Standard.Logic.tryAnd", form: .connective),
        "try_any_of": Spelling(procedure: "Standard.Logic.tryOr", form: .connective),
        "not": Spelling(procedure: "Standard.Logic.not", form: .unary),
        "is": Spelling(procedure: "Standard.Logic.equal", form: .binary),
        "is_not": Spelling(procedure: "Standard.Logic.notEqual", form: .binary),
        "present": Spelling(procedure: "Standard.Logic.notEqual", form: .against(.null)),

        // Standard.Numeric, Standard.Comparable and Standard.Math
        "plus": Spelling(procedure: "Standard.Numeric.plus", form: .binary),
        "minus": Spelling(procedure: "Standard.Numeric.minus", form: .binary),
        "times": Spelling(procedure: "Standard.Numeric.times", form: .binary),
        "divided_by": Spelling(procedure: "Standard.Numeric.dividedBy", form: .binary),
        "remainder": Spelling(procedure: "Standard.Numeric.remainder", form: .binary),
        "min": Spelling(procedure: "Standard.Math.min", form: .binary),
        "max": Spelling(procedure: "Standard.Math.max", form: .binary),
        "less_than": Spelling(procedure: "Standard.Comparable.lessThan", form: .binary),
        "greater_than": Spelling(procedure: "Standard.Math.greaterThan", form: .binary),
        "absolute": Spelling(procedure: "Standard.Math.absolute", form: .unary),
        "floored": Spelling(procedure: "Standard.Math.floored", form: .unary),
        "rounded": Spelling(procedure: "Standard.Math.rounded", form: .unary),

        // Standard.Text
        "text": Spelling(procedure: "Standard.Text.text", form: .unary),
        "starts_with": Spelling(procedure: "Standard.Text.startsWith", form: .binary),
        "uppercased": Spelling(procedure: "Standard.Text.uppercased", form: .unary),
        "lowercased": Spelling(procedure: "Standard.Text.lowercased", form: .unary),
        "trimmed": Spelling(procedure: "Standard.Text.trimmed", form: .unary),
        "characters": Spelling(procedure: "Standard.Text.characters", form: .unary),
        "split": Spelling(procedure: "Standard.Text.split", form: .binary),
        "joined": Spelling(procedure: "Standard.Text.joined", form: .binary),

        // Standard.Collection
        "one_of": Spelling(procedure: "Standard.Collection.contains", form: .flipped),
        "count": Spelling(procedure: "Standard.Collection.count", form: .unary),
        "contains": Spelling(procedure: "Standard.Collection.contains", form: .binary),
        "first": Spelling(procedure: "Standard.Collection.first", form: .unary),
        "last": Spelling(procedure: "Standard.Collection.last", form: .unary),
        "reversed": Spelling(procedure: "Standard.Collection.reversed", form: .unary),
        "drop_first": Spelling(procedure: "Standard.Collection.dropFirst", form: .unary),
        "drop_last": Spelling(procedure: "Standard.Collection.dropLast", form: .unary),
        "sorted": Spelling(procedure: "Standard.Collection.sorted", form: .unary),
        "appending": Spelling(procedure: "Standard.Collection.appending", form: .binary),
        "prepending": Spelling(procedure: "Standard.Collection.prepending", form: .binary),
        "gathering": Spelling(procedure: "Standard.Collection.gathering", form: .binary),
        "map": Spelling(procedure: "Standard.Collection.map", form: .binary),
        "filter": Spelling(procedure: "Standard.Collection.filter", form: .binary),
        "try_map": Spelling(procedure: "Standard.Collection.tryMap", form: .binary),
        "try_filter": Spelling(procedure: "Standard.Collection.tryFilter", form: .binary),
        "keys": Spelling(procedure: "Standard.Collection.keys", form: .unary),
        "values": Spelling(procedure: "Standard.Collection.values", form: .unary),

        // Standard.Control
        "abort": Spelling(procedure: "Standard.Control.abort", form: .unary)
    ]
}
