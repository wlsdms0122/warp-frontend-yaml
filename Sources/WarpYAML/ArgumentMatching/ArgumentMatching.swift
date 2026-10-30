//
//  ArgumentMatching.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// A call that writes its `arguments` as a mapping names them, and the
// document hands them by position. A call is the `call` mapping, which
// stands alone wherever an expression is written, so each such call's
// arguments are put in its callee's order, an Optional parameter the call
// does not name handed `null`. The callee's signature is the one the
// declarations in hand hold. A call of a value has a procedure type, which
// names no parameters, so it hands a list.
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
    // full name the call writes. A call of a value hands a list.
    func matched(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document) { node, kind in
            guard
                kind == .expression,
                let call = node[Self.callKey],
                node.dictionaryValue?.count == 1,
                let arguments = call[Self.argumentsKey],
                let named = arguments.dictionaryValue,
                var fields = call.dictionaryValue
            else {
                return node
            }

            // Only a callee's declaration says what the names are handed to.
            guard let procedure = call[Self.procedureKey] else {
                throw AuthoringError("a call writing its arguments by name names the procedure it calls", at: arguments)
            }

            guard let spelled = procedure.stringValue else {
                throw AuthoringError("a call of a value hands its arguments by position, as a list", at: arguments)
            }

            let callee: Name

            do throws(AuthoringError) {
                callee = try Name(spelled)
            } catch {
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

            let ordered: [(parameter: Name, argument: Tree)]

            do throws(AuthoringError) {
                ordered = try declarations.arguments(handed, to: callee)
            } catch {
                throw AuthoringError(error, at: arguments)
            }

            fields[Self.argumentsKey] = arguments.holding(
                .array(ordered.map { parameter, argument in handed[parameter] == nil ? arguments.making(.null) : argument })
            )

            return node.holding(.dictionary([Self.callKey: call.holding(.dictionary(fields))]))
        }
    }

    // MARK: - Private
}
