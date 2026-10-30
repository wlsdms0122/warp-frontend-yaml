//
//  Elaborator.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// A closure's signature from the slot it stands in. A closure literal
// standing where a procedure type is written takes from it each part of its
// signature it leaves out: a parameter written with no type takes the type
// at its position, and `returns`, `failing`, `const` and `isolated` take the
// slot's. A parameter written `Any` stands. Anything else the closure writes
// stands, and whether it fits is the build's. The parameters' names are the
// closure's own.
//
// The slots are read without typing an expression: an argument of a call to
// a declaration in hand, a `let` or a `var` that writes its type, a
// module variable that writes its type, and a `return` in a body whose
// procedure or closure writes its `returns`. An array's element, a dictionary's
// key and value and an Optional's payload written straight at a slot stand at
// what the slot holds there. A position of a callee's procedure type that
// names one of the callee's type parameters is filled by each call, so it is
// left to the closure.
struct Elaborator {
    // MARK: - Property
    private static let typeKey = "type"
    private static let valueKey = "value"

    // The document's table of module variables.
    private static let variableKey = "var"

    private static let callKey = "call"
    private static let procedureKey = "procedure"
    private static let argumentsKey = "arguments"
    private static let closureKey = "closure"
    private static let dictionaryKey = "dictionary"
    private static let parametersKey = "parameters"
    private static let returnsKey = "returns"
    private static let failingKey = "failing"
    private static let constKey = "const"
    private static let isolatedKey = "isolated"
    private static let bodyKey = "body"
    private static let returnKey = "return"
    private static let anything = "anything"
    private static let selfType = "Self"
    private static let any: TypeSpelling = .named("Any", arguments: [])
    private static let null: TypeSpelling = .named("Null", arguments: [])

    // The declarations a call may name, by full name.
    private let declarations: Declarations

    // MARK: - Initializer
    init(leaningOn declarations: Declarations) {
        self.declarations = declarations
    }

    // MARK: - Public
    // The text's tree with every closure standing in a slot completed. A
    // closure parameter written with no type takes the slot's, and one
    // written `Any` stands.
    func completed(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document) { node, kind in
            switch kind {
            case .document:
                variables(node)

            case .procedure, .closure:
                returned(node)

            case .statement:
                bound(node)

            case .expression:
                called(node)

            case .parameter, .type, .contract, .bound, .typeParameter, .body, .path, .callee:
                node
            }
        }
    }

    // MARK: - Private
    // The document with each module variable that writes its type, `{ type,
    // value }`, holding its start completed at that type.
    private func variables(_ document: Tree) -> Tree {
        guard var entries = document.dictionaryValue, let variables = entries[Self.variableKey] else {
            return document
        }

        entries[Self.variableKey] = variables.dictionaryValue.map { declared in
            variables.holding(.dictionary(declared.mapValues { variable in
                guard
                    var fields = variable.dictionaryValue,
                    fields.count == 2,
                    let type = fields[Self.typeKey].flatMap(Self.type),
                    let value = fields[Self.valueKey]
                else {
                    return variable
                }

                fields[Self.valueKey] = filled(value, at: type)

                return variable.holding(.dictionary(fields))
            }))
        } ?? variables

        return document.holding(.dictionary(entries))
    }

    // A statement that writes its type, with its value completed at it.
    private func bound(_ statement: Tree) -> Tree {
        guard
            var fields = statement.dictionaryValue,
            let type = fields[Self.typeKey].flatMap(Self.type),
            let value = fields[Self.valueKey]
        else {
            return statement
        }

        fields[Self.valueKey] = filled(value, at: type)

        return statement.holding(.dictionary(fields))
    }

    // A call by its callee's name with its arguments completed at the
    // callee's parameter types, opened.
    private func called(_ expression: Tree) -> Tree {
        guard
            let call = expression[Self.callKey],
            var fields = call.dictionaryValue,
            let callee = fields[Self.procedureKey]?.stringValue.flatMap({ callee in try? Name(callee) }),
            let parameters = declarations.signature(of: callee)?.parameters,
            let arguments = fields[Self.argumentsKey]?.arrayValue
        else {
            return expression
        }

        let completed = arguments.enumerated().map { position, argument in
            guard parameters.indices.contains(position), let type = parameters[position].type else { return argument }

            return filled(argument, at: opened(type))
        }

        fields[Self.argumentsKey] = fields[Self.argumentsKey]?.holding(.array(completed))

        return expression.holding(.dictionary([Self.callKey: call.holding(.dictionary(fields))]))
    }

    // A procedure or a closure that writes its `returns`, with what each
    // `return` of its body returns completed at it. A closure in the body
    // is its own.
    private func returned(_ procedure: Tree) -> Tree {
        guard
            var fields = procedure.dictionaryValue,
            let type = fields[Self.returnsKey].flatMap(Self.type),
            let body = fields[Self.bodyKey]
        else {
            return procedure
        }

        fields[Self.bodyKey] = returning(body, at: type)

        return procedure.holding(.dictionary(fields))
    }

    // A body with each `return` in it, and in the bodies of its
    // constructs, completed at `type`.
    private func returning(_ body: Tree, at type: TypeSpelling) -> Tree {
        guard let statements = body.arrayValue else { return body }

        return body.holding(.array(statements.map { statement in
            guard
                var fields = statement.dictionaryValue,
                let value = fields[Self.valueKey],
                let entries = value.dictionaryValue,
                entries.count == 1,
                let construct = entries.first
            else {
                return statement
            }

            if construct.key == Self.returnKey {
                fields[Self.valueKey] = value.holding(.dictionary([construct.key: filled(construct.value, at: type)]))
            } else if let kinds = Grammar.constructs[construct.key], var parts = construct.value.dictionaryValue {
                for (key, kind) in kinds where kind == .body {
                    parts[key] = parts[key].map { part in returning(part, at: type) }
                }

                fields[Self.valueKey] = value.holding(.dictionary([construct.key: construct.value.holding(.dictionary(parts))]))
            } else {
                return statement
            }

            return statement.holding(.dictionary(fields))
        }))
    }

    // An expression written straight at a slot of `type`: a closure
    // completed where the slot is a procedure type, and an array's
    // elements, a dictionary's entries and an Optional's payload at what
    // the slot holds there.
    private func filled(_ expression: Tree, at type: TypeSpelling) -> Tree {
        switch type {
        case let .optional(wrapped):
            return filled(expression, at: wrapped)

        case let .array(element):
            guard let elements = expression.arrayValue else { return expression }

            return expression.holding(.array(elements.map { item in filled(item, at: element) }))

        case let .dictionary(key, value):
            guard let written = expression[Self.dictionaryKey], let entries = written.arrayValue else {
                return expression
            }

            let completed = entries.map { entry in
                guard let pair = entry.arrayValue, pair.count == 2 else { return entry }

                return entry.holding(.array([filled(pair[0], at: key), filled(pair[1], at: value)]))
            }

            return expression.holding(.dictionary([Self.dictionaryKey: written.holding(.array(completed))]))

        case .procedure, .unsaidProcedure:
            guard let closure = expression[Self.closureKey] else { return expression }

            return expression.holding(.dictionary([Self.closureKey: completed(closure, at: type)]))

        case .named, .composition, .parameter, .inout, .variable:
            return expression
        }
    }

    // A closure with each part of its signature it leaves out taken from a
    // procedure type: a parameter with no type the type at its position,
    // and `returns`, `failing`, `const` and `isolated`. A part the slot says
    // nothing of, `Any`, `Null`, no failure, stays out.
    private func completed(_ closure: Tree, at type: TypeSpelling) -> Tree {
        guard var fields = closure.dictionaryValue else { return closure }

        let modifiers: [ProcedureModifier]
        var taken: [TypeSpelling] = []
        var returns: TypeSpelling?
        var failing: ThrowsClause?

        switch type {
        case let .procedure(written, parameters, failure, returned):
            modifiers = written
            taken = parameters
            returns = returned
            failing = failure

        case let .unsaidProcedure(written):
            modifiers = written

        default:
            return closure
        }

        if let parameters = fields[Self.parametersKey], let written = parameters.arrayValue {
            fields[Self.parametersKey] = parameters.holding(.array(written.enumerated().map { position, parameter in
                guard
                    var held = parameter.dictionaryValue,
                    held[Self.typeKey] == nil,
                    taken.indices.contains(position),
                    taken[position] != Self.any
                else {
                    return parameter
                }

                held[Self.typeKey] = parameter.making(.string(taken[position].spelling))

                return parameter.holding(.dictionary(held))
            }))
        }

        if fields[Self.returnsKey] == nil, let returns, returns != Self.null {
            fields[Self.returnsKey] = closure.making(.string(returns.spelling))
        }

        if fields[Self.failingKey] == nil {
            switch failing {
            case .anything:
                fields[Self.failingKey] = closure.making(.string(Self.anything))

            case let .names(names) where !names.isEmpty:
                fields[Self.failingKey] = closure.making(.array(names.map(Tree.string)))

            case .names, .none:
                break
            }
        }

        if fields[Self.constKey] == nil, modifiers.contains(.const) {
            fields[Self.constKey] = closure.making(.bool(true))
        }

        if fields[Self.isolatedKey] == nil, modifiers.contains(.isolated) {
            fields[Self.isolatedKey] = closure.making(.bool(true))
        }

        return closure.holding(.dictionary(fields))
    }

    // A callee's parameter type with each position of a procedure type in it
    // that names a type parameter left out: `Any` for a parameter and `Null`
    // for what it returns. Each call fills those, so the closure does.
    private func opened(_ type: TypeSpelling) -> TypeSpelling {
        switch type {
        case let .array(element):
            .array(opened(element))

        case let .dictionary(key, value):
            .dictionary(key: opened(key), value: opened(value))

        case let .optional(wrapped):
            .optional(opened(wrapped))

        case let .procedure(modifiers, parameters, failing, returns):
            .procedure(
                modifiers: modifiers,
                parameters: parameters.map { parameter in namesTypeParameter(parameter) ? Self.any : parameter },
                failing: failing,
                returns: namesTypeParameter(returns) ? Self.null : returns
            )

        case .named, .composition, .parameter, .inout, .variable, .unsaidProcedure:
            type
        }
    }

    // Whether a type parameter stands anywhere in the type: `some T`,
    // `Self` or a type `Self` names.
    private func namesTypeParameter(_ type: TypeSpelling) -> Bool {
        switch type {
        case .parameter:
            true

        case let .named(name, arguments):
            name == Self.selfType || name.hasPrefix("\(Self.selfType).") || arguments.contains(where: namesTypeParameter)

        case let .array(inner), let .optional(inner), let .inout(inner), let .variable(inner):
            namesTypeParameter(inner)

        case let .dictionary(key, value):
            namesTypeParameter(key) || namesTypeParameter(value)

        case let .procedure(_, parameters, _, returns):
            (parameters + [returns]).contains(where: namesTypeParameter)

        case .composition, .unsaidProcedure:
            false
        }
    }

    // A type a tree writes, and nothing where it writes none that reads.
    private static func type(_ written: Tree) -> TypeSpelling? {
        written.stringValue.flatMap { spelling in try? TypeSpelling(spelling) }
    }
}
