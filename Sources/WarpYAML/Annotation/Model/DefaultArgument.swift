//
//  DefaultArgument.swift
//  WarpYAML
//
//  Created by JSilver on 10/24/26.
//

import Foundation

// One parameter's `default:`, spent at its declaration. The parameter `x: T`
// reads `T?`, and the body first binds
// `{ let: x, type: T, value: { call: { procedure: Standard.Optional.unwrapped, arguments: [ { ref: x }, { closure: { returns: T, body: [ { value: { return: d } } ] } } ] } } }`,
// so an argument that is none, an omitted one included, takes the default.
// A parameter of any type writes no type on the binding, and its closure
// returns `Any`. The closure takes the rest of its signature from the slot
// it stands in.
struct DefaultArgument {
    // MARK: - Property
    static let key = "default"
    static let unwrapped = "Standard.Optional.unwrapped"
    private static let typeKey = "type"
    private static let returnKey = "return"

    // Where the parameter stands among its procedure's.
    let position: Int

    // Where the text wrote the procedure.
    let procedure: [Origin.Step]

    // The default as the text wrote it.
    let written: Tree

    // MARK: - Initializer
    init(position: Int, written: Tree, procedure: [Origin.Step]) {
        self.position = position
        self.procedure = procedure
        self.written = written
    }

    // MARK: - Public
    // The parameter's type as the document declares it, from the type the
    // text writes: that type's Optional, and `Any?` where it writes none.
    func declared(_ type: TypeSpelling?) throws(AuthoringError) -> TypeSpelling {
        if case .inout? = type {
            throw inoutRefusal
        }

        return .optional(type ?? .named("Any", arguments: []))
    }

    // The parameter as the document declares it and the statement binding
    // it, from the pair the text writes it as once its default is off:
    // `x: T` reads `x: T?`, and `x: {}` reads `x: Any?`. A pair holding
    // more, or a type that does not read, is left for the load.
    func spent(_ parameter: Tree) throws -> (parameter: Tree, binding: Tree)? {
        guard let pair = parameter.dictionaryValue, pair.count == 1, let (name, held) = pair.first else { return nil }

        var writtenType: TypeSpelling?

        if let spelling = held.stringValue {
            guard let read = try? TypeSpelling(spelling) else { return nil }

            writtenType = read
        } else if held.dictionaryValue?.isEmpty != true {
            return nil
        }

        // A default on a parameter handed in place is refused at the
        // parameter where the text's declarations are collected, before this.
        let type = try declared(writtenType)

        return (
            parameter.holding(.dictionary([name: held.making(.string(type.spelling))])),
            parameter.making(binding(named: .string(name), typed: writtenType == nil ? nil : held))
        )
    }

    // MARK: - Private
    // The statement binding the parameter named `name` to what it was handed
    // or the default, `type` the one the text declares, before it reads
    // `T?`.
    private func binding(named name: Tree, typed type: Tree?) -> Tree {
        let otherwise: Tree = .dictionary([
            "returns": type ?? .string("Any"),
            "body": .array([.dictionary(["value": .dictionary([Self.returnKey: written])])])
        ])
        let unwrapped: Tree = .dictionary([
            "procedure": .string(Self.unwrapped),
            "arguments": .array([.dictionary(["ref": name]), .dictionary(["closure": otherwise])])
        ])
        var binding: [String: Tree] = ["let": name, "value": .dictionary(["call": unwrapped])]

        binding[Self.typeKey] = type

        return .dictionary(binding)
    }

    private var inoutRefusal: AuthoringError {
        AuthoringError("a parameter handed in place takes a variable, and a default is none")
    }
}
