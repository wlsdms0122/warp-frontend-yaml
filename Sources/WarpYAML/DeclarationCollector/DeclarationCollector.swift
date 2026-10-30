//
//  DeclarationCollector.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// The declarations a text writes, collected off it into the tree a
// document's declarations take, for `Declarations` to read: the types and
// contracts it declares, its procedures, the members of its types, the
// members an extension gives under its head, and its contracts' procedures.
//
// The text's keys take its `name:` prefix and the prose and the defaults
// come off, the way the text is spent. A procedure keeps its signature
// alone: each parameter as `{ name, type }`, a defaulted one's type
// Optional, and `returns`, `failing`, `const`, `isolated` and `access` as
// written. Each name of a type in a signature and in an extension's head is
// written in full, the text's own first and then what it leans on. `Self`
// and what is named through it are the conforming type's, and a type
// parameter's name is the signature's, so neither is read. A declaration
// whose key is no name is left out.
struct DeclarationCollector {
    // MARK: - Property
    private static let typeTables = ["types", "contracts"]
    private static let proceduresKey = "procedures"
    private static let extensionsKey = "extensions"
    private static let parametersKey = "parameters"
    private static let returnsKey = "returns"
    private static let nameKey = "name"
    private static let typeKey = "type"

    // What a signature holds as the text writes it.
    private static let writtenKeys = ["failing", "const", "isolated", "access"]

    // The types every text declares and the declarations of what this text
    // leans on.
    private let declarations: Declarations

    // MARK: - Initializer
    init(leaningOn declarations: Declarations) {
        self.declarations = declarations
    }

    // MARK: - Public
    // The declarations a text's tree writes. A text whose declarations do
    // not read is refused at the node that does not read.
    func collected(_ parsed: Tree) throws -> Tree {
        let naming = try Naming(of: parsed, leaningOn: declarations)
        let annotation = try Annotation(of: try naming.prefixed(parsed), reading: naming)
        let document = annotation.document
        var collected: [String: Tree] = [:]

        if let procedures = document[Self.proceduresKey] {
            collected[Self.proceduresKey] = try Self.procedures(
                procedures,
                at: [.key(Self.proceduresKey)],
                read: naming,
                defaults: annotation.defaults
            )
        }

        for table in Self.typeTables + [Self.extensionsKey] {
            guard let declared = document[table]?.dictionaryValue else { continue }

            var owners: [String: Tree] = [:]

            for (key, declaration) in declared where table == Self.extensionsKey || Self.isName(key) {
                let owner = table == Self.extensionsKey
                    ? try Self.qualified(key, at: declaration, read: naming).spelling
                    : key
                let steps: [Origin.Step] = [.key(table), .key(key), .key(Self.proceduresKey)]
                let members = try declaration[Self.proceduresKey].map { procedures in
                    try Self.procedures(procedures, at: steps, read: naming, defaults: annotation.defaults)
                }

                owners[owner] = .dictionary(members.map { members in [Self.proceduresKey: members] } ?? [:])
            }

            collected[table] = .dictionary(owners)
        }

        return .dictionary(collected)
    }

    // MARK: - Private
    private static func procedures(
        _ table: Tree,
        at steps: [Origin.Step],
        read naming: Naming,
        defaults: [[Origin.Step]: [DefaultArgument]]
    ) throws -> Tree {
        guard let declared = table.dictionaryValue else {
            throw AuthoringError("a table of procedures is a mapping", at: table)
        }

        var procedures: [String: Tree] = [:]

        for (name, procedure) in declared where isName(name) {
            let at = steps + [.key(name)]

            procedures[name] = try signature(of: procedure, read: naming, defaults: defaults[at] ?? [])
        }

        return .dictionary(procedures)
    }

    // A procedure's signature, its parameters `{ name, type }` and the types
    // it writes in full.
    private static func signature(
        of procedure: Tree,
        read naming: Naming,
        defaults: [DefaultArgument]
    ) throws -> Tree {
        guard let fields = procedure.dictionaryValue else {
            throw AuthoringError("a procedure is a mapping", at: procedure)
        }

        var signature: [String: Tree] = [:]

        if let written = fields[parametersKey] {
            guard let parameters = written.arrayValue else {
                throw AuthoringError("a procedure's parameters are a list", at: written)
            }

            signature[parametersKey] = .array(
                try parameters.enumerated().map { position, parameter in
                    let read = try Self.parameter(parameter)
                    let type = try read.type.map { type in try qualified(type, at: parameter, read: naming) }
                    let argument = defaults.first { argument in argument.position == position }
                    var held: [String: Tree] = [nameKey: .string(read.name)]

                    if let argument {
                        do throws(AuthoringError) {
                            held[typeKey] = .string(try argument.declared(type).spelling)
                        } catch {
                            throw AuthoringError(error, at: parameter)
                        }
                    } else if let type {
                        held[typeKey] = .string(type.spelling)
                    }

                    return .dictionary(held)
                }
            )
        }

        if let returns = fields[returnsKey] {
            guard let type = returns.stringValue else {
                throw AuthoringError("a procedure returns a type", at: returns)
            }

            signature[returnsKey] = .string(try qualified(type, at: returns, read: naming).spelling)
        }

        for key in writtenKeys {
            signature[key] = fields[key]
        }

        return .dictionary(signature)
    }

    // A parameter's name and the type it writes: a pair, its name the key
    // holding its type or nothing as `{}` does, or `{ name, type }`.
    private static func parameter(_ parameter: Tree) throws -> (name: String, type: String?) {
        guard let fields = parameter.dictionaryValue else {
            throw AuthoringError("a parameter is a mapping", at: parameter)
        }

        if fields.count == 1, let pair = fields.first {
            switch pair.value.content {
            case let .string(type):
                return (pair.key, type)

            case let .dictionary(held) where held.isEmpty:
                return (pair.key, nil)

            default:
                throw AuthoringError("a parameter written as a pair holds its type, or nothing", at: parameter)
            }
        }

        guard let name = fields[nameKey]?.stringValue else {
            throw AuthoringError("a parameter has a name", at: parameter)
        }

        guard let type = fields[typeKey] else { return (name, nil) }

        guard let spelling = type.stringValue else {
            throw AuthoringError("a parameter's type is a string", at: type)
        }

        return (name, spelling)
    }

    // A key that is a name. A declaration under one that is not is left out,
    // and the load refuses the key.
    private static func isName(_ key: String) -> Bool {
        (try? Name(key)) != nil
    }

    // A type with each name of a type in it written in full, by the text's
    // reading of its names, refused at `node` where it does not read.
    private static func qualified(_ type: String, at node: Tree, read naming: Naming) throws -> TypeSpelling {
        do throws(AuthoringError) {
            return try naming.qualified(try TypeSpelling(type))
        } catch {
            throw AuthoringError(error, at: node)
        }
    }
}
