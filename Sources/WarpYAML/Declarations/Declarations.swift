//
//  Declarations.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The declarations of the documents a text uses, each read from its
// document's tree: every procedure's signature by its full name, and the
// full names each short name stands for. A text names one by its short name
// where it declares nothing of that name itself.
//
// A short name is a type's, a contract's or a procedure's last identifier,
// so `Standard.Comparable` is `Comparable` and `Standard.Optional.unwrapped`
// is `unwrapped`. A procedure spelled under a type its document declares or
// gives members to is that type's short name and its own: `Lib.Card.describe`
// is `Card.describe`, and a member given under the head `Int` is
// `Int.plus`. A type member's spelling is so too, `Lib.Card.Item` is
// `Card.Item`, and is an alias of the type the type member gives. A contract
// is no such owner, so a procedure spelled under one is its last
// identifier, as a contract's own procedure is. A private procedure is its
// document's, and has no short name here. Two declarations of one short
// name are named by neither, and the full name is written. A name that is a
// declaration's full name stands for that declaration before any short name
// is read. Another text of the module reads a text's private procedures
// as concealed: none of them is declared to it, and one it names that
// nothing it reads declares is refused as private.
//
// A call naming its arguments is matched against its callee's signature
// here, and an alias is read as the type it spells: a type member's after
// an applied type, `App.Wrapper<String>.Item`, under the head the type
// member is given under, the head's type parameters read as the types
// between the brackets.
struct Declarations: Sendable {
    // MARK: - Property
    // Every procedure, by its full name: a document's, a member and a
    // contract's.
    private let signatures: [Name: ProcedureSignature]

    // The full names each short name stands for, in the space it stands in.
    private let shortNames: [Space: [Name: Set<Name>]]

    // Every alias, by its full name, as the type it spells: a type declared
    // as one, and a type member's spelling as the type the type member
    // gives, with the head it is given under.
    private let aliases: [Name: Alias]

    // The full names of the private procedures of another text of the
    // module, which this table does not declare.
    private let concealed: Set<Name>

    // MARK: - Initializer
    // No declarations.
    init() {
        self.init(signatures: [:], shortNames: [:], aliases: [:], concealed: [])
    }

    private init(
        signatures: [Name: ProcedureSignature],
        shortNames: [Space: [Name: Set<Name>]],
        aliases: [Name: Alias],
        concealed: Set<Name>
    ) {
        self.signatures = signatures
        self.shortNames = shortNames
        self.aliases = aliases
        self.concealed = concealed
    }

    // MARK: - Public
    // The signature of the procedure declared under a full name.
    func signature(of procedure: Name) -> ProcedureSignature? {
        signatures[procedure]
    }

    // The type a spelling stands for where it is an alias: a name declared
    // as one, which applies no types, and a type member's spelling after a
    // type applied to the types between its brackets, read under the head
    // the type member is given under. Nothing where the spelling is no
    // alias, or the head does not take what it applies.
    func alias(_ type: TypeSpelling) -> TypeSpelling? {
        switch type {
        case let .named(spelling, arguments: []):
            alias(spelling, under: [])

        case let .member(applied, name):
            applied.extendedType.flatMap { owner in alias("\(owner).\(name)", under: applied.arguments) }

        case .named, .array, .dictionary, .optional, .composition, .parameter, .inout, .variable, .procedure,
            .unsaidProcedure:
            nil
        }
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
    // callee does not declare is refused at what it hands. Nothing where
    // the table does not declare the callee.
    func arguments(
        _ named: [Name: Tree],
        to callee: Name
    ) throws(AuthoringError) -> [(parameter: Name, argument: Tree)]? {
        guard let parameters = signatures[callee]?.parameters else { return nil }

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
    // contracts, procedures, the members and type members it gives under
    // `types` and `extensions`, and its contracts' procedures.
    func adding(_ document: Tree) throws -> Declarations {
        let types = document["types"]?.dictionaryValue ?? [:]
        let contracts = document["contracts"]?.dictionaryValue ?? [:]
        let extensions = document["extensions"]?.dictionaryValue ?? [:]
        let typed = adding(types: try (Array(types.keys) + contracts.keys).map { type in try Name(type) })
        var signatures = typed.signatures
        var shortNames = typed.shortNames
        var aliases = aliases

        for (type, declaration) in types {
            guard let spelled = declaration.stringValue else { continue }

            aliases[try Name(type)] = Alias(head: [], type: try TypeSpelling(spelled))
        }

        var members: [(head: TypeSpelling, given: Tree)] = try types.map { type, declaration in
            (try Self.head(of: type, declaredBy: declaration), declaration)
        }

        for (head, given) in extensions {
            members.append((try TypeSpelling(head), given))
        }

        var procedures = document["procedures"]?.dictionaryValue ?? [:]

        for (head, given) in members {
            guard let owner = head.extendedType else { continue }

            for (name, procedure) in given["procedures"]?.dictionaryValue ?? [:] {
                procedures["\(owner).\(name)"] = procedure
            }
        }

        let owners = try Set(members.compactMap(\.head.extendedType).map { owner in try Name(owner) })

        for (head, given) in members {
            guard let owner = head.extendedType else { continue }

            for (member, spelled) in given["types"]?.dictionaryValue ?? [:] {
                guard let type = spelled.stringValue else { continue }

                let name = try Name("\(owner).\(member)")

                aliases[name] = Alias(head: head.arguments, type: try TypeSpelling(type))
                shortNames[.type, default: [:]][Self.shortName(of: name, among: owners), default: []].insert(name)
            }
        }

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

                // What a contract asks is named wherever the contract is,
                // so it is read as no access writes it, an access written
                // on it the load's to refuse.
                let asked = try ProcedureSignature(procedure)

                signatures[name] = ProcedureSignature(
                    parameters: asked.parameters,
                    returns: asked.returns,
                    failing: asked.failing,
                    const: asked.const,
                    isolated: asked.isolated,
                    access: .internal
                )
                shortNames[.procedure, default: [:]][short, default: []].insert(name)
            }
        }

        return Declarations(signatures: signatures, shortNames: shortNames, aliases: aliases, concealed: concealed)
    }

    // These declarations and another table's, as one table, these where
    // both declare a name.
    func merging(_ other: Declarations) -> Declarations {
        Declarations(
            signatures: signatures.merging(other.signatures) { mine, _ in mine },
            shortNames: shortNames.merging(other.shortNames) { mine, theirs in
                mine.merging(theirs) { names, others in names.union(others) }
            },
            aliases: aliases.merging(other.aliases) { mine, _ in mine },
            concealed: concealed.union(other.concealed)
        )
    }

    // These declarations as another text of the module reads them, each
    // private procedure concealed.
    func concealingPrivate() -> Declarations {
        let hidden = signatures.filter { _, signature in signature.access == .private }

        return Declarations(
            signatures: signatures.filter { name, _ in hidden[name] == nil },
            shortNames: shortNames,
            aliases: aliases,
            concealed: concealed.union(hidden.keys)
        )
    }

    // Why a text reading this table does not reach the name, where it is
    // a private procedure of another text of the module that the table does
    // not declare, and nothing where it is not.
    func concealment(of name: Name) -> String? {
        guard concealed.contains(name), !declares(name, in: .procedure) else { return nil }

        return "'\(name.spelling)' is private to another text of the module"
    }

    // Whether a declaration in either space has this full name.
    func declares(_ name: Name) -> Bool {
        declares(name, in: .type) || declares(name, in: .procedure)
    }

    // Whether a declaration in that space has this full name. A type's full
    // name stands among those of its last identifier, and an alias is known
    // by its full name.
    func declares(_ name: Name, in space: Space) -> Bool {
        switch space {
        case .type:
            shortNames[.type]?[Self.lastIdentifier(of: name)]?.contains(name) == true || aliases[name] != nil

        case .procedure:
            signatures[name] != nil
        }
    }

    // These declarations with types known by their full names alone, before
    // what declares them is read.
    func adding(types: some Sequence<Name>) -> Declarations {
        var shortNames = shortNames

        for type in types {
            shortNames[.type, default: [:]][Self.lastIdentifier(of: type), default: []].insert(type)
        }

        return Declarations(signatures: signatures, shortNames: shortNames, aliases: aliases, concealed: concealed)
    }

    // MARK: - Private
    // The type an alias's full name spells under the types a spelling
    // applies, and nothing where none is declared or its head does not take
    // them.
    private func alias(_ spelling: String, under arguments: [TypeSpelling]) -> TypeSpelling? {
        guard let name = try? Name(spelling) else { return nil }

        return aliases[name]?.type(under: arguments)
    }

    // The head a struct's or an enum's declaration gives its members under:
    // the type applied to its own type parameters in order, each `some T`
    // with its bounds.
    private static func head(of type: String, declaredBy declaration: Tree) throws -> TypeSpelling {
        let parameters = try (declaration["typeParameters"]?.arrayValue ?? []).compactMap { parameter in
            try parameter.stringValue.map { spelled in try TypeSpelling("some \(spelled)") }
        }

        return .named(type, arguments: parameters)
    }

    // A procedure's or a type member's short name: under one of the owners
    // its document declares or gives members to, the owner's short name and
    // the name's last identifier, and elsewhere the last identifier alone.
    private static func shortName(of name: Name, among owners: Set<Name>) -> Name {
        let last = lastIdentifier(of: name)

        guard
            name != last,
            let owner = try? Name(String(name.spelling.dropLast(last.spelling.count + 1))),
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
