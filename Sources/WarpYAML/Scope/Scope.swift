//
//  Scope.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// The value names a place of a spent document reads, by WARP-19, WARP-21 and
// WARP-95: the document's constants and variables, the parameters of each
// procedure and closure the place is inside, what the statements before it
// in each body around it introduce, and what a construct around it binds
// for the part the place is in. Names only: what each holds is the build's
// to judge.
struct Scope {
    // What a position on the way down is, by what the position above it is.
    private enum Role {
        // An expression, a declaration or anything else holding no
        // statement directly. A procedure or a closure may stand in it.
        case other
        // A procedure or a closure: its parameters stand around its body.
        case procedure
        // A list of statements.
        case statements
        case statement
        // A statement's `value`, by the name the statement introduces.
        case value(binding: String?)
        // A construct under its key, by the name the statement binds through.
        case construct(String, binding: String?)
        // A switch's `cases`, and one arm of it.
        case arms
        case arm
    }

    // MARK: - Property
    // Each name once, in the order of its spelling.
    let names: [Name]

    // MARK: - Initializer
    init(of document: Tree, at steps: [Origin.Step]) {
        var spellings = ["const", "var"].flatMap { table in
            document[table]?.dictionaryValue.map { declared in Array(declared.keys) } ?? []
        }
        var node = document
        var role = Role.other

        for step in steps {
            guard let child = Self.child(of: node, at: step) else { break }

            let (introduced, next) = Self.stepping(from: node, as: role, at: step, into: child)

            spellings += introduced
            node = child
            role = next
        }

        self.names = Set(spellings).sorted().compactMap { spelling in try? Name(spelling) }
    }

    // MARK: - Public
    // MARK: - Private
    // The names a step from `node` into `child` brings into scope, and what
    // the child is.
    private static func stepping(
        from node: Tree,
        as role: Role,
        at step: Origin.Step,
        into child: Tree
    ) -> (introduced: [String], role: Role) {
        switch (role, step) {
        case (.procedure, .key("body")):
            return (parameters(of: node), .statements)

        case let (.statements, .index(index)):
            let before = node.arrayValue?.prefix(index) ?? []

            return (before.flatMap(introduced(by:)), .statement)

        case (.statement, .key("value")):
            return ([], .value(binding: node["let"]?.stringValue))

        case let (.value(binding), .key(key)) where Grammar.constructs[key] != nil:
            return ([], .construct(key, binding: binding))

        case let (.construct(construct, binding), .key(key)):
            return parts(of: construct, binding: binding, at: key)

        case (.arms, .key):
            return ([], .arm)

        case (.arm, .key("then")):
            return (node["binds"]?.dictionaryValue?.values.compactMap(\.stringValue) ?? [], .statements)

        default:
            return ([], isProcedure(child) ? .procedure : .other)
        }
    }

    // What a construct binds for the part of it a step goes into: a loop's
    // round in its condition and its body, a try's failure in its catch, an
    // unwrap's payload in its `then`, and the arms of a switch.
    private static func parts(
        of construct: String,
        binding: String?,
        at key: String
    ) -> (introduced: [String], role: Role) {
        let bound = binding.map { name in [name] } ?? []

        let introduced = switch (construct, key) {
        case ("loop", "while"), ("loop", "body"), ("try", "catch"), ("unwrap", "then"):
            bound

        default:
            [String]()
        }

        let role: Role = switch Grammar.constructs[construct]?[key] {
        case .body:
            .statements

        case .arms:
            .arms

        default:
            .other
        }

        return (introduced, role)
    }

    // What a statement introduces to the statements after it: a name it
    // lets or declares a variable of, unless a construct binds through it
    // for its own parts alone. An unwrap with no `then` binds its payload
    // from the statement on.
    private static func introduced(by statement: Tree) -> [String] {
        guard let name = (statement["let"] ?? statement["var"])?.stringValue else { return [] }

        guard
            let construct = statement["value"]?.dictionaryValue,
            construct.count == 1,
            let (key, fields) = construct.first.map({ entry in (entry.key, entry.value) }),
            Grammar.constructs[key] != nil
        else {
            return [name]
        }

        return key == "unwrap" && fields["then"] == nil ? [name] : []
    }

    private static func parameters(of procedure: Tree) -> [String] {
        procedure["parameters"]?.arrayValue?.compactMap { parameter in parameter["name"]?.stringValue } ?? []
    }

    // A procedure or a closure, which holds its statements under `body`.
    private static func isProcedure(_ node: Tree) -> Bool {
        node["body"]?.arrayValue != nil
    }

    private static func child(of node: Tree, at step: Origin.Step) -> Tree? {
        switch step {
        case let .key(key):
            node[key]

        case let .index(index):
            node.arrayValue.flatMap { elements in elements.indices.contains(index) ? elements[index] : nil }
        }
    }
}
