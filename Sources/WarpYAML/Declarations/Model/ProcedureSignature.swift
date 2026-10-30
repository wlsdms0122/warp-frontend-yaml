//
//  ProcedureSignature.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a call into a procedure is written against: its parameters in order,
// what it returns, what it may fail with, whether it is const and isolated,
// and who may send it. What a document leaves out is held as its absence: no
// return type is `Null`, no throws clause fails with nothing.
struct ProcedureSignature: Sendable, Hashable {
    // MARK: - Property
    let parameters: [ProcedureParameter]
    let returns: TypeSpelling?
    let failing: ThrowsClause?
    let const: Bool
    let isolated: Bool
    let access: AccessLevel

    // The signature as a document's tree writes it, what it leaves out
    // unwritten.
    var tree: Tree {
        var fields: [String: Tree] = [:]

        if !parameters.isEmpty {
            fields["parameters"] = .array(parameters.map(\.tree))
        }

        if let returns {
            fields["returns"] = .string(returns.spelling)
        }

        switch failing {
        case .none:
            break

        case .anything:
            fields["failing"] = .string("anything")

        case let .names(names):
            fields["failing"] = .array(names.map(Tree.string))
        }

        if const {
            fields["const"] = .bool(true)
        }

        if isolated {
            fields["isolated"] = .bool(true)
        }

        if access != .internal {
            fields["access"] = .string(access.rawValue)
        }

        return .dictionary(fields)
    }

    // MARK: - Initializer
    init(
        parameters: [ProcedureParameter],
        returns: TypeSpelling?,
        failing: ThrowsClause?,
        const: Bool,
        isolated: Bool,
        access: AccessLevel
    ) {
        self.parameters = parameters
        self.returns = returns
        self.failing = failing
        self.const = const
        self.isolated = isolated
        self.access = access
    }

    // A procedure's signature as a document's tree writes it, its body and
    // what else it holds left alone.
    init(_ tree: Tree) throws {
        self.init(
            parameters: try (tree["parameters"]?.arrayValue ?? []).map(ProcedureParameter.init),
            returns: try tree["returns"]?.stringValue.map { type in try TypeSpelling(type) },
            failing: Self.failing(tree["failing"]),
            const: tree["const"]?.boolValue ?? false,
            isolated: tree["isolated"]?.boolValue ?? false,
            access: tree["access"]?.stringValue.flatMap(AccessLevel.init(rawValue:)) ?? .internal
        )
    }

    // MARK: - Public
    // MARK: - Private
    // `anything`, or the failures listed.
    private static func failing(_ tree: Tree?) -> ThrowsClause? {
        switch tree?.content {
        case .string("anything")?:
            .anything

        case let .array(names)?:
            .names(names.compactMap(\.stringValue))

        default:
            nil
        }
    }
}
