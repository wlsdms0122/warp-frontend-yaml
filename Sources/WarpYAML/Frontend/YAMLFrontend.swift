//
//  YAMLFrontend.swift
//  WarpYAML
//
//  Created by JSilver on 8/21/26.
//

import Foundation

// Text in, the `.warp` bytes of its document and their `Origin` out. The
// text is parsed onto a tree, and each spend is a pass over that tree: an
// enum's raw values written as its procedures, `uses:` read, `name:` put on
// the text's own keys, the prose and the defaults taken off, the defaults
// spent, the statement and expression shorthands spent in one walk, short
// names written in full, a call's arguments written by name, or none, put
// in its callee's order, a closure completed from its slot, every name the
// program uses found, and the document finished the one way, with `warp`
// where the text writes none, the names its program uses as its `imports` and the
// claims it stands on as its `importedClaims`. What the text writes beside
// its declarations is handed back by `documentation(from:)`. The Front loads nothing it writes: whoever loads
// the bytes refuses what the load refuses, and reads where a refused place
// stands in the text through the `Origin` handed with them. A refusal of the
// Front's own is an `AuthoringError` at the position the text wrote, with
// the text's position among those handed together, and the texts are
// refused with every such refusal at once, a `TextRefused`.
//
// The texts spent together are one module, and one document. Each reads the
// declarations of its own module, of `Standard` and of the modules it writes
// under `uses:`, the dependencies this front end is handed, and a name none
// of them declares is refused where it is written. A text's declarations are
// read first, so its own procedures are declared beside those it reads, and
// the whole text is then read against them. What a text declares `private`
// the module's other texts do not name.
//
// A claim a used module makes, written beside neither the type nor the
// contract it is about, is reached by nothing a document names, so the
// document imports it: each such claim of every module a text uses, whether
// or not the text stands on it.
public struct YAMLFrontend: Sendable {
    // MARK: - Property
    private static let standardModule: Name = "Standard"

    private let parser: YAMLParser

    // `Standard`'s declarations, which every text reads.
    private let standard: Declarations

    // The declarations of each module a text may use, by its name.
    private let modules: [Name: Declarations]

    // The claims each module makes that a document using it imports, by the
    // module's name, `Standard`'s among them.
    private let claims: [Name: Set<ImportedClaims.Claim>]

    // MARK: - Initializer
    // Reading against `Standard`'s declarations.
    public init() throws {
        let interface = try InterfaceReader().read(Data(Declarations.standardInterface.utf8))

        self.init(
            standard: try Declarations().adding(interface),
            modules: [:],
            claims: [Self.standardModule: ImportedClaims.orphans(of: interface)]
        )
    }

    private init(standard: Declarations, modules: [Name: Declarations], claims: [Name: Set<ImportedClaims.Claim>]) {
        self.parser = YAMLParser()
        self.standard = standard
        self.modules = modules
        self.claims = claims
    }

    // MARK: - Public
    public func document(from text: String) throws -> (document: Data, origin: Origin) {
        try Self.refusing { try spent([(nil, try read(text))]) }
    }

    public func document(from data: Data) throws -> (document: Data, origin: Origin) {
        try document(from: try Self.refusing { try parser.utf8(of: data) })
    }

    // What the text says beside its declarations, by the names its document
    // declares them by: a procedure's `description` and a parameter's `hint`.
    // Read off the declarations, with no body spent.
    public func documentation(from text: String) throws -> Documentation {
        try Self.refusing {
            let (parsed, reached, _) = try reaching(try read(text))
            let naming = try Naming(
                of: parsed,
                reading: try Self.declaring([(nil, parsed, reached)])[0].merging(reached)
            )

            return try Annotation(of: try naming.prefixed(parsed), reading: naming).documentation
        }
    }

    public func documentation(from data: Data) throws -> Documentation {
        try documentation(from: try Self.refusing { try parser.utf8(of: data) })
    }

    // The texts of one module, spent into the module's document's bytes and
    // their `Origin`. A text names another's declarations as it names its
    // own. A refusal, and a place the `Origin` reads, says which text it
    // stands in, by its position among those handed. A module is written in
    // one text or more, so none is refused.
    public func document(from texts: [String]) throws -> (document: Data, origin: Origin) {
        try Self.refusing {
            guard !texts.isEmpty else { throw AuthoringError("a module is written in one text or more") }

            return try spent(try texts.enumerated().map { position, text in
                (position, try Self.inText(position) { try read(text) })
            })
        }
    }

    // This front end with these modules as well, for a text to use. Every
    // dependency handed under one name is a part of one module, and a module
    // this front end already has gains them. A YAML text handed is not
    // spent: its declarations are read against those of every module
    // handed. A refusal says which of them it stands in.
    public func depending(on dependencies: [Dependency]) throws -> YAMLFrontend {
        try Self.refusing {
            var held = modules
            var claimed = claims
            var texts: [(position: Int?, text: Tree, module: Name)] = []

            for (position, dependency) in dependencies.enumerated() {
                try Self.inText(position) {
                    switch dependency {
                    case let .text(text, module):
                        try Self.check(module)

                        texts.append((position, try read(text), module))

                    case let .interface(interface, module):
                        try Self.check(module)

                        let piece = try InterfaceReader().read(interface)

                        held[module] = try held[module, default: Declarations()].adding(piece)
                        claimed[module, default: []].formUnion(ImportedClaims.orphans(of: piece))
                    }
                }
            }

            let everything = every(held)
            let types = try texts.flatMap { position, text, _ in
                try Self.inText(position) { try Self.types(declaredBy: text, reading: everything) }
            }
            let collector = DeclarationCollector(reading: everything.adding(types: types))

            for (position, text, module) in texts {
                let piece = try Self.inText(position) { try collector.collected(text) }

                held[module] = try Self.inText(position) { try held[module, default: Declarations()].adding(piece) }
                claimed[module, default: []].formUnion(ImportedClaims.orphans(of: piece))
            }

            return YAMLFrontend(standard: standard, modules: held, claims: claimed)
        }
    }

    // What a completion at `position` of a text being written reads. The
    // statement or the construct's condition standing there is written as
    // what it reads, and where the text still does not spend, the procedure
    // holding it is read with every other body empty. A position in no
    // procedure's body is refused there.
    public func completion(at position: Origin.Position, in text: String) throws -> Completion {
        try Self.refusing { try completion(at: position, inText: 0, of: [(nil, try read(text))]) }
    }

    // The same, at `position` of the text at `index` among the texts of one
    // module, each naming the others' declarations. Where the module still
    // does not spend, the others are read with every body empty.
    public func completion(at position: Origin.Position, inText index: Int, of texts: [String]) throws -> Completion {
        try Self.refusing {
            guard texts.indices.contains(index) else {
                throw AuthoringError("a completion is asked in one of the module's texts, and there is no text \(index)")
            }

            return try completion(at: position, inText: index, of: try texts.enumerated().map { number, text in
                (position: number, text: try Self.inText(number) { try read(text) })
            })
        }
    }

    // What a declaration of this name in that space shadows for a text
    // using every module this front end depends on: the declarations the text
    // names by it, and, for a procedure, whether this notation reads a
    // one-key mapping under it as its own, where a value is wanted or under
    // a statement's `value`.
    public func shadowing(_ name: Name, as space: Space) -> Shadowing {
        let key = name.spelling
        let everything = every(modules)

        return Shadowing(
            declarations: everything.declarations(named: name, in: space),
            isKeyword: space == .procedure
                && (ExpressionSugar.claims(key) || Grammar.claims(key) || StatementSugar.claims(key))
        )
    }

    // MARK: - Private
    // A text's tree with its enums' raw values spent, so every pass after,
    // the declarations collected off it among them, reads the procedures
    // they are written as.
    private func read(_ text: String) throws -> Tree {
        try RawValueForm().spent(try parser.parse(text))
    }

    // Parsed texts, one module, spent into its document's bytes and their
    // `Origin`, its declarations shadowing those each text uses. Each text
    // is spent on its own and the texts are then laid into one document.
    // Declarations that do not read are refused alone. Once they read, a
    // text refused is read again one body at a time, and every refusal of
    // every text is thrown together.
    private func spent(_ texts: [(position: Int?, text: Tree)]) throws -> (document: Data, origin: Origin) {
        let reached = try texts.map { position, text in
            let (used, declarations, claims) = try Self.inText(position) { try reaching(text) }

            return (position: position, text: used, reached: declarations, claims: claims)
        }
        let own = try Self.declaring(reached.map { text in (text.position, text.text, text.reached) })
        var completed: [(position: Int?, text: Tree)] = []
        var refusals: [AuthoringError] = []

        for ((position, text, declarations, _), declared) in zip(reached, own) {
            let table = declared.merging(declarations)

            do {
                completed.append((position, try self.completed(text, reading: table)))
            } catch let refusal as AuthoringError {
                refusals += try recovered(text, reading: table, refusedWith: refusal).map { refusal in
                    position.map { position in AuthoringError(refusal, inText: position) } ?? refusal
                }
            }
        }

        guard refusals.isEmpty else { throw TextRefused(refusals) }

        return try Self.written(try Self.finished(
            completed.map { position, text in position.map(text.inText) ?? text },
            beside: reached.reduce(Declarations()) { table, text in table.merging(text.reached) },
            claiming: reached.reduce(into: []) { claims, text in claims.formUnion(text.claims) }
        ))
    }

    // The refusals of a text refused with `first`, read one procedure body
    // at a time: its declarations' alone, or else one for each body
    // refused. Where no part refuses alone, the text's own.
    private func recovered(
        _ text: Tree,
        reading table: Declarations,
        refusedWith first: AuthoringError
    ) throws -> [AuthoringError] {
        let recovery = try Recovery(of: text)

        if let refusal = try refusal(of: recovery.declarations, reading: table) {
            return [refusal]
        }

        let refusals = try recovery.bodies.compactMap { body in try refusal(of: body, reading: table) }

        return refusals.isEmpty ? [first] : refusals
    }

    // What a text is refused with, and nothing where it is spent.
    private func refusal(of text: Tree, reading table: Declarations) throws -> AuthoringError? {
        do {
            _ = try Self.written(try Self.finished([try completed(text, reading: table)], beside: table, claiming: []))

            return nil
        } catch let refusal as AuthoringError {
            return refusal
        }
    }

    // A completion at `position` of the text at `index` among parsed texts
    // of one module, each by its position among those handed, nil for a text
    // handed alone.
    private func completion(
        at position: Origin.Position,
        inText index: Int,
        of texts: [(position: Int?, text: Tree)]
    ) throws -> Completion {
        let reached = try texts.map { number, text in
            let (used, declarations, _) = try Self.inText(number) { try reaching(text) }

            return (position: number, text: used, reached: declarations)
        }
        let point = try CompletionPoint(in: reached[index].text, inText: reached[index].position, at: position)
        let rewritten = reached.enumerated().map { offset, text in
            (position: text.position, text: offset == index ? point.text : text.text, reached: text.reached)
        }
        let own = try Self.declaring(rewritten)
        let reaching = rewritten.reduce(Declarations()) { table, text in table.merging(text.reached) }

        // Each text completed against what its module declares for it and
        // what it uses, standing in its own text among those handed.
        // Recovering, the procedure holding the position keeps its body and
        // every other body of the module is empty.
        func document(recovering: Bool) throws -> (document: Tree, spellings: [String: String]) {
            try Self.finished(
                try rewritten.enumerated().map { offset, text in
                    let tree = recovering
                        ? try Recovery.text(text.text, holding: offset == index ? point.procedure : nil)
                        : text.text
                    let completed = try Self.inText(text.position) {
                        try self.completed(tree, reading: own[offset].merging(text.reached))
                    }

                    return text.position.map(completed.inText) ?? completed
                },
                beside: reaching,
                claiming: []
            )
        }

        let spent: (document: Tree, spellings: [String: String])

        do {
            spent = try document(recovering: false)
        } catch is AuthoringError {
            spent = try document(recovering: true)
        }

        let written = try Self.written(spent)
        let places = try point.places(in: spent.document)

        return Completion(
            document: written.document,
            origin: written.origin,
            names: Scope(of: spent.document, at: places.written).names,
            receiver: places.receiver
        )
    }

    // `Standard`'s declarations and those of every module, in the order of
    // the modules' names.
    private func every(_ modules: [Name: Declarations]) -> Declarations {
        modules.sorted { first, second in first.key < second.key }.reduce(standard) { table, module in
            table.merging(module.value)
        }
    }

    // A parsed text with its `uses:` spent, the declarations it reads beside
    // its own module's, `Standard`'s and each module's it uses, and the
    // claims those modules make that a document using them imports. A module
    // this front end does not depend on is refused where it is named, with
    // the modules it does.
    private func reaching(
        _ text: Tree
    ) throws -> (text: Tree, reached: Declarations, claims: Set<ImportedClaims.Claim>) {
        let use = try ModuleUse(of: text)
        var reached = standard
        var claimed = claims[Self.standardModule] ?? []

        for (name, node) in use.modules where name != Self.standardModule {
            guard let module = modules[name] else {
                let handed = modules.keys.sorted().map(\.spelling)
                let listed = handed.isEmpty ? "none" : handed.joined(separator: ", ")

                throw AuthoringError("no module '\(name)' is handed to the front end. It is handed \(listed)", at: node)
            }

            reached = reached.merging(module)
            claimed.formUnion(claims[name] ?? [])
        }

        return (use.text, reached, claimed)
    }

    // The texts of one module, each spent, laid into the module's document
    // beside the declarations they reach and finished the one way, importing
    // the names it uses and `claims`, with the spelling each text wrote by
    // the one the document gives a private procedure it renames.
    private static func finished(
        _ texts: [Tree],
        beside reached: Declarations,
        claiming claims: Set<ImportedClaims.Claim>
    ) throws -> (document: Tree, spellings: [String: String]) {
        let module = try ModuleDocument(of: texts, beside: reached)
        let document = try OneWay().written(
            module.document,
            importing: try Imports(of: module.document).names,
            claiming: claims
        )

        return (document, module.spellings)
    }

    // What a parsed text spells, read against `table`, before it is laid
    // into its module's document: the declarations of its module and of
    // what it uses. A name the program uses that none of them declares is
    // refused where it is written.
    private func completed(_ parsed: Tree, reading table: Declarations) throws -> Tree {
        let naming = try Naming(of: parsed, reading: table)
        let annotation = try Annotation(of: try naming.prefixed(parsed), reading: naming)
        let shorthands = try Grammar().rewriting(
            try annotation.defaulted(annotation.document),
            [StatementSugar().rewritten, ExpressionSugar(reading: naming).rewritten]
        )
        let matched = try ArgumentMatching(declarations: table).matched(try naming.resolved(shorthands))
        let completed = try Elaborator(reading: table).completed(matched)

        if let missing = try Imports(of: completed).unfound(by: table) {
            throw AuthoringError(
                unfound(missing.name, isWrittenAsAKey: missing.isSent && missing.at.isImplicit, reading: table),
                at: missing.at
            )
        }

        return completed
    }

    // Why a name the text uses is found nowhere: another text of its module
    // keeps it private, or the modules declaring it that the text does not
    // use, or no module at all. Where no module declares a callee a
    // mapping's key names, the refusal says the mapping is a call and how a
    // dictionary is written.
    private func unfound(_ spelling: String, isWrittenAsAKey: Bool, reading table: Declarations) -> String {
        if let concealment = (try? Name(spelling)).flatMap(table.concealment) {
            return concealment
        }

        let declaring = (try? Name(spelling)).map { name in
            modules.keys.sorted().filter { module in
                guard let declared = modules[module] else { return false }

                return declared.declares(name)
                    || [Space.type, .procedure].contains { space in !declared.declarations(named: name, in: space).isEmpty }
            }
        } ?? []

        let unfound = "no module the text uses declares '\(spelling)'"

        switch declaring.count {
        case 0:
            guard isWrittenAsAKey else { return unfound }

            return "\(unfound). A mapping keyed by a name calls it, and a dictionary is written under `dictionary`"

        case 1:
            return "\(unfound). \(declaring[0].spelling) declares it: write \(declaring[0].spelling) under uses"

        default:
            let listed = declaring.map(\.spelling).joined(separator: ", ")

            return "\(unfound). \(listed) declare it: write one of them under uses"
        }
    }

    // A spent document's bytes, and where the text is for a place in them
    // and what it wrote for a spelling the document gives.
    private static func written(
        _ finished: (document: Tree, spellings: [String: String])
    ) throws -> (document: Data, origin: Origin) {
        (try BinaryWriter().write(finished.document), Origin(finished.document, spellings: finished.spellings))
    }

    // What each of these texts of one module reads its module to declare:
    // its own declarations, and every other text's with each private
    // procedure concealed. Each text's declarations are read alone, against
    // what it reaches, the short name of a type read against the types of
    // every text. A declaration names no body, so no text has to be read
    // before another; two texts sending each other are a cycle the build
    // refuses. A text whose declarations do not read is refused where it
    // writes them, before any call is matched.
    private static func declaring(
        _ texts: [(position: Int?, text: Tree, reached: Declarations)]
    ) throws -> [Declarations] {
        let types = try texts.flatMap { position, text, reached in
            try inText(position) { try Self.types(declaredBy: text, reading: reached) }
        }
        let declared = try texts.map { position, text, reached in
            try inText(position) {
                let collector = DeclarationCollector(reading: reached.adding(types: types))

                return try Declarations().adding(try collector.collected(text))
            }
        }

        return declared.indices.map { offset in
            declared.indices.reduce(declared[offset]) { table, other in
                other == offset ? table : table.merging(declared[other].concealingPrivate())
            }
        }
    }

    // A module's name, which is an identifier, and is not `Standard`'s,
    // which every text uses.
    private static func check(_ module: Name) throws(AuthoringError) {
        guard module.isIdentifier else { throw AuthoringError("a module is named by an identifier") }

        guard module != standardModule else {
            throw AuthoringError("'Standard' is the language's module, which every text uses")
        }
    }

    // The full names of the types and contracts a parsed text declares. A
    // key that is no name is the load's to refuse, and is left out here.
    private static func types(declaredBy parsed: Tree, reading held: Declarations) throws -> [Name] {
        let prefixed = try Naming(of: parsed, reading: held).prefixed(parsed)

        return ["types", "contracts"].flatMap { table in
            (prefixed[table]?.dictionaryValue?.keys).map { keys in keys.compactMap { key in try? Name(key) } } ?? []
        }
    }

    // What `spend` makes, the Front's one refusal thrown as the texts'.
    private static func refusing<Spent>(_ spend: () throws -> Spent) throws -> Spent {
        do {
            return try spend()
        } catch let refusal as AuthoringError {
            throw TextRefused([refusal])
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
