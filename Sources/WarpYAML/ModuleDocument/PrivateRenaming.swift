//
//  PrivateRenaming.swift
//  WarpYAML
//
//  Created by JSilver on 11/4/26.
//

import Foundation

// The texts of one module, each with its private procedures given spellings
// the module's document holds apart. A text's private procedure is its own:
// the text names it and no other text does. Where another text of the
// module declares or names its spelling, the module's one document could
// not hold both, so the procedure is given a spelling nothing the module
// declares, names or reaches has, its full name followed by `_` and the
// first number that makes it so, and every call the text writes to it is
// written under that spelling. A private procedure no other text declares
// or names keeps the spelling the text wrote. A contract's procedure is
// what the contract asks, and is never given another spelling.
struct PrivateRenaming {
    // MARK: - Property
    private static let proceduresKey = "procedures"
    private static let typesKey = "types"
    private static let contractsKey = "contracts"
    private static let extensionsKey = "extensions"
    private static let typeTables = [typesKey, contractsKey]

    // The texts, in the order handed, each written with the spellings given.
    let texts: [Tree]

    // The spelling the text wrote, by the spelling each renamed procedure is
    // given.
    let spellings: [String: String]

    // MARK: - Initializer
    // Texts written in full, every name a full name, and the declarations
    // they reach beside the module's own.
    init(of texts: [Tree], beside reached: Declarations) throws {
        let declared = texts.map(Self.procedures(declaredBy:))
        let named = try texts.map { text in Set(try Imports(of: text).names) }
        var taken = texts.reduce(into: Set<String>()) { names, text in names.formUnion(Self.types(declaredBy: text)) }
            .union(declared.flatMap(\.keys))
            .union(named.flatMap { names in names })
        var renamed: [[String: String]] = Array(repeating: [:], count: texts.count)
        var spellings: [String: String] = [:]

        for (offset, procedures) in declared.enumerated() {
            for (spelling, isPrivate) in procedures.sorted(by: { first, second in first.key < second.key }) {
                guard
                    isPrivate,
                    texts.indices.contains(where: { other in
                        other != offset && (declared[other][spelling] != nil || named[other].contains(spelling))
                    })
                else {
                    continue
                }

                let given = Self.given(for: spelling) { candidate in
                    taken.contains(candidate) || (try? Name(candidate)).map(reached.declares) == true
                }

                taken.insert(given)
                renamed[offset][spelling] = given
                spellings[given] = spelling
            }
        }

        self.texts = try zip(texts, renamed).map { text, renamed in
            renamed.isEmpty ? text : try Self.renaming(text, by: renamed)
        }
        self.spellings = spellings
    }

    // MARK: - Public
    // MARK: - Private
    // The first spelling `taken` does not take: the full name followed by
    // `_` and a number, counted from one.
    private static func given(for spelling: String, unless taken: (String) -> Bool) -> String {
        var number = 1

        while taken("\(spelling)_\(number)") {
            number += 1
        }

        return "\(spelling)_\(number)"
    }

    // The text with each procedure `renamed` names declared and called
    // under the spelling it is given.
    private static func renaming(_ text: Tree, by renamed: [String: String]) throws -> Tree {
        try Grammar().rewriting(text) { node, kind in
            switch kind {
            case .document:
                return declaring(node) { owner, table in keyed(table, owner: owner, by: renamed) }

            case .callee:
                guard let callee = node.stringValue, let given = renamed[callee] else { return node }

                return node.holding(.string(given))

            case .procedure, .closure, .parameter, .type, .contract, .bound, .typeParameter, .arms, .body, .statement,
                .expression, .path:
                return node
            }
        }
    }

    // The document with each table that declares procedures rewritten by
    // `rewrite`, with what the table declares them under: the document's
    // procedures, and the members a type's declaration or an extension
    // gives. A contract's procedures are what it asks, and no such table.
    private static func declaring(_ document: Tree, _ rewrite: (Grammar.Owner, Tree) -> Tree) -> Tree {
        guard var entries = document.dictionaryValue else { return document }

        entries[proceduresKey] = entries[proceduresKey].map { table in rewrite(.document, table) }

        for (key, owner) in [(typesKey, Grammar.Owner.type), (extensionsKey, Grammar.Owner.extension)] {
            guard let declarations = entries[key], var owners = declarations.dictionaryValue else { continue }

            for (name, declaration) in owners {
                guard var given = declaration.dictionaryValue, let procedures = given[proceduresKey] else { continue }

                given[proceduresKey] = rewrite(owner(name), procedures)
                owners[name] = declaration.holding(.dictionary(given))
            }

            entries[key] = declarations.holding(.dictionary(owners))
        }

        return document.holding(.dictionary(entries))
    }

    // A table of procedures with each key whose full name `renamed` names
    // written for the spelling it is given, which is the full name followed
    // by what it is given after it.
    private static func keyed(_ table: Tree, owner: Grammar.Owner, by renamed: [String: String]) -> Tree {
        guard let procedures = table.dictionaryValue else { return table }

        let keyed = procedures.reduce(into: [String: Tree]()) { keyed, entry in
            guard let name = owner.name(of: entry.key), let given = renamed[name] else {
                keyed[entry.key] = entry.value

                return
            }

            keyed[entry.key + given.dropFirst(name.count)] = entry.value
        }

        return table.holding(.dictionary(keyed))
    }

    // The full name of each procedure a text declares, and whether it is
    // private: each one a table `declaring(_:_:)` rewrites declares, read
    // as its signature reads, and a contract's, which is never private.
    private static func procedures(declaredBy text: Tree) -> [String: Bool] {
        var procedures: [String: Bool] = [:]

        _ = declaring(text) { owner, table in
            for (key, procedure) in table.dictionaryValue ?? [:] {
                guard let name = owner.name(of: key) else { continue }

                procedures[name] = (try? ProcedureSignature(procedure))?.access == .private
            }

            return table
        }

        for (contract, declaration) in text[contractsKey]?.dictionaryValue ?? [:] {
            for key in declaration[proceduresKey]?.dictionaryValue?.keys.sorted() ?? [] {
                procedures[Grammar.Owner.contract(contract).name(of: key) ?? key] = false
            }
        }

        return procedures
    }

    // The full names of the types and contracts a text declares, and the
    // spellings of the type members a type's declaration or an extension
    // gives.
    private static func types(declaredBy text: Tree) -> Set<String> {
        var names: Set<String> = []
        var owners: [(type: String, given: Tree)] = []

        for table in typeTables {
            for (type, declaration) in text[table]?.dictionaryValue ?? [:] {
                names.insert(type)
                owners.append((type, declaration))
            }
        }

        for (head, extended) in text[extensionsKey]?.dictionaryValue ?? [:] {
            guard let type = (try? TypeSpelling(head))?.extendedType else { continue }

            owners.append((type, extended))
        }

        for (type, given) in owners {
            for member in given[typesKey]?.dictionaryValue?.keys.sorted() ?? [] {
                names.insert("\(type).\(member)")
            }
        }

        return names
    }
}
