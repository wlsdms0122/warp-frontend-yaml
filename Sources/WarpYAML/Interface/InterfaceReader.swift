//
//  InterfaceReader.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// An interface text into its tree: a module's declarations without their
// implementation, `(interface 1)` first, its imports, types, contracts,
// extensions and procedures in a document's nodes, each a procedure's
// signature and no body. This refuses what has no tree, an interface of
// another language version than the one this front end writes, and what an
// interface does not write: a constant, a module variable, a body, an
// access, and a key written twice. The names and signatures the tree holds
// are `Declarations`' to read.
struct InterfaceReader {
    // MARK: - Property
    // MARK: - Initializer
    init() {}

    // MARK: - Public
    func read(_ text: Data) throws(AuthoringError) -> Tree {
        var reader = try ElementReader(text)
        let nodes = try reader.read()

        guard let first = nodes.first else {
            throw AuthoringError(
                "an interface begins with '(interface \(OneWay.version))'",
                at: Origin.Position(line: 1, column: 1)
            )
        }

        let (word, operands) = try node(first)

        guard word == "interface" else {
            throw AuthoringError("a text beginning with '\(word)' is no interface", at: first.position)
        }
        guard operands.count == 1, case let .atom(.int(version), _) = operands[0] else {
            throw AuthoringError("'interface' takes the language version", at: first.position)
        }
        guard version == OneWay.version else {
            throw AuthoringError(
                "this front end writes language version \(OneWay.version), and reads no interface of version \(version)",
                at: first.position
            )
        }

        var document: [String: Tree] = ["interface": .int(version)]
        var imports: [Tree] = []

        for declaration in nodes.dropFirst() {
            let (word, operands) = try node(declaration)
            let at = declaration.position

            switch word {
            case "import":
                imports.append(.string(try joined(operands, by: ": ", cutAt: [":"], at: at)))

            case "type":
                let (name, type) = try typeMember(operands, at: at)

                try put(.string(type), under: name, in: "types", of: &document, at: at)

            case "struct":
                try put(
                    try structure(operands.dropFirst()),
                    under: try key(operands, at: at),
                    in: "types",
                    of: &document,
                    at: at
                )

            case "contract":
                try put(
                    try contract(operands.dropFirst()),
                    under: try key(operands, at: at),
                    in: "contracts",
                    of: &document,
                    at: at
                )

            case "extension":
                let (head, given) = try extensionGiven(operands, at: at)

                try put(given, under: head, in: "extensions", of: &document, at: at)

            case "procedure":
                try put(
                    try procedure(operands.dropFirst()),
                    under: try key(operands, at: at),
                    in: "procedures",
                    of: &document,
                    at: at
                )

            case "const", "var":
                throw AuthoringError("an interface writes no '\(word)'", at: at)

            case "interface":
                throw AuthoringError("'interface' is written twice", at: at)

            default:
                throw AuthoringError("'\(word)' is no node of an interface", at: at)
            }
        }

        document["imports"] = .array(imports)

        return .dictionary(document)
    }

    // MARK: - Private
    // A struct's declaration. It always writes `struct`, a struct with no
    // field included.
    private func structure(_ nodes: ArraySlice<Element>) throws(AuthoringError) -> Tree {
        var fields: [String: Tree] = [:]
        var declaration: [String: Tree] = [:]
        var typeParameters: [Tree] = []

        for member in nodes {
            let (word, operands) = try node(member)
            let at = member.position

            switch word {
            case "field":
                guard operands.count == 2 else { throw AuthoringError("'field' takes a name and a type", at: at) }

                try put(
                    .string(try TypeSpelling(operands[1]).spelling),
                    under: try name(operands[0]),
                    in: &fields,
                    at: at
                )

            case "typeParameter":
                typeParameters.append(.string(try bounded(operands, at: at)))

            default:
                try given(word, operands, at: at, into: &declaration)
            }
        }

        declaration["struct"] = .dictionary(fields)

        if !typeParameters.isEmpty {
            declaration["typeParameters"] = .array(typeParameters)
        }

        return .dictionary(declaration)
    }

    private func contract(_ nodes: ArraySlice<Element>) throws(AuthoringError) -> Tree {
        var declaration: [String: Tree] = [:]
        var types: [Tree] = []

        for member in nodes {
            let (word, operands) = try node(member)
            let at = member.position

            switch word {
            case "type":
                types.append(.string(try bounded(operands, at: at)))

            case "procedure":
                try put(
                    try procedure(operands.dropFirst()),
                    under: try key(operands, at: at),
                    in: "procedures",
                    of: &declaration,
                    at: at
                )

            default:
                throw AuthoringError("'\(word)' is no node of a contract", at: at)
            }
        }

        if !types.isEmpty {
            declaration["types"] = .array(types)
        }

        return .dictionary(declaration)
    }

    // An extension's head, the key it stands under, and what it gives.
    private func extensionGiven(
        _ nodes: [Element],
        at position: Origin.Position
    ) throws(AuthoringError) -> (String, Tree) {
        var head: String?
        var declaration: [String: Tree] = [:]

        for member in nodes {
            let (word, operands) = try node(member)
            let at = member.position

            guard word == "head" else {
                try given(word, operands, at: at, into: &declaration)
                continue
            }

            guard head == nil else { throw AuthoringError("'head' is written twice", at: at) }
            guard operands.count == 1 else { throw AuthoringError("'head' takes one type", at: at) }

            head = try TypeSpelling(operands[0]).spelling
        }

        guard let head else { throw AuthoringError("an extension writes its head", at: position) }

        return (head, .dictionary(declaration))
    }

    // What a struct's declaration and an extension both give a type: the
    // contracts it adopts, its type members and its members.
    private func given(
        _ word: String,
        _ operands: [Element],
        at position: Origin.Position,
        into declaration: inout [String: Tree]
    ) throws(AuthoringError) {
        switch word {
        case "satisfies":
            try put(
                .array(try operands.map { operand throws(AuthoringError) in .string(try name(operand)) }),
                under: word,
                in: &declaration,
                at: position
            )

        case "type":
            let (name, type) = try typeMember(operands, at: position)

            try put(.string(type), under: name, in: "types", of: &declaration, at: position)

        case "procedure":
            try put(
                try procedure(operands.dropFirst()),
                under: try key(operands, at: position),
                in: "procedures",
                of: &declaration,
                at: position
            )

        default:
            throw AuthoringError("'\(word)' is no node here", at: position)
        }
    }

    // A procedure's signature: what a procedure, a member and a contract's
    // procedure write in an interface.
    private func procedure(_ nodes: ArraySlice<Element>) throws(AuthoringError) -> Tree {
        var signature: [String: Tree] = [:]
        var parameters: [Tree] = []

        for part in nodes {
            let (word, operands) = try node(part)
            let at = part.position

            switch word {
            case "const", "isolated":
                guard operands.isEmpty else { throw AuthoringError("'\(word)' takes nothing", at: at) }

                try put(.bool(true), under: word, in: &signature, at: at)

            case "parameter":
                parameters.append(try parameter(operands, at: at))

            case "returns":
                guard operands.count == 1 else { throw AuthoringError("'returns' takes one type", at: at) }

                try put(.string(try TypeSpelling(operands[0]).spelling), under: word, in: &signature, at: at)

            case "failing":
                try put(try failing(operands), under: word, in: &signature, at: at)

            case "bound":
                guard operands.count >= 2 else { throw AuthoringError("'bound' takes a name and its contracts", at: at) }

                let bound = try joined(Array(operands.dropFirst()), by: " & ", cutAt: ["&"], at: at)

                try put(.string(bound), under: try name(operands[0]), in: "bounds", of: &signature, at: at)

            case "sameType":
                let (name, type) = try typeMember(operands, at: at)

                try put(.string(type), under: name, in: "sameTypes", of: &signature, at: at)

            case "body", "access":
                throw AuthoringError("an interface writes no '\(word)'", at: at)

            default:
                throw AuthoringError("'\(word)' is no node of a procedure", at: at)
            }
        }

        if !parameters.isEmpty {
            signature["parameters"] = .array(parameters)
        }

        return .dictionary(signature)
    }

    // `(parameter f)` or `(parameter f (type T))`.
    private func parameter(_ operands: [Element], at position: Origin.Position) throws(AuthoringError) -> Tree {
        guard let first = operands.first, operands.count <= 2 else {
            throw AuthoringError("'parameter' takes a name and its type", at: position)
        }

        var parameter: [String: Tree] = ["name": .string(try name(first))]

        if operands.count == 2 {
            let (word, typed) = try node(operands[1])

            guard word == "type", typed.count == 1 else {
                throw AuthoringError("a parameter's type is written '(type …)'", at: operands[1].position)
            }

            parameter["type"] = .string(try TypeSpelling(typed[0]).spelling)
        }

        return .dictionary(parameter)
    }

    // `(failing (anything))` writes `anything`, and `(failing a b)` the names.
    private func failing(_ operands: [Element]) throws(AuthoringError) -> Tree {
        if operands.count == 1, case let .list(elements, _) = operands[0] {
            guard elements.count == 1, case .atom(.name("anything"), _) = elements[0] else {
                throw AuthoringError("'failing' takes '(anything)' or names", at: operands[0].position)
            }

            return .string("anything")
        }

        return .array(try operands.map { operand throws(AuthoringError) in .string(try name(operand)) })
    }

    // A name and a type: a type a document declares, a type member, a same
    // type.
    private func typeMember(
        _ operands: [Element],
        at position: Origin.Position
    ) throws(AuthoringError) -> (String, String) {
        guard operands.count == 2 else { throw AuthoringError("a name and a type are written here", at: position) }

        return (try name(operands[0]), try TypeSpelling(operands[1]).spelling)
    }

    // A name and the contracts bounding it, `K: App.Named & Hashable`: a
    // struct's type parameter, a contract's type.
    private func bounded(_ operands: [Element], at position: Origin.Position) throws(AuthoringError) -> String {
        guard let first = operands.first else { throw AuthoringError("a name is written here", at: position) }

        let name = try joined([first], by: "", cutAt: [":"], at: position)

        guard operands.count > 1 else { return name }

        return "\(name): \(try joined(Array(operands.dropFirst()), by: " & ", cutAt: ["&"], at: position))"
    }

    // Names the tree joins into one string, each read back by cutting at
    // `cuts`: one holding a cut, or white space at an end, has no text.
    private func joined(
        _ operands: [Element],
        by separator: String,
        cutAt cuts: Set<Character>,
        at position: Origin.Position
    ) throws(AuthoringError) -> String {
        guard !operands.isEmpty else { throw AuthoringError("a name is written here", at: position) }

        var names: [String] = []

        for operand in operands {
            let name = try name(operand)

            guard
                !name.contains(where: cuts.contains),
                name.first?.isWhitespace != true,
                name.last?.isWhitespace != true
            else {
                throw AuthoringError("'\(name)' is cut otherwise where the tree joins it", at: operand.position)
            }

            names.append(name)
        }

        return names.joined(separator: separator)
    }

    // A declaration's name, the first of its operands.
    private func key(_ operands: [Element], at position: Origin.Position) throws(AuthoringError) -> String {
        guard let first = operands.first else {
            throw AuthoringError("a declaration is written with its name", at: position)
        }

        return try name(first)
    }

    private func name(_ operand: Element) throws(AuthoringError) -> String {
        guard case let .atom(.name(name), _) = operand else {
            throw AuthoringError("a name stands here", at: operand.position)
        }

        return name
    }

    // A node's word and its operands.
    private func node(_ element: Element) throws(AuthoringError) -> (String, [Element]) {
        guard case let .list(elements, _) = element, case let .atom(.name(word), _) = elements.first else {
            throw AuthoringError("a node is a list beginning with its word", at: element.position)
        }

        return (word, Array(elements.dropFirst()))
    }

    // `value` under `key` in the dictionary `table` of `dictionary`.
    private func put(
        _ value: Tree,
        under key: String,
        in table: String,
        of dictionary: inout [String: Tree],
        at position: Origin.Position
    ) throws(AuthoringError) {
        var entries = dictionary[table]?.dictionaryValue ?? [:]

        try put(value, under: key, in: &entries, at: position)
        dictionary[table] = .dictionary(entries)
    }

    private func put(
        _ value: Tree,
        under key: String,
        in dictionary: inout [String: Tree],
        at position: Origin.Position
    ) throws(AuthoringError) {
        guard dictionary[key] == nil else { throw AuthoringError("'\(key)' is written twice", at: position) }

        dictionary[key] = value
    }
}
