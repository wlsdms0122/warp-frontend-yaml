//
//  CompletionPoint.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// A text being written, at the position a completion is asked at. What
// stands there may not read yet, so the innermost statement or construct
// condition holding the position is written as what it reads: the path
// written before the last dot under the `ref` the position stands in, or
// null. A statement is written as `{ value: <that> }`, which binds no name,
// and a construct's condition as that alone, its bodies empty. What is read
// there stands before it, so the statements after it, in its body and in
// each body around it, are left out.
struct CompletionPoint {
    // MARK: - Property
    // The keys a list of statements stands under in a construct, which a
    // procedure's and a closure's `body` is among.
    private static let statementLists = Set(Grammar.constructs.values.flatMap { parts in
        parts.filter { _, kind in kind == .body }.keys
    })

    // The text with what stands at the position written as what it reads.
    let text: Tree

    // The procedure whose body holds the position, by what it is declared
    // under.
    let procedure: Grammar.Kind

    // The position, and which of the texts spent together it stands in, nil
    // for a text spent alone.
    private let position: Origin.Position
    private let inText: Int?

    // What is written in place, and whether it is a statement.
    private let written: Tree
    private let isStatement: Bool

    // Whether what is written reads a path.
    private let readsPath: Bool

    // MARK: - Initializer
    // A parsed text at `position`. A position in no procedure's body is
    // refused there.
    init(in text: Tree, inText index: Int?, at position: Origin.Position) throws(AuthoringError) {
        let path = text.path(to: position)

        guard
            let at = path.indices.last(where: { index in Self.replaces(at: index, on: path) }),
            let procedure = Self.procedure(on: path.map(\.step))
        else {
            throw Self.refusal(at: position, inText: index)
        }

        let replaced = path[at].node
        let receiver = path.last.flatMap { last in
            last.step == .key("ref") ? last.node.stringValue.flatMap(Self.receiver(of:)) : nil
        }
        let read = receiver.map { receiver in
            Tree(.dictionary(["ref": Tree(.string(receiver), at: path.last?.node.position)]), at: path.last?.node.position)
        } ?? Tree(.null, at: replaced.position)
        let isStatement = Self.conditionKey(on: path, at: at) == nil
        let written = isStatement ? Tree(.dictionary(["value": read]), at: replaced.position) : read

        self.text = Self.replacing(in: text, at: Array(path[...at].map(\.step)), under: nil, with: written)
        self.procedure = procedure
        self.position = position
        self.inText = index
        self.written = written
        self.isStatement = isStatement
        self.readsPath = receiver != nil
    }

    // MARK: - Public
    // Where what was written in place stands in the document the text was
    // spent into, in its own text among those spent together, and where the
    // path it reads does, nil where it reads none. Refused where the spend
    // did not keep it.
    func places(in document: Tree) throws(AuthoringError) -> (
        written: [Origin.Step],
        receiver: [Origin.Step]?
    ) {
        guard let steps = Self.steps(to: written, inText: inText, in: document, from: []) else {
            throw Self.refusal(at: position, inText: inText)
        }

        let read = isStatement ? steps + [.key("value")] : steps

        return (steps, readsPath ? read : nil)
    }

    // MARK: - Private
    private static func refusal(at position: Origin.Position, inText index: Int?) -> AuthoringError {
        let refusal = AuthoringError("no statement of a procedure's body stands here", at: position)

        return index.map { index in AuthoringError(refusal, inText: index) } ?? refusal
    }

    // Whether the node at `index` on the way down is what is written in
    // place: a mapping in a list of statements, or a construct's condition.
    private static func replaces(at index: Int, on path: [(step: Origin.Step, node: Tree)]) -> Bool {
        guard index > 0 else { return false }

        if case .index = path[index].step, case let .key(list) = path[index - 1].step, statementLists.contains(list) {
            return path[index].node.dictionaryValue != nil
        }

        return conditionKey(on: path, at: index) != nil
    }

    // The key of a construct's condition the node at `index` stands under,
    // a statement's `value` holding the construct: `while`, `when` or `of`.
    private static func conditionKey(on path: [(step: Origin.Step, node: Tree)], at index: Int) -> String? {
        guard
            index > 1,
            case let .key(part) = path[index].step,
            case let .key(construct) = path[index - 1].step,
            path[index - 2].step == .key("value"),
            Grammar.constructs[construct]?[part] == .expression
        else {
            return nil
        }

        return part
    }

    // The procedure a way down goes into, by the owner it is declared under,
    // as `Grammar` reads a document.
    private static func procedure(on steps: [Origin.Step]) -> Grammar.Kind? {
        let keys = steps.prefix(4).map { step -> String? in
            guard case let .key(key) = step else { return nil }

            return key
        }

        guard keys.count >= 2, let table = keys[0], let name = keys[1] else { return nil }

        if table == "procedures" {
            return .procedure(.document, key: name)
        }

        guard keys.count == 4, keys[2] == "procedures", let key = keys[3] else { return nil }

        switch table {
        case "types":
            return .procedure(.type(name), key: key)

        case "extensions":
            return .procedure(.extension(name), key: key)

        case "contracts":
            return .procedure(.contract(name), key: key)

        default:
            return nil
        }
    }

    // The path a `ref` holds before its last dot, where the position stands
    // at the end of what is written. Within brackets left open, the path
    // being written between them. Nothing where no dot ends a path.
    static func receiver(of written: String) -> String? {
        let scalars = Array(written.unicodeScalars)
        // Where each open bracket's path starts, and its last dot.
        var open: [(start: Int, dot: Int?)] = [(0, nil)]
        var quote: Unicode.Scalar?
        var index = 0

        while index < scalars.count {
            let scalar = scalars[index]

            if let opened = quote {
                if scalar == "\\" {
                    index += 1
                } else if scalar == opened {
                    quote = nil
                }
            } else {
                switch scalar {
                case "\"", "'":
                    quote = scalar

                case "[":
                    open.append((index + 1, nil))

                case "]" where open.count > 1:
                    open.removeLast()

                case ".":
                    open[open.count - 1].dot = index

                default:
                    break
                }
            }

            index += 1
        }

        guard let innermost = open.last, let dot = innermost.dot else { return nil }

        var path = String(String.UnicodeScalarView(scalars[innermost.start..<dot]))

        if path.hasSuffix("?") {
            path.removeLast()
        }

        return path.isEmpty ? nil : path
    }

    // The tree with what the steps reach replaced. In each list of
    // statements on the way, the statements after the one stepped into are
    // left out, and where a construct's condition is replaced, the
    // construct's bodies are left empty. `key` is the key the tree stands
    // under.
    private static func replacing(
        in tree: Tree,
        at steps: [Origin.Step],
        under key: String?,
        with replacement: Tree
    ) -> Tree {
        guard let step = steps.first else { return replacement }

        let rest = Array(steps.dropFirst())

        switch (step, tree.content) {
        case let (.key(child), .dictionary(entries)):
            guard let held = entries[child] else { return tree }

            var replaced = entries
            replaced[child] = replacing(in: held, at: rest, under: child, with: replacement)

            if rest.isEmpty, let key, let parts = Grammar.constructs[key] {
                for (part, kind) in parts where part != child {
                    replaced[part] = replaced[part].map { held in emptied(held, as: kind) }
                }
            }

            return tree.holding(.dictionary(replaced))

        case let (.index(index), .array(elements)) where elements.indices.contains(index):
            var replaced = key.map(statementLists.contains) == true ? Array(elements.prefix(index + 1)) : elements
            replaced[index] = replacing(in: elements[index], at: rest, under: nil, with: replacement)

            return tree.holding(.array(replaced))

        default:
            return tree
        }
    }

    // A construct's part with no statement in it: a body empty, and each
    // arm's `then`.
    private static func emptied(_ part: Tree, as kind: Grammar.Kind) -> Tree {
        switch kind {
        case .body:
            return part.holding(.array([]))

        case .arms:
            guard let arms = part.dictionaryValue else { return part }

            return part.holding(.dictionary(arms.mapValues { arm in
                guard var fields = arm.dictionaryValue, let then = fields["then"] else { return arm }

                fields["then"] = then.holding(.array([]))

                return arm.holding(.dictionary(fields))
            }))

        default:
            return part
        }
    }

    // The steps to what was written in place: the node the text wrote at its
    // position, holding what it holds.
    private static func steps(
        to written: Tree,
        inText text: Int?,
        in node: Tree,
        from steps: [Origin.Step]
    ) -> [Origin.Step]? {
        if !node.isImplicit, node.text == text, node.position == written.position, node == written {
            return steps
        }

        switch node.content {
        case let .dictionary(entries):
            return entries.lazy.compactMap { key, child in
                Self.steps(to: written, inText: text, in: child, from: steps + [.key(key)])
            }.first

        case let .array(elements):
            return elements.enumerated().lazy.compactMap { index, child in
                Self.steps(to: written, inText: text, in: child, from: steps + [.index(index)])
            }.first

        case .null, .bool, .int, .double, .string:
            return nil
        }
    }
}
