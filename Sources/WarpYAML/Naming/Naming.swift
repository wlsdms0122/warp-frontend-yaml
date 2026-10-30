//
//  Naming.swift
//  WarpYAML
//
//  Created by JSilver on 9/2/26.
//

import Foundation

// The `name:` a text may write, and what it does to the document.
//
// A document has no name key: a declaration is named by its key, dots
// included. What this notation reads under that key is a prefix. A text
// writing `name: Bank` declares `Bank.transfer` where it wrote `transfer`
// under `types`, `contracts` and `procedures`, and the key is
// spent here.
//
// A key takes the prefix where it is bare, or dotted with one of the text's
// bare types first (`Fetch.parse`), and an extension's key where the type
// extended takes it. What the text mentions is read full where it names one
// of those keys: a `call` to `transfer` reaches `Bank.transfer`, and `Account`
// in a type reads as `Bank.Account`. A member of one of the text's types,
// written in the type or in an extension, and a procedure of one of its
// contracts, is one of its procedures, so `Account.describe` reaches
// `Bank.Account.describe`.
// Any other name is a declaration of a document the text leans on, where
// its declarations hold one of that name, or is left as written.
struct Naming: Sendable {
    // MARK: - Property
    static let key = "name"

    private static let typeTables = ["types", "contracts"]
    private static let procedureTable = "procedures"
    private static let extensionTable = "extensions"

    // The tables whose keys are the text's own names. A constant is read by
    // its bare name inside its own module, so it takes no prefix.
    private static let tables = typeTables + [procedureTable, extensionTable]

    let prefix: Name?

    // The keys that are the text's own, by table, as the text wrote them.
    // `prefixed` puts the prefix on these, and `declared` reads a mention
    // full by them.
    private let ownKeys: [String: Set<Name>]

    // What the text leans on, read after its own keys.
    private let declarations: Declarations

    // A text that writes no name.
    static let none = Naming(prefix: nil, ownKeys: [:], declarations: Declarations())

    // MARK: - Initializer
    // A text's tree. A `name` that is not identifiers joined by dots is
    // refused at its key, since the prefix stands in front of a dot in every
    // name it is put on. What each prefixed name may be is the load's.
    init(of document: Tree, leaningOn declarations: Declarations) throws {
        let outline = Self.outline(of: document)
        let ownKeys = Self.ownKeys(in: outline)
        var prefix: Name?

        if let written = document[Self.key] {
            guard
                let spelling = written.stringValue,
                let name = try? Name(spelling),
                Self.joinsIdentifiers(name)
            else {
                throw AuthoringError(
                    "a name is identifiers joined by dots, and this notation spends it as a prefix on what the"
                        + " text declares",
                    at: written
                )
            }

            prefix = name
        }

        self.init(prefix: prefix, ownKeys: ownKeys, declarations: declarations)
    }

    private init(prefix: Name?, ownKeys: [String: Set<Name>], declarations: Declarations) {
        self.prefix = prefix
        self.ownKeys = ownKeys
        self.declarations = declarations
    }

    // MARK: - Public
    // The text's tree with the prefix put on its own keys and the name key
    // gone. Two keys that read as one name are one declaration written
    // twice, refused at the second.
    func prefixed(_ document: Tree) throws -> Tree {
        guard let prefix, var entries = document.dictionaryValue else { return document }

        entries[Self.key] = nil

        for table in Self.tables {
            guard let declared = entries[table]?.dictionaryValue else { continue }

            let own = ownKeys[table] ?? []
            var written: [String: Tree] = [:]

            for (key, declaration) in Self.ordered(declared) {
                let full = (try? Name(key)).flatMap { name in own.contains(name) ? "\(prefix).\(key)" : nil } ?? key

                guard written[full] == nil else {
                    throw AuthoringError(
                        "'\(full)' is written twice under \(table), once short and once full",
                        at: declaration
                    )
                }

                written[full] = declaration
            }

            entries[table] = entries[table]?.holding(.dictionary(written))
        }

        return document.holding(.dictionary(entries))
    }

    // What a name the text writes in that space is called in full. One of
    // the text's own keys there is the prefixed name, or the name as written
    // where the text wrote no name, as a declaration shadows what it leans
    // on. Any other name is the declaration of what the text leans on that
    // the name stands for, which two refuse, and nothing where none does.
    func declared(_ name: Name, in space: Space) throws(AuthoringError) -> Name? {
        let tables = space == .type ? Self.typeTables : [Self.procedureTable]

        guard tables.contains(where: { table in ownKeys[table]?.contains(name) == true }) else {
            return try declarations.qualified(name, in: space)
        }

        guard let prefix else { return name }

        return try? Name("\(prefix).\(name)")
    }

    // A type with each name of a type in it written in full, by this
    // reading of the text's names. `Self` and what is named through it are
    // the conforming type's, and a name the reading does not know stands as
    // written.
    func qualified(_ type: TypeSpelling) throws(AuthoringError) -> TypeSpelling {
        try type.mapTypeNames { name throws(AuthoringError) in
            guard name != "Self", !name.hasPrefix("Self."), let written = try? Name(name) else { return name }

            return try declared(written, in: .type)?.spelling ?? name
        }
    }

    // A document with each name its callees, types, contracts, bounds and
    // extension heads write resolved by this reading: a short name written
    // in full, and a full name kept. A spelling that does not read, and a
    // name the reading does not know, stand as written. Two declarations of
    // one short name are refused where it is written.
    func resolved(_ document: Tree) throws -> Tree {
        try Grammar().rewriting(document) { node, kind in
            guard kind != .document else { return try extensionsResolved(node) }

            do throws(AuthoringError) {
                switch kind {
                case .callee:
                    return try resolved(node, in: .procedure)

                case .contract:
                    return try resolved(node, in: .type)

                case .type, .bound:
                    guard let written = node.stringValue, let spelling = try typeResolved(written) else { return node }

                    return node.holding(.string(spelling))

                // A name, then its bound after the colon.
                case .typeParameter:
                    guard
                        let written = node.stringValue,
                        let colon = written.firstIndex(of: ":"),
                        let bound = try typeResolved(written[written.index(after: colon)...].trimmingCharacters(in: .whitespaces))
                    else {
                        return node
                    }

                    return node.holding(.string("\(written[..<colon]): \(bound)"))

                case .document, .procedure, .closure, .parameter, .body, .statement, .expression, .path:
                    return node
                }
            } catch {
                throw AuthoringError(error, at: node)
            }
        }
    }

    // MARK: - Private
    // A name written in that space as this reading resolves it.
    private func resolved(_ node: Tree, in space: Space) throws(AuthoringError) -> Tree {
        guard
            let written = node.stringValue,
            let name = try? Name(written),
            let full = try declared(name, in: space),
            full.spelling != written
        else {
            return node
        }

        return node.holding(.string(full.spelling))
    }

    // A type's spelling written again with each name in it resolved, and
    // nothing where it does not read or no name in it changes.
    private func typeResolved(_ written: String) throws(AuthoringError) -> String? {
        guard let type = try? TypeSpelling(written) else { return nil }

        let resolved = try qualified(type)

        return resolved == type ? nil : resolved.spelling
    }

    // The document's extension heads, each with its names resolved. Two
    // heads that resolve to one are one extension written twice, refused
    // at the second.
    private func extensionsResolved(_ document: Tree) throws -> Tree {
        guard var entries = document.dictionaryValue, let extensions = entries["extensions"]?.dictionaryValue else {
            return document
        }

        var written: [String: Tree] = [:]

        for (head, declaration) in Self.ordered(extensions) {
            let resolved: String

            do {
                resolved = try typeResolved(head) ?? head
            } catch {
                throw AuthoringError(error, at: declaration)
            }

            guard written[resolved] == nil else {
                throw AuthoringError("'\(resolved)' is written twice under extensions, once short and once full", at: declaration)
            }

            written[resolved] = declaration
        }

        entries["extensions"] = entries["extensions"]?.holding(.dictionary(written))

        return document.holding(.dictionary(entries))
    }

    // A table's entries in the order the text writes them.
    private static func ordered(_ entries: [String: Tree]) -> [(key: String, value: Tree)] {
        entries.sorted { lhs, rhs in
            let left = lhs.value.position.map { position in [position.line, position.column] } ?? []
            let right = rhs.value.position.map { position in [position.line, position.column] } ?? []

            return left == right ? lhs.key < rhs.key : left.lexicographicallyPrecedes(right)
        }
    }

    // The keys a text's tree writes under each table of declarations, an
    // extension's by the type its head extends, and under each, the keys of
    // what it declares under `procedures`, the members of every head
    // extending one type together. A key that is no name, and a head that
    // extends none, is the load's to refuse, and is left out here.
    private static func outline(of document: Tree) -> [String: [Name: [Name]]] {
        tables.reduce(into: [:]) { outline, table in
            guard let declared = document[table]?.dictionaryValue else { return }

            outline[table] = declared.reduce(into: [:]) { keys, entry in
                let written = table == extensionTable
                    ? (try? TypeSpelling(entry.key))?.extendedType
                    : entry.key

                guard let key = written.flatMap({ written in try? Name(written) }) else { return }

                let members = entry.value["procedures"]?.dictionaryValue.map { procedures in Array(procedures.keys) }

                keys[key, default: []] += (members ?? []).compactMap { member in try? Name(member) }
            }
        }
    }

    // The text's own keys under each table, read off its outline: a bare
    // key, a dotted key whose first identifier is one of the text's bare
    // types, and under `extensions` one of the text's own types a head
    // extends. A member a type of the text's own is given, in the type or in
    // an extension, and a procedure of one of its contracts, is one of its
    // procedures, under the owner's key and the procedure's.
    private static func ownKeys(in outline: [String: [Name: [Name]]]) -> [String: Set<Name>] {
        let keys = { (table: String) in outline[table].map { declared in Array(declared.keys) } ?? [] }
        let bareTypes = Set(typeTables.flatMap(keys).filter { name in name.isIdentifier })

        var ownKeys: [String: Set<Name>] = [:]

        for table in typeTables + [procedureTable] {
            ownKeys[table] = Set(
                keys(table).filter { name in name.isIdentifier || bareTypes.contains(head(of: name)) }
            )
        }

        let ownTypes = typeTables.reduce(into: Set<Name>()) { types, table in types.formUnion(ownKeys[table] ?? []) }

        ownKeys[extensionTable] = Set(keys(extensionTable).filter { name in ownTypes.contains(name) })

        for table in typeTables + [extensionTable] {
            for (owner, members) in outline[table] ?? [:] where ownTypes.contains(owner) {
                for member in members {
                    if let spelling = try? Name("\(owner).\(member)") {
                        ownKeys[procedureTable, default: []].insert(spelling)
                    }
                }
            }
        }

        return ownKeys
    }

    // Whether a name is identifiers joined by dots, each segment one.
    private static func joinsIdentifiers(_ name: Name) -> Bool {
        name.spelling.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { segment in
            (try? Name(String(segment)))?.isIdentifier == true
        }
    }

    // The first identifier of a dotted name: `Fetch` of `Fetch.parse`, and
    // the name itself where it has no dot.
    private static func head(of name: Name) -> Name {
        guard
            let dot = name.spelling.firstIndex(of: "."),
            let head = try? Name(String(name.spelling[..<dot]))
        else { return name }

        return head
    }
}
