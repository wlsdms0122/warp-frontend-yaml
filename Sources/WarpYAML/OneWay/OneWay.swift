//
//  OneWay.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The last pass: a document says each thing one way (WARP-11), where
// the passes before it can write a thing another way. A parameter of any
// type writes no type, so `Any` written out is left out, and `satisfies`,
// `failing` and a contract's `types` stand in name order, compared by their
// bytes, since a short name written in full can sort elsewhere. A contract's
// type is compared by the name it introduces. Then the document says its
// version where the text writes none, the names its program uses as its
// `imports`, in name order, and the claims it imports, by the type and then
// by the contract, where there are any. Every other absence and order the
// text writes stands, for the load to judge.
struct OneWay {
    // MARK: - Property
    static let version = 1

    private static let versionKey = "warp"
    private static let importsKey = "imports"
    private static let importedClaimsKey = "importedClaims"

    // What this pass writes and no text does.
    static let writtenKeys = [importsKey, importedClaimsKey]
    private static let typeKey = "type"
    private static let failingKey = "failing"
    private static let satisfiesKey = "satisfies"
    private static let typesKey = "types"
    private static let any = "Any"

    // MARK: - Initializer
    init() {
    }

    // MARK: - Public
    // The document as its spend finished it, importing the names its
    // program uses and the claims it stands on.
    func written(
        _ document: Tree,
        importing names: [String],
        claiming claims: Set<ImportedClaims.Claim>
    ) throws -> Tree {
        let ruled = try Grammar().rewriting(document) { node, kind in
            switch kind {
            case .document:
                Self.declarationsInNameOrder(node)

            case .procedure, .closure:
                Self.inNameOrder(node, under: Self.failingKey, by: Self.precedes)

            case .parameter:
                Self.anyLeftOut(node)

            case .type, .contract, .bound, .typeParameter, .arms, .body, .statement, .expression, .path, .callee:
                node
            }
        }

        guard var entries = ruled.dictionaryValue else { return ruled }

        if entries[Self.versionKey] == nil {
            entries[Self.versionKey] = ruled.making(.int(Self.version))
        }

        entries[Self.importsKey] = ruled.making(.array(names.map(Tree.string)))

        entries[Self.importedClaimsKey] = claims.isEmpty ? nil : ruled.making(.array(claims.sorted().map { claim in
            .array([.string(claim.type), .string(claim.contract)])
        }))

        return ruled.holding(.dictionary(entries))
    }

    // Names in name order by their bytes.
    static func inNameOrder(_ names: [String]) -> [String] {
        names.sorted(by: precedes)
    }

    // MARK: - Private
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

        let lists: [(table: String, key: String, order: (String, String) -> Bool)] = [
            (typesKey, satisfiesKey, precedes),
            ("extensions", satisfiesKey, precedes),
            ("contracts", typesKey, introducedPrecedes)
        ]

        for (table, key, order) in lists {
            guard let declarations = entries[table], let held = declarations.dictionaryValue else { continue }

            entries[table] = declarations.holding(.dictionary(held.mapValues { declaration in
                inNameOrder(declaration, under: key, by: order)
            }))
        }

        return document.holding(.dictionary(entries))
    }

    // The node with the list of names under `key` in name order. A list
    // holding anything but strings is left for the load.
    private static func inNameOrder(
        _ node: Tree,
        under key: String,
        by order: (String, String) -> Bool
    ) -> Tree {
        guard
            var fields = node.dictionaryValue,
            let list = fields[key],
            let written = list.arrayValue
        else {
            return node
        }

        guard written.allSatisfy({ element in element.stringValue != nil }) else { return node }

        fields[key] = list.holding(.array(written.sorted { first, second in
            order(first.stringValue ?? "", second.stringValue ?? "")
        }))

        return node.holding(.dictionary(fields))
    }

    private static func precedes(_ first: String, _ second: String) -> Bool {
        first.utf8.lexicographicallyPrecedes(second.utf8)
    }

    // Two names a list introduces, each read up to a `:` written beside it,
    // `"Item: Hashable"` as `Item`.
    private static func introducedPrecedes(_ first: String, _ second: String) -> Bool {
        precedes(name(of: first), name(of: second))
    }

    // A name read up to a `:` written beside it.
    private static func name(of written: String) -> String {
        guard let colon = written.firstIndex(of: ":") else { return written }

        return written[..<colon].trimmingCharacters(in: .whitespaces)
    }
}
