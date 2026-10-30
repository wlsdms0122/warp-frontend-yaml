//
//  Declarations.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The declarations of the documents a text leans on, each read from its
// document's tree: every procedure's signature by its full name, and the
// full names each short name stands for. A text names one by its short name
// where it declares nothing of that name itself.
//
// A short name is a type's, a contract's or a procedure's last identifier,
// so `Standard.Comparable` is `Comparable` and `Standard.Optional.unwrapped`
// is `unwrapped`. A procedure spelled under a type its document declares or
// gives members to is that type's short name and its own: `Lib.Card.describe`
// is `Card.describe`, and a member given under the head `Int` is
// `Int.plus`. A contract is no such owner, so a procedure spelled under one
// is its last identifier, as a contract's own procedure is. A private
// procedure is its document's, and has no short name here. Two declarations
// of one short name are named by neither, and the full name is written. A
// name that is a declaration's full name stands for that declaration before
// any short name is read.
//
// A call naming its arguments is matched against its callee's signature
// here.
struct Declarations: Sendable {
    // MARK: - Property
    // Every procedure, by its full name: a document's, a member and a
    // contract's.
    private let signatures: [Name: ProcedureSignature]

    // The full names each short name stands for, in the space it stands in.
    private let shortNames: [Space: [Name: Set<Name>]]

    // MARK: - Initializer
    // No declarations.
    init() {
        self.init(signatures: [:], shortNames: [:])
    }

    private init(signatures: [Name: ProcedureSignature], shortNames: [Space: [Name: Set<Name>]]) {
        self.signatures = signatures
        self.shortNames = shortNames
    }

    // MARK: - Public
    // The signature of the procedure declared under a full name.
    func signature(of procedure: Name) -> ProcedureSignature? {
        signatures[procedure]
    }

    // The declaration a name stands for in that space: the one it is the
    // full name of, else the one it is the short name of, and nothing where
    // it is neither. Two of one short name refuse.
    func qualified(_ name: Name, in space: Space) throws(AuthoringError) -> Name? {
        guard !declares(name, in: space) else { return name }

        let declared = declarations(named: name, in: space)

        guard declared.count > 1 else { return declared.first }

        let listed = declared.dropLast().map(\.spelling).joined(separator: ", ")

        throw AuthoringError(
            "'\(name)' is declared by \(listed) and \(declared[declared.count - 1]). Write the one you mean in full"
        )
    }

    // Every declaration a short name stands for in that space, by full name
    // in order.
    func declarations(named name: Name, in space: Space) -> [Name] {
        (shortNames[space]?[name] ?? []).sorted()
    }

    // The arguments a call hands by name, by position: each under the
    // callee's parameter it is handed to, in the callee's parameter order, an
    // Optional parameter the call does not name handed `null`. A name the
    // callee does not declare is refused at what it hands.
    func arguments(
        _ named: [Name: Tree],
        to callee: Name
    ) throws(AuthoringError) -> [(parameter: Name, argument: Tree)] {
        guard let parameters = signatures[callee]?.parameters else {
            throw AuthoringError(
                "'\(callee)' is not declared by a document this text leans on, so its arguments are written by position"
            )
        }

        if
            let unknown = named.keys.sorted().first(where: { name in !parameters.contains { $0.name == name } }),
            let argument = named[unknown]
        {
            let taken = parameters.isEmpty ? "nothing" : parameters.map(\.name.spelling).joined(separator: ", ")

            throw AuthoringError("'\(callee)' takes no '\(unknown)'. It takes \(taken)", at: argument)
        }

        return try parameters.map { parameter throws(AuthoringError) in
            if let argument = named[parameter.name] { return (parameter.name, argument) }

            guard parameter.type?.isOptional == true else {
                let type = parameter.type?.spelling ?? "Any"

                throw AuthoringError("'\(callee)' takes \(parameter.name), \(type), which this call does not name")
            }

            return (parameter.name, .null)
        }
    }

    // These declarations with what a document's tree declares: its types,
    // contracts, procedures, the members it gives under `types` and
    // `extensions`, and its contracts' procedures.
    func adding(_ document: Tree) throws -> Declarations {
        let types = document["types"]?.dictionaryValue ?? [:]
        let contracts = document["contracts"]?.dictionaryValue ?? [:]
        let extensions = document["extensions"]?.dictionaryValue ?? [:]
        let typed = adding(types: try (Array(types.keys) + contracts.keys).map { type in try Name(type) })
        var signatures = typed.signatures
        var shortNames = typed.shortNames

        var members: [(owner: String, procedures: Tree?)] = types.map { type, declaration in
            (type, declaration["procedures"])
        }

        for (head, given) in extensions {
            guard let owner = try TypeSpelling(head).extendedType else { continue }

            members.append((owner, given["procedures"]))
        }

        var procedures = document["procedures"]?.dictionaryValue ?? [:]

        for (owner, declared) in members {
            for (name, procedure) in declared?.dictionaryValue ?? [:] {
                procedures["\(owner).\(name)"] = procedure
            }
        }

        let owners = try Set(members.map { member in try Name(member.owner) })

        for (spelling, procedure) in procedures {
            let name = try Name(spelling)
            let signature = try ProcedureSignature(procedure)

            signatures[name] = signature

            guard signature.access != .private else { continue }

            shortNames[.procedure, default: [:]][Self.shortName(of: name, among: owners), default: []].insert(name)
        }

        for (contract, declaration) in contracts {
            for (spelling, procedure) in declaration["procedures"]?.dictionaryValue ?? [:] {
                let short = try Name(spelling)
                let name = try Name("\(contract).\(spelling)")

                signatures[name] = try ProcedureSignature(procedure)
                shortNames[.procedure, default: [:]][short, default: []].insert(name)
            }
        }

        return Declarations(signatures: signatures, shortNames: shortNames)
    }

    // These declarations with types known by their full names alone, before
    // what declares them is read.
    func adding(types: some Sequence<Name>) -> Declarations {
        var shortNames = shortNames

        for type in types {
            shortNames[.type, default: [:]][Self.lastIdentifier(of: type), default: []].insert(type)
        }

        return Declarations(signatures: signatures, shortNames: shortNames)
    }

    // MARK: - Private
    // Whether a declaration in that space has this full name. A type's full
    // name stands among those of its last identifier.
    private func declares(_ name: Name, in space: Space) -> Bool {
        switch space {
        case .type:
            shortNames[.type]?[Self.lastIdentifier(of: name)]?.contains(name) == true

        case .procedure:
            signatures[name] != nil
        }
    }

    // A procedure's short name: under one of the owners its document
    // declares or gives members to, the owner's short name and the
    // procedure's last identifier, and elsewhere the last identifier alone.
    private static func shortName(of procedure: Name, among owners: Set<Name>) -> Name {
        let last = lastIdentifier(of: procedure)

        guard
            procedure != last,
            let owner = try? Name(String(procedure.spelling.dropLast(last.spelling.count + 1))),
            owners.contains(owner),
            let short = try? Name("\(lastIdentifier(of: owner)).\(last)")
        else {
            return last
        }

        return short
    }

    private static func lastIdentifier(of name: Name) -> Name {
        guard
            let dot = name.spelling.lastIndex(of: "."),
            let last = try? Name(String(name.spelling[name.spelling.index(after: dot)...]))
        else {
            return name
        }

        return last
    }
}
