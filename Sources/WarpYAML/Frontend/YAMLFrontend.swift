//
//  YAMLFrontend.swift
//  WarpYAML
//
//  Created by JSilver on 8/21/26.
//

import Foundation

// Text in, the `.warp` bytes of its document and their `Origin` out. The
// text is parsed onto a tree, and each spend is a pass over that tree:
// `name:` put on the text's own keys, the prose and the defaults taken off,
// the defaults spent, the statement and expression shorthands spent in one
// walk, short names written in full, a call's arguments written by name put
// in its callee's order, a closure completed from its slot, and the document
// finished the one way, with `warp` and `imports` where the text writes
// none. What the text writes beside its declarations is handed back by
// `documentation(from:)`. The Front loads nothing it writes: whoever loads
// the bytes refuses what the load refuses, and reads where a refused place
// stands in the text through the `Origin` handed with them. A refusal of the
// Front's own is an `AuthoringError` at the position the text wrote, or with
// the text's position among those handed together. A spend runs on a
// `SpendingThread`, its caller waiting, so a caller spends from any thread.
//
// A text's declarations are read first, so its own procedures are declared
// beside those it leans on, and the whole text is then read against those
// declarations. Texts that lean on each other are spent the same way
// together, in any order. What a text leans on is `Standard`'s declarations,
// read from the interface the specification gives, and those of the texts
// and the interfaces it is handed.
public struct YAMLFrontend: Sendable {
    // MARK: - Property
    private let parser: YAMLParser

    // The declarations a text leans on.
    private let declarations: Declarations

    // MARK: - Initializer
    // Reading against `Standard`'s declarations.
    public init() throws {
        self.init(declarations: try Declarations.standard())
    }

    private init(declarations: Declarations) {
        self.parser = YAMLParser()
        self.declarations = declarations
    }

    // MARK: - Public
    public func document(from text: String) throws -> (document: Data, origin: Origin) {
        try SpendingThread().run {
            let parsed = try parser.parse(text)
            let table = try Self.declaring([(nil, parsed)], onto: declarations)

            return try Self.written(try Self.spent(parsed, leaningOn: table))
        }
    }

    public func document(from data: Data) throws -> (document: Data, origin: Origin) {
        try document(from: try parser.utf8(of: data))
    }

    // What the text says beside its declarations, by the names its document
    // declares them by: a procedure's `description` and a parameter's `hint`.
    // Read off the declarations, with no body spent.
    public func documentation(from text: String) throws -> Documentation {
        try SpendingThread().run {
            let parsed = try parser.parse(text)
            let naming = try Naming(of: parsed, leaningOn: try Self.declaring([(nil, parsed)], onto: declarations))

            return try Annotation(of: try naming.prefixed(parsed), reading: naming).documentation
        }
    }

    public func documentation(from data: Data) throws -> Documentation {
        try documentation(from: try parser.utf8(of: data))
    }

    // Texts that lean on each other, each spent into its document's bytes and
    // their `Origin`, in the order they are handed. A text names another's
    // declarations as it names a leaned-on text's. A refusal says which text
    // it stands in.
    public func documents(from texts: [String]) throws -> [(document: Data, origin: Origin)] {
        try SpendingThread().run {
            let parsed: [(position: Int?, text: Tree)] = try texts.enumerated().map { position, text in
                (position, try Self.inText(position) { try parser.parse(text) })
            }
            let table = try Self.declaring(parsed, onto: declarations)

            return try parsed.map { position, text in
                try Self.inText(position) { try Self.written(try Self.spent(text, leaningOn: table)) }
            }
        }
    }

    // This front end leaning on these as well, for a caller that spends texts
    // one at a time or asks where one of them is. A refusal says which of
    // them it stands in.
    public func leaning(on dependencies: [Dependency]) throws -> YAMLFrontend {
        try SpendingThread().run {
            var held = declarations
            var texts: [(position: Int?, text: Tree)] = []

            for (position, dependency) in dependencies.enumerated() {
                switch dependency {
                case let .text(text):
                    texts.append((position, try Self.inText(position) { try parser.parse(text) }))

                case let .interface(interface):
                    held = try Self.inText(position) { try held.adding(try InterfaceReader().read(interface)) }
                }
            }

            return YAMLFrontend(declarations: try Self.declaring(texts, onto: held))
        }
    }

    // What a declaration of this name in that space shadows for a text
    // leaning on this front end: the declarations the text names by it, and,
    // for a procedure, whether this notation reads a one-key mapping under it
    // as its own, where a value is wanted or under a statement's `value`.
    public func shadowing(_ name: Name, as space: Space) -> Shadowing {
        let key = name.spelling

        return Shadowing(
            declarations: declarations.declarations(named: name, in: space),
            isKeyword: space == .procedure
                && (ExpressionSugar.claims(key) || Grammar.claims(key) || StatementSugar.claims(key))
        )
    }

    // MARK: - Private
    // The document a parsed text spells, read against `table`: the
    // declarations of what it leans on, its own among them.
    private static func spent(_ parsed: Tree, leaningOn table: Declarations) throws -> Tree {
        let naming = try Naming(of: parsed, leaningOn: table)
        let annotation = try Annotation(of: try naming.prefixed(parsed), reading: naming)
        let shorthands = try Grammar().rewriting(
            try annotation.defaulted(annotation.document),
            [StatementSugar().rewritten, ExpressionSugar(reading: naming).rewritten]
        )
        let matched = try ArgumentMatching(declarations: table).matched(try naming.resolved(shorthands))

        return try OneWay().written(try Elaborator(leaningOn: table).completed(matched))
    }

    // A spent document's bytes, and where the text is for a place in them.
    private static func written(_ document: Tree) throws -> (document: Data, origin: Origin) {
        (try BinaryWriter().write(document), Origin(document))
    }

    // `held` with what these texts declare: each text's declarations alone,
    // the short name of a type read against the types of every text. A
    // declaration names no body, so no text has to be read before another;
    // two texts sending each other are a cycle the build refuses. A text
    // whose declarations do not read is refused where it writes them, before
    // any call is matched.
    private static func declaring(
        _ texts: [(position: Int?, text: Tree)],
        onto held: Declarations
    ) throws -> Declarations {
        let types = try texts.flatMap { position, text in
            try inText(position) { try Self.types(declaredBy: text, leaningOn: held) }
        }
        let collector = DeclarationCollector(leaningOn: held.adding(types: types))

        return try texts.reduce(held) { declared, written in
            try inText(written.position) { try declared.adding(try collector.collected(written.text)) }
        }
    }

    // The full names of the types and contracts a parsed text declares. A
    // key that is no name is the load's to refuse, and is left out here.
    private static func types(declaredBy parsed: Tree, leaningOn held: Declarations) throws -> [Name] {
        let prefixed = try Naming(of: parsed, leaningOn: held).prefixed(parsed)

        return ["types", "contracts"].flatMap { table in
            (prefixed[table]?.dictionaryValue?.keys).map { keys in keys.compactMap { key in try? Name(key) } } ?? []
        }
    }

    // What `spend` makes of one text, a refusal saying which text it stands
    // in where the text has a position among those handed together.
    private static func inText<Spent>(_ position: Int?, _ spend: () throws -> Spent) throws -> Spent {
        do {
            return try spend()
        } catch let refusal as AuthoringError {
            guard let position else { throw refusal }

            throw AuthoringError(refusal, inText: position)
        }
    }
}
