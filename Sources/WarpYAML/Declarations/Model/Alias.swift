//
//  Alias.swift
//  WarpYAML
//
//  Created by JSilver on 11/2/26.
//

import Foundation

// The type an alias spells, with the types the head it is given under
// applies: none for a type declared as an alias, and for a type member
// those of the head, a struct's or an enum's own type parameters in its
// declaration and an extension's head in an extension. A head type `some T`
// is a type parameter the spelling reading the alias gives a type.
struct Alias: Sendable, Hashable {
    // MARK: - Property
    // The types the head applies, in order.
    let head: [TypeSpelling]

    // The type spelled, written under the head.
    let type: TypeSpelling

    // MARK: - Initializer
    init(head: [TypeSpelling], type: TypeSpelling) {
        self.head = head
        self.type = type
    }

    // MARK: - Public
    // The type read under the types a spelling applies: each head type
    // parameter read as the type at its position. Nothing where the head
    // does not take them: a count apart, or a head type that is no type
    // parameter and is not the type at its position. Whether a type meets a
    // type parameter's bounds is not read.
    func type(under arguments: [TypeSpelling]) -> TypeSpelling? {
        guard let bindings = bindings(to: arguments) else { return nil }

        return type.substituting(bindings)
    }

    // MARK: - Private
    // The type each head type parameter is read as, by its name, and nothing
    // where the head does not take the arguments.
    private func bindings(to arguments: [TypeSpelling]) -> [String: TypeSpelling]? {
        guard head.count == arguments.count else { return nil }

        var bindings: [String: TypeSpelling] = [:]

        for (written, argument) in zip(head, arguments) {
            switch written {
            case let .parameter(name, _):
                guard bindings[name, default: argument] == argument else { return nil }

                bindings[name] = argument

            default:
                guard written == argument else { return nil }
            }
        }

        return bindings
    }
}
