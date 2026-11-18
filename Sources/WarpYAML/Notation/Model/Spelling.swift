//
//  Spelling.swift
//  WarpYAML
//
//  Created by JSilver on 8/30/26.
//

import Foundation

// What one operator key stands in for: the procedure it reaches, and the form
// of the mapping it is written in. Every procedure is named in full.
struct Spelling: Sendable, Equatable {
    // How the mapping around the key is written, and how it comes apart.
    //
    // A spelling is a call either way; what varies is where its arguments come
    // from, and how many there are.
    enum Form: Sendable, Equatable {
        // Whether `of` is written beside the key: what the form needs, refuses
        // or leaves to the text.
        enum Subject: Sendable, Equatable {
            case required
            case refused
            case optional
        }

        // The subject first and what is under the key second:
        // `{ of: x, plus: 1 }`.
        case binary

        // What is under the key is the one argument: `{ count: x }`. No
        // subject.
        case unary

        // Either of the two, read by what the text wrote: a key this table
        // does not hold, whose count only the declaration behind it knows.
        // `{ shout: x }` and `{ of: x, repeated: 3 }`.
        case either

        // Expressions under the key, each left unasked until the procedure
        // asks for it. No subject.
        case connective

        // The expression under the key first, and this fixed value second.
        // `present: x` is `x` against null. No subject.
        case against(Tree)

        // A subject and an operand, the other way round: the document says "the
        // subject is one of these" where the procedure says "these contain it".
        case flipped

        // MARK: - Property
        var subject: Subject {
            switch self {
            case .binary, .flipped: .required
            case .unary, .connective, .against: .refused
            case .either: .optional
            }
        }

        // Whether a text declaring a procedure by this key takes the key over:
        // a plain send yields, and a form of this notation's own does not.
        var yieldsToTheText: Bool {
            switch self {
            case .binary, .unary, .either: true
            case .connective, .against, .flipped: false
            }
        }

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    let procedure: Name

    let form: Form

    // MARK: - Initializer
    init(procedure: Name, form: Form) {
        self.procedure = procedure
        self.form = form
    }

    // MARK: - Public
    // MARK: - Private
}
