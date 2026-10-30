//
//  TypeSpelling+Element.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

extension TypeSpelling {
    // How deep a type's nodes nest.
    private static let nodeDepthBound = 128

    // A type written as the text's node: an atom for a name, or a node by
    // its word. The node writes the type's string, and a node whose string
    // reads back as another type, `(named Array Int)` or `(composition A)`,
    // has no tree and is refused.
    init(_ node: Element) throws(AuthoringError) {
        let read = try Self.read(node, depth: 0)

        guard (try? TypeSpelling(read.spelling)) == read else {
            throw AuthoringError(
                "the type node writes '\(read.spelling)', which reads back as another type",
                at: node.position
            )
        }

        self = read
    }

    private static func read(_ node: Element, depth: Int) throws(AuthoringError) -> TypeSpelling {
        guard depth <= nodeDepthBound else {
            throw AuthoringError("a type's nodes nest at most \(nodeDepthBound) levels", at: node.position)
        }

        guard case let .list(elements, position) = node else {
            guard case let .atom(.name(name), _) = node else {
                throw AuthoringError("a type is a name or a type node", at: node.position)
            }

            return .named(name, arguments: [])
        }

        guard case let .atom(.name(word), _) = elements.first else {
            throw AuthoringError("a type node begins with its word", at: position)
        }

        let operands = elements.dropFirst()

        switch (word, operands.count) {
        case ("array", 1):
            return .array(try read(operands[1], depth: depth + 1))

        case ("dictionary", 2):
            return .dictionary(
                key: try read(operands[1], depth: depth + 1),
                value: try read(operands[2], depth: depth + 1)
            )

        case ("optional", 1):
            return .optional(try read(operands[1], depth: depth + 1))

        case ("inout", 1):
            return .inout(try read(operands[1], depth: depth + 1))

        case ("var", 1):
            return .variable(try read(operands[1], depth: depth + 1))

        case ("named", 2...):
            let applied = try arguments(operands.dropFirst(), depth: depth + 1)

            return .named(try name(operands[1]), arguments: applied)

        case ("composition", 1...):
            return .composition(try operands.map(name))

        case ("some", 1...):
            return .parameter(try name(operands[1]), bounds: try operands.dropFirst().map(name))

        case ("procedure", _):
            return try procedure(Array(operands), at: position, depth: depth)

        default:
            throw AuthoringError("'(\(word) …)' is no type node written so", at: position)
        }
    }

    private static func arguments(_ operands: ArraySlice<Element>, depth: Int) throws(AuthoringError) -> [TypeSpelling] {
        var arguments: [TypeSpelling] = []

        for operand in operands {
            arguments.append(try read(operand, depth: depth))
        }

        return arguments
    }

    // A procedure type's parts, in the order modifiers, `parameters`,
    // `failing`, `returns`, its parameters and what it returns both or
    // neither.
    private static func procedure(
        _ parts: [Element],
        at position: Origin.Position,
        depth: Int
    ) throws(AuthoringError) -> TypeSpelling {
        let order = ["const": 0, "isolated": 0, "parameters": 1, "failing": 2, "returns": 3]
        var modifiers: [ProcedureModifier] = []
        var parameters: [TypeSpelling]?
        var failing: ThrowsClause?
        var returns: TypeSpelling?
        var written: [String] = []

        for part in parts {
            guard
                case let .list(elements, at) = part,
                case let .atom(.name(word), _) = elements.first,
                let rank = order[word]
            else {
                throw AuthoringError(
                    "a procedure type's part is 'const', 'isolated', 'parameters', 'failing' or 'returns'",
                    at: part.position
                )
            }
            guard !written.contains(word) else { throw AuthoringError("'\(word)' is written twice", at: at) }
            guard written.allSatisfy({ earlier in order[earlier, default: 0] <= rank }) else {
                throw AuthoringError("a procedure type's parts stand as modifiers, parameters, failing, returns", at: at)
            }

            written.append(word)

            let operands = Array(elements.dropFirst())

            switch word {
            case "parameters":
                parameters = try arguments(operands[...], depth: depth + 1)

            case "failing":
                failing = try throwsClause(operands)

            case "returns":
                guard operands.count == 1 else { throw AuthoringError("'returns' takes one type", at: at) }

                returns = try read(operands[0], depth: depth + 1)

            default:
                guard operands.isEmpty, let modifier = ProcedureModifier(rawValue: word) else {
                    throw AuthoringError("'\(word)' takes nothing", at: at)
                }

                modifiers.append(modifier)
            }
        }

        switch (parameters, returns) {
        case let (.some(parameters), .some(returns)):
            return .procedure(
                modifiers: modifiers,
                parameters: parameters,
                failing: failing,
                returns: returns
            )

        case (.none, .none) where failing == nil:
            return .unsaidProcedure(modifiers: modifiers)

        default:
            throw AuthoringError(
                "a procedure type writes its parameters and what it returns both, or neither",
                at: position
            )
        }
    }

    private static func throwsClause(_ operands: [Element]) throws(AuthoringError) -> ThrowsClause {
        if
            operands.count == 1,
            case let .list(elements, _) = operands[0],
            elements.count == 1,
            case .atom(.name("anything"), _) = elements[0]
        {
            return .anything
        }

        return .names(try operands.map(name))
    }

    private static func name(_ operand: Element) throws(AuthoringError) -> String {
        guard case let .atom(.name(name), _) = operand else {
            throw AuthoringError("a name stands here", at: operand.position)
        }

        return name
    }
}
