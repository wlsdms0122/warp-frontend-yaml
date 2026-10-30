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

    var isOptional: Bool {
        guard case .optional = self else { return false }

        return true
    }

    // The type an extension under this head gives members to, whose name a
    // member is spelled under: the name it applies, and `Optional` for an
    // Optional. A head that is no type's name extends none.
    var extendedType: String? {
        switch self {
        case let .named(name, _):
            name

        case .array:
            "Array"

        case .dictionary:
            "Dictionary"

        case .optional:
            "Optional"

        case .composition, .parameter, .inout, .variable, .procedure, .unsaidProcedure:
            nil
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

        case .named, .array, .dictionary, .optional, .composition, .inout, .variable:
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
    // bound's. A type parameter's own name and a failure's are no type's.
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

    // MARK: - Private
    private static func joined(_ types: [TypeSpelling]) -> String {
        types.map(\.spelling).joined(separator: ", ")
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
