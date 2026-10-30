//
//  OneWay.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The last pass: a document says each thing one way (`DOCUMENT.md`), where
// the passes before it can write a thing another way. A parameter of any
// type writes no type, so `Any` written out is left out, and `satisfies`,
// `failing` and a contract's `types` stand in name order, names compared by
// their bytes, since a short name written in full can sort elsewhere. Then
// the document says its version, and its imports where the text writes
// none. Every other absence and order the text writes stands, for the load
// to judge. An imports list writing claims and no name has the names filled
// in beside its claims.
struct OneWay {
    // MARK: - Property
    static let version = 1

    private static let versionKey = "warp"
    private static let importsKey = "imports"
    private static let typeKey = "type"
    private static let failingKey = "failing"
    private static let satisfiesKey = "satisfies"
    private static let typesKey = "types"
    private static let any = "Any"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // The document as its spend finished it.
    func written(_ document: Tree) throws -> Tree {
        let ruled = try Grammar().rewriting(document) { node, kind in
            switch kind {
            case .document:
                Self.declarationsInNameOrder(node)

            case .procedure, .closure:
                Self.inNameOrder(node, under: Self.failingKey)

            case .parameter:
                Self.anyLeftOut(node)

            case .type, .contract, .bound, .typeParameter, .body, .statement, .expression, .path, .callee:
                node
            }
        }

        guard var entries = ruled.dictionaryValue else { return ruled }

        if entries[Self.versionKey] == nil {
            entries[Self.versionKey] = ruled.making(.int(Self.version))
        }

        let claims = Self.claims(writtenBy: entries[Self.importsKey])

        if entries[Self.importsKey] == nil || !claims.isEmpty {
            let names = try Imports(of: ruled).names.map { name in ruled.making(.string(name)) }
            let imports = (names + claims).sorted { first, second in
                Self.precedes(first.stringValue ?? "", second.stringValue ?? "")
            }

            entries[Self.importsKey] = entries[Self.importsKey]?.holding(.array(imports))
                ?? ruled.making(.array(imports))
        }

        return ruled.holding(.dictionary(entries))
    }

    // Names in name order by their bytes, each read up to a `:` written
    // beside it, `"Item: Hashable"` as `Item`.
    static func inNameOrder(_ names: [String]) -> [String] {
        names.sorted(by: precedes)
    }

    // MARK: - Private
    // The claims an imports list writes where it writes claims and no name,
    // which says the names are the program's to fill in beside them, and
    // none for any other list.
    private static func claims(writtenBy imports: Tree?) -> [Tree] {
        guard let listed = imports?.arrayValue, !listed.isEmpty else { return [] }

        let isClaim = listed.allSatisfy { element in element.stringValue?.contains(":") == true }

        return isClaim ? listed : []
    }

    // A parameter written `{ name, type: Any }` as `{ name }`.
    private static func anyLeftOut(_ parameter: Tree) -> Tree {
        guard var fields = parameter.dictionaryValue, fields[typeKey]?.stringValue == any else { return parameter }

        fields[typeKey] = nil

        return parameter.holding(.dictionary(fields))
    }

    // The document with what each type and extension satisfies and each
    // contract's types in name order.
    private static func declarationsInNameOrder(_ document: Tree) -> Tree {
        guard var entries = document.dictionaryValue else { return document }

        for (table, key) in [(typesKey, satisfiesKey), ("extensions", satisfiesKey), ("contracts", typesKey)] {
            guard let declarations = entries[table], let held = declarations.dictionaryValue else { continue }

            entries[table] = declarations.holding(.dictionary(held.mapValues { declaration in
                inNameOrder(declaration, under: key)
            }))
        }

        return document.holding(.dictionary(entries))
    }

    // The node with the list of names under `key` in name order. A list
    // holding anything but strings is left for the load.
    private static func inNameOrder(_ node: Tree, under key: String) -> Tree {
        guard
            var fields = node.dictionaryValue,
            let list = fields[key],
            let written = list.arrayValue
        else {
            return node
        }

        guard written.allSatisfy({ element in element.stringValue != nil }) else { return node }

        fields[key] = list.holding(.array(written.sorted { first, second in
            precedes(first.stringValue ?? "", second.stringValue ?? "")
        }))

        return node.holding(.dictionary(fields))
    }

    private static func precedes(_ first: String, _ second: String) -> Bool {
        name(of: first).utf8.lexicographicallyPrecedes(name(of: second).utf8)
    }

    // A name read up to a `:` written beside it.
    private static func name(of written: String) -> String {
        guard let colon = written.firstIndex(of: ":") else { return written }

        return written[..<colon].trimmingCharacters(in: .whitespaces)
    }
}
