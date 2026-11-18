//
//  ModuleDocument.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// The texts of one module, each spent on its own, written as the module's one
// document. Each text's private procedures are given spellings the document
// holds apart, under `PrivateRenaming`. What each text declares is then
// laid into one tree: a name two texts declare is refused where the later
// one declares it, and two texts extending one head give it what each
// gives. A node holding what several texts wrote stands where the first of
// them wrote it. A struct or an enum the module declares is given in its
// declaration what an extension of the type gives every value of it, since
// that is where a document writes it.
struct ModuleDocument {
    // MARK: - Property
    private static let tables = ["types", "contracts", "procedures", "const", "var"]
    private static let extensionsKey = "extensions"
    private static let typesKey = "types"
    private static let satisfiesKey = "satisfies"

    // What an extension and a type's declaration give a type under a name.
    private static let given = ["procedures", "types"]

    // What a type's declaration writes where every value of the type has
    // what is given to it.
    private static let nominal = ["struct", "enum"]

    // The module's document, before it is finished the one way.
    let document: Tree

    // The spelling a text wrote, by the spelling the document gives each
    // private procedure it renames.
    let spellings: [String: String]

    // MARK: - Initializer
    // Texts written in full, and the declarations they reach beside the
    // module's own.
    init(of texts: [Tree], beside reached: Declarations) throws {
        let renaming = try PrivateRenaming(of: texts, beside: reached)

        self.document = try Self.folded(
            renaming.texts.count == 1 ? renaming.texts[0] : try Self.gathered(renaming.texts)
        )
        self.spellings = renaming.spellings
    }

    // MARK: - Public
    // MARK: - Private
    // The texts' keys laid into one tree, in the order the texts are handed.
    // A key that is no table is written once, or the same by every text
    // writing it.
    private static func gathered(_ texts: [Tree]) throws(AuthoringError) -> Tree {
        var entries: [String: Tree] = [:]

        for text in texts {
            guard let written = text.dictionaryValue else {
                throw AuthoringError("a text is a mapping of what it declares", at: text)
            }

            for (key, value) in written.sorted(by: { first, second in first.key < second.key }) {
                guard let first = entries[key] else {
                    entries[key] = value

                    continue
                }

                if tables.contains(key) {
                    entries[key] = try declared(first, value, under: key, by: declaredOnce)
                } else if key == extensionsKey {
                    entries[key] = try declared(first, value, under: key, by: extended)
                } else if first != value {
                    throw AuthoringError("'\(key)' is written apart by two texts of one module", at: value)
                }
            }
        }

        return texts[0].holding(.dictionary(entries))
    }

    // Two tables of declarations as one, the declarations under one name
    // laid together by `join`.
    private static func declared(
        _ first: Tree,
        _ second: Tree,
        under key: String,
        by join: (String, Tree, Tree) throws(AuthoringError) -> Tree
    ) throws(AuthoringError) -> Tree {
        guard var table = first.dictionaryValue, let added = second.dictionaryValue else {
            throw AuthoringError("'\(key)' is written apart by two texts of one module", at: second)
        }

        for (name, declaration) in added.sorted(by: { first, second in first.key < second.key }) {
            table[name] = try table[name].map { held throws(AuthoringError) in try join(name, held, declaration) }
                ?? declaration
        }

        return first.holding(.dictionary(table))
    }

    // A name declared once, refused where it is declared again.
    private static func declaredOnce(_ name: String, _ first: Tree, _ second: Tree) throws(AuthoringError) -> Tree {
        let earlier = first.text.map { text in ", first in text \(text)" } ?? ""

        throw AuthoringError("'\(name)' is declared twice in one module\(earlier)", at: second)
    }

    // Two extensions of one head as one, giving it what each gives.
    private static func extended(_ head: String, _ first: Tree, _ second: Tree) throws(AuthoringError) -> Tree {
        guard let held = first.dictionaryValue, let added = second.dictionaryValue else {
            throw AuthoringError("'\(head)' is extended apart by two texts of one module", at: second)
        }

        return first.holding(.dictionary(try giving(added, to: held)))
    }

    // What `added` gives a type laid beside what `held` gives it: the
    // contracts it satisfies listed together, and its members, each declared
    // once. Anything else is written once, or the same by both.
    private static func giving(_ added: [String: Tree], to held: [String: Tree]) throws(AuthoringError) -> [String: Tree] {
        var given = held

        for (key, value) in added.sorted(by: { first, second in first.key < second.key }) {
            guard let first = given[key] else {
                given[key] = value

                continue
            }

            if key == satisfiesKey, let listed = first.arrayValue, let more = value.arrayValue {
                given[key] = first.holding(.array(listed + more))
            } else if Self.given.contains(key) {
                given[key] = try declared(first, value, under: key, by: declaredOnce)
            } else if first != value {
                throw AuthoringError("'\(key)' is written apart by two declarations of one type", at: value)
            }
        }

        return given
    }

    // The document with each extension of a struct or an enum it declares,
    // written by the type's name alone, given in the type's declaration. An
    // extension writing anything but what a declaration gives stays, for the
    // load to read.
    private static func folded(_ document: Tree) throws(AuthoringError) -> Tree {
        guard
            var entries = document.dictionaryValue,
            var types = entries[typesKey]?.dictionaryValue,
            var extensions = entries[extensionsKey]?.dictionaryValue
        else {
            return document
        }

        for (head, extended) in extensions.sorted(by: { first, second in first.key < second.key }) {
            guard
                let declaration = types[head],
                let declared = declaration.dictionaryValue,
                nominal.contains(where: { key in declared[key] != nil }),
                let gives = extended.dictionaryValue,
                gives.keys.allSatisfy({ key in key == satisfiesKey || given.contains(key) })
            else {
                continue
            }

            types[head] = declaration.holding(.dictionary(try giving(gives, to: declared)))
            extensions[head] = nil
        }

        entries[typesKey] = entries[typesKey]?.holding(.dictionary(types))
        entries[extensionsKey] = extensions.isEmpty ? nil : entries[extensionsKey]?.holding(.dictionary(extensions))

        return document.holding(.dictionary(entries))
    }
}
