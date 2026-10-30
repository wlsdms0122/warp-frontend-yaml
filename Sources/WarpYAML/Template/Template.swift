//
//  Template.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A string put together from text and values, written
// `{ format: <template>, with: { <name>: <expression>, … } }`: text with
// `${path}` placeholders and `$$` for a literal `$`. A placeholder's path
// starts at a binding under `with` and reads on from it. It is spent into
// `Standard.Text.joined` over the pieces and the empty string, each
// placeholder asked `Standard.Text.text`; one piece of text alone is that
// text.
struct Template {
    // A piece of the template.
    enum Segment: Equatable {
        case text(String)
        case placeholder(Placeholder)
    }

    // The path a placeholder writes: the binding it starts at, and what it
    // reads on from there as written, each path between brackets read as a
    // placeholder of its own.
    struct Placeholder: Equatable {
        enum Step: Equatable {
            case written(String)
            case path(Placeholder)
        }

        // MARK: - Property
        let spelling: String
        let head: String
        let steps: [Step]

        // MARK: - Initializer
        // MARK: - Public
        // MARK: - Private
    }

    // MARK: - Property
    // The keys a template is written under: the text, and what its
    // placeholders are bound to.
    static let formatKey = "format"
    static let withKey = "with"
    static let keys: Set<String> = [formatKey, withKey]

    private static let read = "Standard.Text.text"
    private static let joined = "Standard.Text.joined"
    private static let whiteSpace = CharacterSet.whitespacesAndNewlines

    private let segments: [Segment]

    // Where the template is written, and the expressions its placeholders
    // are bound to.
    private let format: Tree
    private let bindings: [String: Tree]

    // MARK: - Initializer
    // A mapping holding `format` and, where its placeholders read values,
    // `with`.
    init(of mapping: Tree) throws {
        let entries = mapping.dictionaryValue ?? [:]
        let found = entries.keys.sorted()

        guard let format = entries[Self.formatKey] else {
            throw AuthoringError("`with` only accompanies `format` (found keys: \(found))", at: mapping)
        }

        guard Set(found).isSubset(of: Self.keys) else {
            throw AuthoringError(
                "a mapping with `format` holds `format`, the template, and `with`, its bindings,"
                    + " and nothing else (found keys: \(found))",
                at: mapping
            )
        }

        guard let text = format.stringValue else {
            throw AuthoringError("`format` takes a template string", at: format)
        }

        if let with = entries[Self.withKey] {
            guard let bindings = with.dictionaryValue else {
                throw AuthoringError("`format`'s `with` takes a mapping of bindings", at: with)
            }

            self.bindings = bindings
        } else {
            self.bindings = [:]
        }

        self.format = format
        self.segments = try Self.segments(of: text, at: format)
    }

    // MARK: - Public
    // The expression the template stands for, at `format`.
    func spent() throws -> Tree {
        if segments.count == 1, case let .text(only) = segments[0] {
            return format.making(.string(only))
        }

        let pieces: [Tree] = try segments.map { segment in
            switch segment {
            case let .text(text):
                return .string(text)

            case let .placeholder(placeholder):
                return .dictionary([
                    "call": .dictionary([
                        "procedure": .string(Self.read),
                        "arguments": .array([try substituted(placeholder)])
                    ])
                ])
            }
        }

        return format.making(
            .dictionary([
                "call": .dictionary(["procedure": .string(Self.joined), "arguments": .array([.array(pieces), .string("")])])
            ])
        )
    }

    // MARK: - Private
    // The expression a placeholder reads: its binding, or where it reads on,
    // the binding's path with the rest written after it, each path between
    // brackets read over the same bindings.
    private func substituted(_ placeholder: Placeholder) throws -> Tree {
        guard let bound = bindings[placeholder.head] else {
            throw AuthoringError(
                "`format`'s placeholder ${\(placeholder.spelling)} names no binding this template was given",
                at: format
            )
        }

        guard !placeholder.steps.isEmpty else { return bound }

        guard bound.dictionaryValue?.count == 1, var path = bound["ref"]?.stringValue else {
            throw AuthoringError(
                "`format`'s placeholder ${\(placeholder.spelling)} drills into '\(placeholder.head)',"
                    + " which is bound to something other than a name",
                at: format
            )
        }

        for step in placeholder.steps {
            switch step {
            case let .written(text):
                path += text

            case let .path(inner):
                let closed = try substituted(inner)

                guard closed.dictionaryValue?.count == 1, let reached = closed["ref"]?.stringValue else {
                    throw AuthoringError(
                        "`format`'s index ${\(inner.spelling)} is bound to something other than a name,"
                            + " and an index reads a name",
                        at: format
                    )
                }

                path += reached
            }
        }

        return bound.making(.dictionary(["ref": .string(path)]))
    }

    // The text and the placeholders of a template. `${` with no `}` closing
    // it, and `${}` holding nothing, are text.
    private static func segments(of text: String, at format: Tree) throws -> [Segment] {
        var segments: [Segment] = []
        var buffer = ""
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if character == "$", next < text.endIndex, text[next] == "$" {
                buffer.append("$")
                index = text.index(after: next)

                continue
            }

            if
                character == "$",
                next < text.endIndex,
                text[next] == "{",
                let close = closing(text, from: text.index(after: next), opening: "{", closing: "}")
            {
                let inner = String(text[text.index(after: next)..<close])

                if !inner.trimmingCharacters(in: whiteSpace).isEmpty {
                    if !buffer.isEmpty {
                        segments.append(.text(buffer))
                        buffer = ""
                    }

                    segments.append(.placeholder(try placeholder(inner, at: format)))
                    index = text.index(after: close)

                    continue
                }
            }

            buffer.append(character)
            index = next
        }

        if !buffer.isEmpty {
            segments.append(.text(buffer))
        }

        return segments
    }

    // A path: its head up to the first `.`, `?` or `[`, then the rest as
    // written, with what stands between brackets read as a path of its own
    // unless it is an integer or a string.
    private static func placeholder(_ written: String, at format: Tree) throws -> Placeholder {
        let text = written.trimmingCharacters(in: whiteSpace)
        let rest = text.firstIndex { character in ".?[".contains(character) } ?? text.endIndex
        var steps: [Placeholder.Step] = []
        var buffer = ""
        var index = rest

        while index < text.endIndex {
            let character = text[index]

            guard character == "[" else {
                buffer.append(character)
                index = text.index(after: index)

                continue
            }

            let start = text.index(after: index)

            guard let close = closing(text, from: start, opening: "[", closing: "]") else {
                throw AuthoringError(
                    "`format`'s placeholder ${\(text)}: the path ends inside `[`, and a `[` is closed by `]`",
                    at: format
                )
            }

            let inner = peeled(String(text[start..<close]).trimmingCharacters(in: whiteSpace))

            if inner.hasPrefix("\"") || isInteger(inner) {
                buffer += "[\(inner)]"
            } else {
                steps.append(.written(buffer + "["))
                steps.append(.path(try placeholder(inner, at: format)))
                buffer = "]"
            }

            index = text.index(after: close)
        }

        if !buffer.isEmpty {
            steps.append(.written(buffer))
        }

        return Placeholder(
            spelling: text,
            head: String(text[..<rest]).trimmingCharacters(in: whiteSpace),
            steps: steps
        )
    }

    // Where the bracket opened before `start` closes, past the brackets
    // inside it and what stands between quotes, and nothing where it does
    // not.
    private static func closing(
        _ text: String,
        from start: String.Index,
        opening: Character,
        closing: Character
    ) -> String.Index? {
        var depth = 1
        var quoted = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]

            if quoted {
                if escaped {
                    escaped = false
                } else if character == "\\" {
                    escaped = true
                } else if character == "\"" {
                    quoted = false
                }
            } else if character == "\"" {
                quoted = true
            } else if character == opening {
                depth += 1
            } else if character == closing {
                depth -= 1

                if depth == 0 {
                    return index
                }
            }

            index = text.index(after: index)
        }

        return nil
    }

    // A path between brackets may be written as a placeholder of its own.
    private static func peeled(_ inner: String) -> String {
        guard inner.hasPrefix("${"), inner.hasSuffix("}") else { return inner }

        return String(inner.dropFirst(2).dropLast()).trimmingCharacters(in: whiteSpace)
    }

    private static func isInteger(_ text: String) -> Bool {
        let digits = text.first.map { sign in "+-".contains(sign) } == true ? text.dropFirst() : Substring(text)

        return !digits.isEmpty && digits.allSatisfy { digit in ("0"..."9").contains(digit) }
    }
}
