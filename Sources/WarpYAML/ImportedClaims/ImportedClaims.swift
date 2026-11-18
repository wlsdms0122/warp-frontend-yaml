//
//  ImportedClaims.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// The claims a document imports: those a piece of a module it uses makes
// about a type and a contract that piece declares neither of. A document
// that asks whether a type satisfies a contract reads the contract, and the
// type where a document declares it, so a claim written beside either is
// reached with it. A claim written beside neither is reached by nothing the
// document names, so the document writes it. A piece is what this front end
// is handed as one: a text, or an interface.
struct ImportedClaims {
    // One claim: the type, and the contract it satisfies.
    struct Claim: Sendable, Hashable, Comparable {
        // MARK: - Property
        let type: String
        let contract: String

        // MARK: - Initializer
        init(_ type: String, _ contract: String) {
            self.type = type
            self.contract = contract
        }

        // MARK: - Public
        // By the type and then by the contract, each by its bytes.
        static func < (lhs: Claim, rhs: Claim) -> Bool {
            guard lhs.type != rhs.type else { return lhs.contract.utf8.lexicographicallyPrecedes(rhs.contract.utf8) }

            return lhs.type.utf8.lexicographicallyPrecedes(rhs.type.utf8)
        }

        // MARK: - Private
    }

    // MARK: - Property
    private static let typesKey = "types"
    private static let contractsKey = "contracts"
    private static let extensionsKey = "extensions"
    private static let satisfiesKey = "satisfies"

    // MARK: - Initializer
    // MARK: - Public
    // The claims a piece's declarations make that the piece declares neither
    // the type nor the contract of, every name in it written in full. A
    // type's declaration claims about the type it declares, so only an
    // extension makes one.
    static func orphans(of piece: Tree) -> Set<Claim> {
        let declared = keys(of: piece[typesKey]).union(keys(of: piece[contractsKey]))
        var claims: Set<Claim> = []

        for (head, given) in piece[extensionsKey]?.dictionaryValue ?? [:] {
            guard let type = (try? TypeSpelling(head))?.extendedType, !declared.contains(type) else { continue }

            for contract in given[satisfiesKey]?.arrayValue?.compactMap(\.stringValue) ?? []
            where !declared.contains(contract) {
                claims.insert(Claim(type, contract))
            }
        }

        return claims
    }

    // MARK: - Private
    // The keys of a table, and none where it is no dictionary.
    private static func keys(of table: Tree?) -> Set<String> {
        Set(table?.dictionaryValue?.keys.map { key in key } ?? [])
    }
}
