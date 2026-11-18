//
//  Imports.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a document's program uses and does not declare, by WARP-10's
// imports list: the procedures it sends, and the types, contracts and type
// members' spellings it names in a declaration, a bound, a local binding, a
// cast, a closure's signature, an extension or what a type satisfies. A type
// member after an applied type, `App.Wrapper<String>.Item`, names the type
// and the type member's spelling, `App.Wrapper` and `App.Wrapper.Item`. A
// document declares the spelling of each type member it gives, in a type's
// declaration or in an extension. A name the language declares, `Self` and
// a type `Self` names are none of them. What a type may fail with names no
// type a link resolves. Which claims of other documents a document stands
// on is its build's, so the list holds none.
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

    // The node each name is first written at, and whether it is a callee
    // there.
    private let written: [String: (at: Tree, isSent: Bool)]

    // MARK: - Initializer
    // The imports of a document as the passes before finished it, every
    // name in it written in full.
    init(of document: Tree) throws {
        var sends: [String: Tree] = [:]
        var mentions: [String: Tree] = [:]
        var procedures: Set<String> = []

        _ = try Grammar().rewriting(document) { node, kind in
            switch kind {
            case .document:
                for (head, declaration) in node["extensions"]?.dictionaryValue ?? [:] {
                    Self.note(Self.names(in: head), at: declaration, in: &mentions)
                }

            case let .procedure(owner, key):
                if let name = owner.name(of: key) {
                    procedures.insert(name)
                }

            case .callee:
                if let callee = node.stringValue {
                    Self.note([callee], at: node, in: &sends)
                }

            case .type, .bound:
                if let type = node.stringValue {
                    Self.note(Self.names(in: type), at: node, in: &mentions)
                }

            case .contract:
                if let contract = node.stringValue {
                    Self.note([contract], at: node, in: &mentions)
                }

            case .typeParameter:
                if let written = node.stringValue, let colon = written.firstIndex(of: ":") {
                    Self.note(
                        Self.names(in: written[written.index(after: colon)...].trimmingCharacters(in: .whitespaces)),
                        at: node,
                        in: &mentions
                    )
                }

            case .closure, .parameter, .arms, .body, .statement, .expression, .path:
                break
            }

            return node
        }

        let types = Self.keys(of: document["types"])
            .union(Self.keys(of: document["contracts"]))
            .union(Self.typeMembers(givenIn: document))
        let used = sends.filter { name, _ in !procedures.contains(name) }
            .mapValues { node in (at: node, isSent: true) }
            .merging(
                mentions.filter { name, _ in !types.contains(name) && !Self.isDeclaredByTheLanguage(name) }
                    .mapValues { node in (at: node, isSent: false) }
            ) { send, mention in Self.precedes(mention.at, send.at) ? mention : send }

        self.names = OneWay.inNameOrder(Array(used.keys))
        self.written = used
    }

    // MARK: - Public
    // The name written first that none of these declarations has, with
    // the node it is written at and whether it is a callee there, and
    // nothing where each is. A spelling that is no name is the load's.
    func unfound(by declarations: Declarations) -> (name: String, at: Tree, isSent: Bool)? {
        first { spelling in (try? Name(spelling)).map { name in !declarations.declares(name) } ?? false }
    }

    // The name written first of those `picked` takes, with the node it is
    // written at and whether it is a callee there, and nothing where it
    // takes none.
    func first(where picked: (String) -> Bool) -> (name: String, at: Tree, isSent: Bool)? {
        names
            .filter(picked)
            .compactMap { name in written[name].map { noted in (name: name, at: noted.at, isSent: noted.isSent) } }
            .min { first, second in
                Self.precedes(first.at, second.at) || (!Self.precedes(second.at, first.at) && first.name < second.name)
            }
    }

    // MARK: - Private
    // The names of types and contracts a type spelling writes and the
    // spellings of the type members it names after an applied type, and none
    // for one that does not read, which the load refuses.
    private static func names(in spelling: String) -> Set<String> {
        guard let type = try? TypeSpelling(spelling) else { return [] }

        var names = type.typeMemberSpellings

        _ = type.mapTypeNames { name in
            names.insert(name)

            return name
        }

        return names
    }

    // The spelling of each type member the document gives, under its type's
    // declaration or an extension's head. A head that extends no type gives
    // none.
    private static func typeMembers(givenIn document: Tree) -> Set<String> {
        var owners: [(type: String, given: Tree)] = (document["types"]?.dictionaryValue ?? [:]).map { type, declaration in
            (type, declaration)
        }

        for (head, given) in document["extensions"]?.dictionaryValue ?? [:] {
            guard let type = (try? TypeSpelling(head))?.extendedType else { continue }

            owners.append((type, given))
        }

        return owners.reduce(into: []) { spellings, owner in
            for member in keys(of: owner.given["types"]) {
                spellings.insert("\(owner.type).\(member)")
            }
        }
    }

    // Each name at this node, where no node the text writes before it is
    // noted for it.
    private static func note(_ names: some Sequence<String>, at node: Tree, in noted: inout [String: Tree]) {
        for name in names where noted[name].map({ written in precedes(node, written) }) ?? true {
            noted[name] = node
        }
    }

    // Whether the text writes one node before another, a node with no
    // position first.
    private static func precedes(_ node: Tree, _ other: Tree) -> Bool {
        let left = node.position.map { position in [position.line, position.column] } ?? []
        let right = other.position.map { position in [position.line, position.column] } ?? []

        return left.lexicographicallyPrecedes(right)
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
