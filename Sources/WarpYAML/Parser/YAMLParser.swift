//
//  YAMLParser.swift
//  WarpYAML
//
//  Created by JSilver on 8/15/26.
//

import Foundation
import Yams

// YAML text to a `Tree`, each node at the position the text wrote it at. It
// knows YAML and nothing about programs.
struct YAMLParser: Sendable {
    // MARK: - Property
    // The prefix the secondary tag handle `!!` stands for.
    private static let secondaryHandlePrefix = "tag:yaml.org,2002:"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    func parse(_ data: Data) throws -> Tree {
        try parse(try utf8(of: data))
    }

    func parse(_ text: String) throws -> Tree {
        try tree(fromNode: try composed(withoutByteOrderMark(text)), depth: 0)
    }

    // The text the bytes hold, for the doors that take `Data`. Bytes that are
    // not UTF-8 are refused at the first one, counted in the text a parse
    // reads.
    func utf8(of data: Data) throws -> String {
        var bytes = data.makeIterator()
        var parser = Unicode.UTF8.ForwardParser()
        var valid = 0

        while case let .valid(scalar) = parser.parseScalar(from: &bytes) {
            valid += scalar.count
        }

        let text = String(decoding: data.prefix(valid), as: UTF8.self)

        guard valid == data.count else {
            throw AuthoringError("the text is not UTF-8", at: position(after: withoutByteOrderMark(text)))
        }

        return text
    }

    // MARK: - Private
    // The text as written, without the byte order mark in front of it, which
    // says how the bytes are encoded and is not text.
    private func withoutByteOrderMark(_ text: String) -> String {
        guard text.unicodeScalars.first == "\u{FEFF}" else { return text }

        return String(text.unicodeScalars.dropFirst())
    }

    private func composed(_ text: String) throws -> Yams.Node {
        // Yams resolves a key's tag in place to compare keys, and an alias is
        // its anchor's node, tag and all. A resolver whose one rule gives
        // implicit for every scalar keeps a scalar the text wrote no tag on
        // untagged after compose.
        let resolver = try Resolver.basic.appending(.implicit, "^")
        let root: Yams.Node?

        do {
            root = try Yams.compose(yaml: text, resolver)
        } catch let YamlError.duplicatedKeysInMapping(duplicates, _) {
            throw try repeated(among: duplicates)
        } catch let refused as YamlError {
            throw refusal(refused)
        }

        guard let root else {
            throw AuthoringError("the text holds no YAML document", at: position(after: text))
        }

        return root
    }

    // What Yams refused, at the position it gives.
    private func refusal(_ refused: YamlError) -> AuthoringError {
        switch refused {
        case let .scanner(context, problem, mark, _),
            let .parser(context, problem, mark, _),
            let .composer(context, problem, mark, _):
            return AuthoringError(
                context.map { context in "\(context.text), \(problem)" } ?? problem,
                at: position(of: mark)
            )

        case let .reader(problem, offset, _, yaml):
            return AuthoringError(problem, at: offset.map { offset in position(after: yaml.prefix(offset)) })

        default:
            return AuthoringError("\(refused)")
        }
    }

    // A key written again in a mapping, refused at the repeat written first
    // in the text. The keys are nodes compose made.
    private func repeated(among duplicates: [Yams.Node: [Yams.Node]]) throws -> AuthoringError {
        let repeats = try duplicates.values
            .flatMap { keys in keys.dropFirst() }
            .map { key in (key: key, position: try position(ofComposed: key.mark)) }

        guard
            let first = repeats.min(by: { one, other in
                (one.position.line, one.position.column) < (other.position.line, other.position.column)
            })
        else {
            return uncomposed("the YAML parse refused a repeated key and named none")
        }

        guard case let .scalar(key) = first.key else {
            return AuthoringError("non-scalar mapping key is not supported", at: first.position)
        }

        return twice(key.string, at: first.position)
    }

    // The position Yams gives with a refusal, which may be none.
    private func position(of mark: Mark?) -> Origin.Position? {
        mark.map { mark in Origin.Position(line: mark.line, column: mark.column) }
    }

    // The position of a node compose made. Compose marks every node.
    private func position(ofComposed mark: Mark?) throws -> Origin.Position {
        guard let mark else { throw uncomposed("the YAML parse gave a node with no mark") }

        return Origin.Position(line: mark.line, column: mark.column)
    }

    // The position of what follows the text, counted the way a mark is: lines
    // and unicode scalars, both from one. A line ends at a line feed, a
    // carriage return, the two together, a next line, a line separator or a
    // paragraph separator.
    private func position(after text: some StringProtocol) -> Origin.Position {
        var line = 1
        var column = 1
        var previous: Unicode.Scalar?

        for scalar in text.unicodeScalars {
            switch scalar {
            case "\n" where previous == "\r":
                break

            case "\n", "\r", "\u{85}", "\u{2028}", "\u{2029}":
                line += 1
                column = 1

            default:
                column += 1
            }

            previous = scalar
        }

        return Origin.Position(line: line, column: column)
    }

    // A mapping's entry stands at its key's position: the last step of a
    // place names the key, and a mapping's own mark is its first key's.
    // `depth` counts the containers `node` stands in.
    private func tree(fromNode node: Yams.Node, depth: Int) throws -> Tree {
        let own = try position(ofComposed: node.mark)

        switch node {
        case let .scalar(scalar):
            return Tree(try content(fromScalar: scalar), at: own)

        case let .sequence(sequence):
            try refuseTag(sequence.tag, otherThan: .seq, on: "a sequence", at: own)
            try refuseDepth(depth, at: own)

            return Tree(.array(try sequence.map { element in try tree(fromNode: element, depth: depth + 1) }), at: own)

        case let .mapping(mapping):
            try refuseTag(mapping.tag, otherThan: .map, on: "a mapping", at: own)
            try refuseDepth(depth, at: own)

            var entries: [String: Tree] = [:]

            for (key, entry) in mapping {
                guard case let .scalar(scalarKey) = key else {
                    throw AuthoringError("non-scalar mapping key is not supported", at: try position(ofComposed: key.mark))
                }

                let position = try position(ofComposed: scalarKey.mark)

                try refuseTag(scalarKey.tag, otherThan: .str, on: "a key", at: position)

                guard entries[scalarKey.string] == nil else {
                    throw twice(scalarKey.string, at: position)
                }

                entries[scalarKey.string] = try tree(fromNode: entry, depth: depth + 1).positioned(at: position)
            }

            return Tree(.dictionary(entries), at: own)

        case .alias:
            throw uncomposed("the YAML parse left an alias unresolved")
        }
    }

    // A container at `depth` is the next one in, against the bound the
    // binary writer holds: a text nesting deeper is no document, and is
    // refused where it crosses the bound, before any pass walks it.
    private func refuseDepth(_ depth: Int, at position: Origin.Position) throws {
        guard depth < BinaryWriter.depthBound else {
            throw AuthoringError("the text nests deeper than \(BinaryWriter.depthBound) containers", at: position)
        }
    }

    // A collection or a key takes no tag, or the core schema's tag for its
    // kind. A key is a string.
    private func refuseTag(
        _ tag: Tag,
        otherThan kind: Tag.Name,
        on taker: String,
        at position: Origin.Position
    ) throws {
        let name = Tag.Name(rawValue: tag.rawValue)

        guard name == .implicit || name == .nonSpecific || name == kind else {
            throw refusal(of: name, on: taker, at: position)
        }
    }

    // A tag a node does not take, refused as which of two it is: outside the
    // core schema, or a core schema tag of another kind.
    private func refusal(
        of tag: Tag.Name,
        on taker: String,
        at position: Origin.Position
    ) -> AuthoringError {
        switch tag {
        case .str, .seq, .map, .null, .bool, .int, .float:
            return AuthoringError("'\(spelling(of: tag))' is not a tag \(taker) takes", at: position)

        default:
            return AuthoringError("tag '\(spelling(of: tag))' is outside the core schema this notation reads", at: position)
        }
    }

    // A tag the way a text writes it, under the `!!` handle where it has
    // that handle's prefix.
    private func spelling(of tag: Tag.Name) -> String {
        guard tag.rawValue.hasPrefix(Self.secondaryHandlePrefix) else { return tag.rawValue }

        return "!!\(tag.rawValue.dropFirst(Self.secondaryHandlePrefix.count))"
    }

    // A scalar by its tag. A quoted or block scalar is tagged as a string by
    // the parse.
    private func content(fromScalar scalar: Yams.Node.Scalar) throws -> Tree.Content {
        let text = scalar.string
        let position = try self.position(ofComposed: scalar.mark)

        switch Tag.Name(rawValue: scalar.tag.rawValue) {
        case .implicit:
            return try implicit(text, at: position)

        case .str, .nonSpecific:
            return .string(text)

        case let tag:
            guard let typed = try tagged(text, as: tag, at: position) else {
                throw AuthoringError("'\(text)' is tagged '\(spelling(of: tag))' and does not read as one", at: position)
            }

            return typed
        }
    }

    // An untagged plain scalar, typed by JSON's literals and nothing wider,
    // so `no`, `on`, `09:20` and `007` stay strings.
    private func implicit(_ text: String, at position: Origin.Position) throws -> Tree.Content {
        switch text {
        case "", "~", "null":
            return .null

        case "true":
            return .bool(true)

        case "false":
            return .bool(false)

        default:
            break
        }

        // An integer literal too wide for `Int` is refused rather than widened,
        // so a document that wrote every digit is not read as one that wrote
        // roughly that many.
        if matches(text, #"^-?(0|[1-9][0-9]*)$"#) {
            guard let integer = Int(text) else {
                throw quotable(notAnInt(text), at: position)
            }

            return .int(integer)
        }

        guard matches(text, #"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"#) else {
            return .string(text)
        }

        guard let double = Double(text), double.isFinite else {
            throw quotable(notFinite(text), at: position)
        }

        return .double(double)
    }

    // A scalar under an explicit tag, read by that tag's forms in the YAML 1.2
    // core schema. Nil where the text is none of them.
    private func tagged(_ text: String, as tag: Tag.Name, at position: Origin.Position) throws -> Tree.Content? {
        switch tag {
        case .null:
            return ["", "~", "null", "Null", "NULL"].contains(text) ? .null : nil

        case .bool:
            switch text {
            case "true", "True", "TRUE":
                return .bool(true)

            case "false", "False", "FALSE":
                return .bool(false)

            default:
                return nil
            }

        case .int:
            let integer: Int?

            if matches(text, #"^[-+]?[0-9]+$"#) {
                integer = Int(text)
            } else if matches(text, #"^0o[0-7]+$"#) {
                integer = Int(text.dropFirst(2), radix: 8)
            } else if matches(text, #"^0x[0-9a-fA-F]+$"#) {
                integer = Int(text.dropFirst(2), radix: 16)
            } else {
                return nil
            }

            guard let integer else {
                throw AuthoringError(notAnInt(text), at: position)
            }

            return .int(integer)

        case .float:
            let nonFinite = matches(text, #"^([-+]?\.(inf|Inf|INF)|\.(nan|NaN|NAN))$"#)

            guard nonFinite || matches(text, #"^[-+]?(\.[0-9]+|[0-9]+(\.[0-9]*)?)([eE][-+]?[0-9]+)?$"#) else {
                return nil
            }

            guard !nonFinite, let double = Double(text), double.isFinite else {
                throw AuthoringError(notFinite(text), at: position)
            }

            return .double(double)

        default:
            throw refusal(of: tag, on: "a scalar", at: position)
        }
    }

    // What a number Warp does not hold is refused with, said one way whether
    // or not the text tagged it.
    private func notAnInt(_ text: String) -> String {
        "'\(text)' does not fit an Int, a 64-bit integer"
    }

    private func notFinite(_ text: String) -> String {
        "'\(text)' is not a finite number, and Warp numbers are finite"
    }

    // A refusal of an untagged scalar, which quoting reads as a string.
    private func quotable(_ message: String, at position: Origin.Position) -> AuthoringError {
        AuthoringError("\(message). Quote it if you meant a string", at: position)
    }

    private func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    // A key written again in its mapping, refused where it is written again.
    private func twice(_ key: String, at position: Origin.Position) -> AuthoringError {
        AuthoringError("'\(key)' is a key twice in one mapping", at: position)
    }

    // A node compose does not give: it resolves every alias and marks every
    // node. The refusal is the parse's and not the text's, so it has no
    // position.
    private func uncomposed(_ message: String) -> AuthoringError {
        assertionFailure(message)

        return AuthoringError(message)
    }
}
