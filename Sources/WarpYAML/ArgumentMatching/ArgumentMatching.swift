//
//  ArgumentMatching.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// A call that writes its `arguments` as a mapping names them, a call to a
// procedure by name writing no `arguments` names none, and the document
// hands them by position. A call is the `call` mapping, which stands alone
// wherever an expression is written, so each such call's arguments are put
// in its callee's order, an Optional parameter the call does not name handed
// `null`. The callee's signature is the one the declarations in hand hold,
// and a call to a callee they do not hold is left as written. A call of a
// value has a procedure type, which names no parameters, so it hands a list.
struct ArgumentMatching: Sendable {
    // MARK: - Property
    private static let callKey = "call"
    private static let procedureKey = "procedure"
    private static let argumentsKey = "arguments"

    // The signatures a callee is matched against, the text's own included.
    private let declarations: Declarations

    // MARK: - Initializer
    init(declarations: Declarations) {
        self.declarations = declarations
    }

    // MARK: - Public
    // A document with every call's arguments written by name handed by
    // position, in its callee's parameter order, an Optional parameter the
    // call does not name handed `null` at the arguments. The callee is the
    // full name the call writes. A call of a value hands a list. A call
    // writing no arguments to a callee taking none is left as written.
    func matched(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document) { node, kind in
            guard
                kind == .expression,
                let call = node[Self.callKey],
                node.dictionaryValue?.count == 1,
                var fields = call.dictionaryValue
            else {
                return node
            }

            let written = call[Self.argumentsKey]

            // Arguments written as no mapping are left as written.
            if let written, written.dictionaryValue == nil { return node }

            let arguments = written ?? call.making(.dictionary([:]))
            let named = arguments.dictionaryValue ?? [:]
            let callee: Name

            do throws(AuthoringError) {
                callee = try Self.callee(of: call)
            } catch {
                // A call writing no arguments names nothing to match, so
                // what it calls is the load's to judge.
                guard written != nil else { return node }

                throw AuthoringError(error, at: arguments)
            }

            var handed: [Name: Tree] = [:]

            for (key, argument) in named {
                do throws(AuthoringError) {
                    handed[try Name(key)] = argument
                } catch {
                    throw AuthoringError(error, at: argument)
                }
            }

            let matched: [(parameter: Name, argument: Tree)]?

            do throws(AuthoringError) {
                matched = try declarations.arguments(handed, to: callee)
            } catch {
                throw AuthoringError(error, at: arguments)
            }

            // A callee the table does not declare is a name the text uses
            // and nothing declares, refused where the call names it, and a
            // call writing no arguments to a callee taking none is written.
            guard let ordered = matched, written != nil || !ordered.isEmpty else { return node }

            fields[Self.argumentsKey] = arguments.holding(
                .array(ordered.map { parameter, argument in handed[parameter] == nil ? arguments.making(.null) : argument })
            )

            return node.holding(.dictionary([Self.callKey: call.holding(.dictionary(fields))]))
        }
    }

    // MARK: - Private
    // The procedure a call names, which only its declaration says what the
    // names are handed to.
    private static func callee(of call: Tree) throws(AuthoringError) -> Name {
        guard let procedure = call[procedureKey] else {
            throw AuthoringError("a call writing its arguments by name names the procedure it calls")
        }

        guard let spelled = procedure.stringValue else {
            throw AuthoringError("a call of a value hands its arguments by position, as a list")
        }

        return try Name(spelled)
    }
}
