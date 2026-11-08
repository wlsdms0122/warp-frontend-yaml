//
//  TypeSpelling.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A type as the type grammar writes it: its parts, read from a string in the
// one spelling and written back as that string. What a type means, whether a
// name is declared, a bound names a contract or a modifier stands where it
// may, is the load's to judge, so the parts are held in the order written.
indirect enum TypeSpelling: Sendable, Hashable {
    // A name, `Int`, `App.Point`, `Self` or `Self.Item`, and with arguments a
    // name applied to the types between its brackets, `App.Box<Int>`.
    case named(String, arguments: [TypeSpelling])
    case array(TypeSpelling)
    case dictionary(key: TypeSpelling, value: TypeSpelling)
    // A type member's name after a type applied to the types between its
    // brackets, `App.Wrapper<String>.Item`. A type member's spelling written
    // bare, `App.Box.Item`, is a name.
    case member(TypeSpelling, name: String)
    case optional(TypeSpelling)
    case composition([String])
    // `some T` or `some T.Item`, with the contracts written beside it where it
    // is bounded, `some T: Hashable & App.Named`.
    case parameter(String, bounds: [String])
    case `inout`(TypeSpelling)
    // `var T`, a field a path may write through.
    case variable(TypeSpelling)
    case procedure(
        modifiers: [ProcedureModifier],
        parameters: [TypeSpelling],
        failing: ThrowsClause?,
        returns: TypeSpelling
    )
    // `const Procedure`: a procedure the modifiers say something of, its
    // signature unsaid. `Procedure` written bare is a name.
    case unsaidProcedure(modifiers: [ProcedureModifier])

    // MARK: - Property
    // The one spelling.
    var spelling: String {
        switch self {
        case let .named(name, arguments):
            arguments.isEmpty ? name : "\(name)<\(Self.joined(arguments))>"

        case let .array(element):
            "Array<\(element.spelling)>"

        case let .dictionary(key, value):
            "Dictionary<\(key.spelling), \(value.spelling)>"

        case let .member(applied, name):
            "\(applied.spelling).\(name)"

        case let .optional(wrapped):
            wrapped.isGrouped ? "(\(wrapped.spelling))?" : "\(wrapped.spelling)?"

        case let .composition(names):
            names.joined(separator: " & ")

        case let .parameter(name, bounds):
            bounds.isEmpty ? "some \(name)" : "some \(name): \(bounds.joined(separator: " & "))"

        case let .inout(type):
            "inout \(type.spelling)"

        case let .variable(type):
            "var \(type.spelling)"

        case let .procedure(modifiers, parameters, failing, returns):
            Self.prefix(modifiers) + "(\(Self.joined(parameters)))\(Self.clause(failing)) -> \(returns.spelling)"

        case let .unsaidProcedure(modifiers):
            "\(Self.prefix(modifiers))Procedure"
        }
    }

    // The types the type applies, in order: a name's arguments, an array's
    // element, a dictionary's key and value and an Optional's payload.
    // Anything else applies none.
    var arguments: [TypeSpelling] {
        switch self {
        case let .named(_, arguments):
            arguments

        case let .array(element):
            [element]

        case let .dictionary(key, value):
            [key, value]

        case let .optional(wrapped):
            [wrapped]

        case .member, .composition, .parameter, .inout, .variable, .procedure, .unsaidProcedure:
            []
        }
    }

    var isOptional: Bool {
        guard case .optional = self else { return false }

        return true
    }

    // The type an extension under this head gives members to, whose name a
    // member is spelled under: the name it applies, `Optional` for an
    // Optional, and for a type member after an applied type the type
    // member's spelling. A head that is no type's name extends none.
    var extendedType: String? {
        switch self {
        case let .named(name, _):
            name

        case .array:
            "Array"

        case .dictionary:
            "Dictionary"

        case let .member(applied, name):
            applied.extendedType.map { type in "\(type).\(name)" }

        case .optional:
            "Optional"

        case .composition, .parameter, .inout, .variable, .procedure, .unsaidProcedure:
            nil
        }
    }

    // The spelling of each type member the type names after an applied type:
    // the name the type applies and the type member's, with a dot between
    // them, `App.Wrapper.Item` of `App.Wrapper<String>.Item`.
    var typeMemberSpellings: Set<String> {
        switch self {
        case let .named(_, arguments):
            Self.typeMemberSpellings(in: arguments)

        case let .array(type), let .optional(type), let .inout(type), let .variable(type):
            type.typeMemberSpellings

        case let .dictionary(key, value):
            Self.typeMemberSpellings(in: [key, value])

        case let .member(applied, _):
            applied.typeMemberSpellings.union(extendedType.map { spelling in [spelling] } ?? [])

        case let .procedure(_, parameters, _, returns):
            Self.typeMemberSpellings(in: parameters + [returns])

        case .composition, .parameter, .unsaidProcedure:
            []
        }
    }

    // A type a `?` written straight after would stand inside, so its Optional
    // is written in parentheses: a procedure type, whose return type runs to
    // the end of the spelling, and a bounded type parameter, whose bound does.
    var isGrouped: Bool {
        switch self {
        case .procedure, .unsaidProcedure:
            true

        case let .parameter(_, bounds):
            !bounds.isEmpty

        case .named, .array, .dictionary, .member, .optional, .composition, .inout, .variable:
            false
        }
    }

    // MARK: - Initializer
    init(_ string: String) throws(AuthoringError) {
        var reader = TypeSpellingReader(string)

        self = try reader.read()
    }

    // MARK: - Public
    // The same type with every name of a type or a contract in it put through
    // `transform`: a name, an applied name, a composition's names and a
    // bound's. A type parameter's own name, a type member's name after an
    // applied type and a failure's are no type's.
    func mapTypeNames<Failure: Error>(
        _ transform: (String) throws(Failure) -> String
    ) throws(Failure) -> TypeSpelling {
        switch self {
        case let .named(name, arguments):
            let mapped = try arguments.map { type throws(Failure) in try type.mapTypeNames(transform) }

            return .named(try transform(name), arguments: mapped)

        case let .array(element):
            return .array(try element.mapTypeNames(transform))

        case let .dictionary(key, value):
            return .dictionary(key: try key.mapTypeNames(transform), value: try value.mapTypeNames(transform))

        case let .member(applied, name):
            return .member(try applied.mapTypeNames(transform), name: name)

        case let .optional(wrapped):
            return .optional(try wrapped.mapTypeNames(transform))

        case let .composition(names):
            return .composition(try names.map(transform))

        case let .parameter(name, bounds):
            return .parameter(name, bounds: try bounds.map(transform))

        case let .inout(type):
            return .inout(try type.mapTypeNames(transform))

        case let .variable(type):
            return .variable(try type.mapTypeNames(transform))

        case let .procedure(modifiers, parameters, failing, returns):
            return .procedure(
                modifiers: modifiers,
                parameters: try parameters.map { type throws(Failure) in try type.mapTypeNames(transform) },
                failing: failing,
                returns: try returns.mapTypeNames(transform)
            )

        case .unsaidProcedure:
            return self
        }
    }

    // The same type with each type parameter `types` holds a type for read as
    // that type: `some T` as the type, and `some T.Item` as the type's type
    // member `Item`. A type parameter it holds none for stands.
    func substituting(_ types: [String: TypeSpelling]) -> TypeSpelling {
        switch self {
        case let .named(name, arguments):
            .named(name, arguments: arguments.map { type in type.substituting(types) })

        case let .array(element):
            .array(element.substituting(types))

        case let .dictionary(key, value):
            .dictionary(key: key.substituting(types), value: value.substituting(types))

        case let .member(applied, name):
            .member(applied.substituting(types), name: name)

        case let .optional(wrapped):
            .optional(wrapped.substituting(types))

        case let .parameter(name, bounds):
            Self.substituted(name, bounds: bounds, by: types)

        case let .inout(type):
            .inout(type.substituting(types))

        case let .variable(type):
            .variable(type.substituting(types))

        case let .procedure(modifiers, parameters, failing, returns):
            .procedure(
                modifiers: modifiers,
                parameters: parameters.map { type in type.substituting(types) },
                failing: failing,
                returns: returns.substituting(types)
            )

        case .composition, .unsaidProcedure:
            self
        }
    }

    // MARK: - Private
    // A type parameter as the type `types` holds for it, its type member
    // where it names one after a dot, and itself where `types` holds none.
    private static func substituted(
        _ name: String,
        bounds: [String],
        by types: [String: TypeSpelling]
    ) -> TypeSpelling {
        if let type = types[name] { return type }

        guard
            let dot = name.firstIndex(of: "."),
            let type = types[String(name[..<dot])]
        else {
            return .parameter(name, bounds: bounds)
        }

        let member = String(name[name.index(after: dot)...])

        switch type {
        case let .named(owner, arguments: []):
            return .named("\(owner).\(member)", arguments: [])

        case let .parameter(owner, _):
            return .parameter("\(owner).\(member)", bounds: bounds)

        default:
            return .member(type, name: member)
        }
    }

    private static func joined(_ types: [TypeSpelling]) -> String {
        types.map(\.spelling).joined(separator: ", ")
    }

    private static func typeMemberSpellings(in types: [TypeSpelling]) -> Set<String> {
        types.reduce(into: []) { spellings, type in spellings.formUnion(type.typeMemberSpellings) }
    }

    private static func prefix(_ modifiers: [ProcedureModifier]) -> String {
        modifiers.map { modifier in "\(modifier.rawValue) " }.joined()
    }

    private static func clause(_ failing: ThrowsClause?) -> String {
        switch failing {
        case .none:
            ""

        case .anything:
            " throws"

        case let .names(names):
            " throws(\(names.joined(separator: ", ")))"
        }
    }
}
