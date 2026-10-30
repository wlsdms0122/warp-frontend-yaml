//
//  Imports.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a document's program uses and does not declare, by `DOCUMENT.md`'s
// imports list: the procedures it sends, and the types and contracts it
// names in a declaration, a bound, a local binding, a cast, a closure's
// signature, an extension or what a type satisfies. A name the language
// declares, `Self` and a type `Self` names are none of them. What a type
// may fail with names no type a link resolves. Which claims of other
// documents a document stands on is its build's, so the list holds none.
struct Imports {
    // MARK: - Property
    // The names the language declares, which no document declares.
    private static let language: Set<String> = [
        "Any", "Never", "Null", "Bool", "Int", "Double", "String", "Array", "Dictionary", "Optional", "Procedure",
        "Hashable", "Failure", "Round", "Some"
    ]
    private static let selfType = "Self"

    // The names, in name order.
    let names: [String]

    // MARK: - Initializer
    // The imports of a document as the passes before finished it, every
    // name in it written in full.
    init(of document: Tree) throws {
        var sends: Set<String> = []
        var mentions: Set<String> = []
        var procedures: Set<String> = []

        _ = try Grammar().rewriting(document) { node, kind in
            switch kind {
            case .document:
                for head in Self.keys(of: node["extensions"]) {
                    mentions.formUnion(Self.names(in: head))
                }

            case let .procedure(owner, key):
                if let name = owner.name(of: key) {
                    procedures.insert(name)
                }

            case .callee:
                if let callee = node.stringValue {
                    sends.insert(callee)
                }

            case .type, .bound:
                if let type = node.stringValue {
                    mentions.formUnion(Self.names(in: type))
                }

            case .contract:
                if let contract = node.stringValue {
                    mentions.insert(contract)
                }

            case .typeParameter:
                if let written = node.stringValue, let colon = written.firstIndex(of: ":") {
                    mentions.formUnion(
                        Self.names(in: written[written.index(after: colon)...].trimmingCharacters(in: .whitespaces))
                    )
                }

            case .closure, .parameter, .body, .statement, .expression, .path:
                break
            }

            return node
        }

        let types = Self.keys(of: document["types"]).union(Self.keys(of: document["contracts"]))
        let used = sends.subtracting(procedures)
            .union(mentions.subtracting(types).filter { name in !Self.isDeclaredByTheLanguage(name) })

        self.names = OneWay.inNameOrder(Array(used))
    }

    // MARK: - Public
    // MARK: - Private
    // The names of types and contracts a type spelling writes, and none for
    // one that does not read, which the load refuses.
    private static func names(in spelling: String) -> Set<String> {
        var names: Set<String> = []

        _ = try? TypeSpelling(spelling).mapTypeNames { name in
            names.insert(name)

            return name
        }

        return names
    }

    // The keys of a table, and none where it is no dictionary.
    private static func keys(of table: Tree?) -> Set<String> {
        Set(table?.dictionaryValue?.keys.map { key in key } ?? [])
    }

    // Whether the language declares the name, or `Self` stands for it.
    private static func isDeclaredByTheLanguage(_ name: String) -> Bool {
        language.contains(name) || name == selfType || name.hasPrefix("\(selfType).")
    }
}
