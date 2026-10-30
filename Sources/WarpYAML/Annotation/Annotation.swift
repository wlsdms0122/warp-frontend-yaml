//
//  Annotation.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// The keys a text writes beside a declaration that the document does not
// hold, taken off a text whose names carry their prefix: a procedure's
// `description`, and a parameter's `hint` and `default`. A procedure is one
// of the text's own, a member of one of its types or one an extension
// gives. The prose is kept by the procedure's full name, and the defaults
// by where the text wrote the procedure.
//
// A parameter is written as a pair, and the pair holds a mapping where it
// says more than its type: `timeout: { type: Int, default: 30, hint: seconds }`.
// What is left once the keys are off is the pair's own, its type or nothing,
// and a pair holding a mapping with none of these keys is left for the
// reader.
//
// A default is spent into the document the text is read into, the way
// `DefaultArgument` says, so the document holds no default.
struct Annotation {
    // MARK: - Property
    private static let descriptionKey = "description"
    private static let hintKey = "hint"
    private static let parametersKey = "parameters"
    private static let typeKey = "type"
    private static let bodyKey = "body"

    // The text without the keys.
    let document: Tree

    // What the prose keys held.
    let documentation: Documentation

    // Each procedure's defaults, by where the text wrote the procedure, in
    // the order its parameters stand.
    let defaults: [[Origin.Step]: [DefaultArgument]]

    // MARK: - Initializer
    // A text's tree with its names' prefix on, its procedures named in full
    // by `naming`: the document's own, a type's and what an extension gives,
    // under the type its head extends. A contract's procedure writes no
    // prose. An extension's key that reads as no type's head is left for
    // the load.
    init(of prefixed: Tree, reading naming: Naming) throws {
        var descriptions: [Name: String] = [:]
        var hints: [Name: [Name: String]] = [:]
        var defaults: [[Origin.Step]: [DefaultArgument]] = [:]

        self.document = try Grammar().rewriting(prefixed) { node, kind in
            guard
                case let .procedure(owner, key) = kind,
                let steps = Self.steps(to: key, under: owner),
                let full = Self.name(of: key, under: owner, reading: naming),
                var fields = node.dictionaryValue
            else {
                return node
            }

            if let description = try Self.prose(under: Self.descriptionKey, in: node) {
                fields[Self.descriptionKey] = nil
                descriptions[full] = description
            }

            if let parameters = fields[Self.parametersKey]?.arrayValue {
                var taken: [Tree] = []

                for (position, parameter) in parameters.enumerated() {
                    let read = try Self.parameter(parameter, at: position, of: steps)

                    if let hint = read.hint, let name = read.name {
                        hints[full, default: [:]][name] = hint
                    }

                    if let argument = read.default {
                        defaults[argument.procedure, default: []].append(argument)
                    }

                    taken.append(read.parameter)
                }

                fields[Self.parametersKey] = fields[Self.parametersKey]?.holding(.array(taken))
            }

            return node.holding(.dictionary(fields))
        }
        self.documentation = Documentation(descriptions: descriptions, hints: hints)
        self.defaults = defaults
    }

    // MARK: - Public
    // The text's tree with every default spent, before its statement
    // shorthands, so the default is spent with the body it now stands in:
    // each defaulted parameter, a pair, reads `T?`, and its binding stands
    // first in its procedure's body, in the parameters' order, made at the
    // parameter. A procedure whose body is no list is left for the load.
    func defaulted(_ document: Tree) throws -> Tree {
        guard !defaults.isEmpty else { return document }

        return try Grammar().rewriting(document) { node, kind in
            guard
                case let .procedure(owner, key) = kind,
                let steps = Self.steps(to: key, under: owner),
                let arguments = defaults[steps],
                var fields = node.dictionaryValue,
                var parameters = fields[Self.parametersKey]?.arrayValue
            else {
                return node
            }

            let body = fields[Self.bodyKey] ?? node.making(.array([]))

            guard let statements = body.arrayValue else { return node }

            var bindings: [Tree] = []

            for argument in arguments.sorted(by: { first, second in first.position < second.position }) {
                guard
                    parameters.indices.contains(argument.position),
                    let spent = try argument.spent(parameters[argument.position])
                else {
                    continue
                }

                parameters[argument.position] = spent.parameter
                bindings.append(spent.binding)
            }

            fields[Self.parametersKey] = fields[Self.parametersKey]?.holding(.array(parameters))
            fields[Self.bodyKey] = body.holding(.array(bindings + statements))

            return node.holding(.dictionary(fields))
        }
    }

    // MARK: - Private
    // Where the text wrote a procedure declared under `owner` by `key`, and
    // nothing for a contract's.
    private static func steps(to key: String, under owner: Grammar.Owner) -> [Origin.Step]? {
        switch owner {
        case .document:
            [.key("procedures"), .key(key)]

        case let .type(type):
            [.key("types"), .key(type), .key("procedures"), .key(key)]

        case let .extension(head):
            [.key("extensions"), .key(head), .key("procedures"), .key(key)]

        case .contract:
            nil
        }
    }

    // The full name of a procedure declared under `owner` by `key`: an
    // extension's under the type its head extends, the head's names read
    // in full.
    private static func name(of key: String, under owner: Grammar.Owner, reading naming: Naming) -> Name? {
        guard case let .extension(head) = owner else {
            return owner.name(of: key).flatMap { name in try? Name(name) }
        }

        guard let type = (try? naming.qualified(TypeSpelling(head)))?.extendedType else { return nil }

        return try? Name("\(type).\(key)")
    }

    // A parameter with its hint and default taken off, its name where it is
    // a pair. A pair holding a mapping that says no more than the pair would
    // is left as written.
    private static func parameter(
        _ parameter: Tree,
        at position: Int,
        of procedure: [Origin.Step]
    ) throws -> (parameter: Tree, name: Name?, hint: String?, default: DefaultArgument?) {
        guard
            let pair = parameter.dictionaryValue,
            pair.count == 1,
            let written = pair.first,
            let name = try? Name(written.key),
            let fields = written.value.dictionaryValue
        else {
            return (parameter, nil, nil, nil)
        }

        let hint = try prose(under: hintKey, in: written.value)
        let value = fields[DefaultArgument.key]

        guard hint != nil || value != nil else { return (parameter, nil, nil, nil) }

        if let value, value.content == .null {
            throw AuthoringError(
                "a default of null is what an Optional parameter left out is handed. Write '\(name): T?'",
                at: value
            )
        }

        let argument = value.map { value in
            DefaultArgument(position: position, written: value, procedure: procedure)
        }
        var left = fields

        left[hintKey] = nil
        left[DefaultArgument.key] = nil

        // What the pair holds once the keys are off: its type alone is
        // written as the pair's type, and anything else is the reading's.
        let held = left.count == 1 && left[typeKey] != nil
            ? left[typeKey] ?? written.value
            : written.value.holding(.dictionary(left))

        return (parameter.holding(.dictionary([written.key: held])), name, hint, argument)
    }

    // The string under the key, nothing where the key is not written, and a
    // refusal at it where it holds anything else.
    private static func prose(under key: String, in node: Tree) throws -> String? {
        guard let written = node[key] else { return nil }

        guard let prose = written.stringValue else {
            throw AuthoringError("a \(key) is a string", at: written)
        }

        return prose
    }
}
