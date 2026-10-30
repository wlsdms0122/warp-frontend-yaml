//
//  ProcedureParameter.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A parameter of a procedure's signature: its name, and its type where one
// is written. A parameter written with no type takes anything.
struct ProcedureParameter: Sendable, Hashable {
    // MARK: - Property
    let name: Name
    let type: TypeSpelling?

    // The parameter as a document's tree writes it, `{ name, type }`.
    var tree: Tree {
        var fields: [String: Tree] = ["name": .string(name.spelling)]

        if let type {
            fields["type"] = .string(type.spelling)
        }

        return .dictionary(fields)
    }

    // MARK: - Initializer
    init(name: Name, type: TypeSpelling?) {
        self.name = name
        self.type = type
    }

    // A parameter as a document's tree writes it, `{ name, type }`.
    init(_ tree: Tree) throws {
        self.init(
            name: try Name(tree["name"]?.stringValue ?? ""),
            type: try tree["type"]?.stringValue.map { type in try TypeSpelling(type) }
        )
    }

    // MARK: - Public
    // MARK: - Private
}
