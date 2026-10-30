//
//  ExpressionSugarTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
import Testing
@testable import WarpYAML

@Suite("The expression shorthands a text writes, spent into the calls they stand for")
struct ExpressionSugarTests {
    // MARK: - Property
    private let parser = YAMLParser()

    // MARK: - Initializer
    // MARK: - Test
    @Test("an operator mapping is the call of the procedure its key reaches", arguments: [
        ("{ of: { ref: a }, plus: 1 }", "{ call: { procedure: Standard.Numeric.plus, arguments: [ { ref: a }, 1 ] } }"),
        ("{ count: { ref: xs } }", "{ call: { procedure: Standard.Collection.count, arguments: [ { ref: xs } ] } }"),
        ("{ of: { ref: x }, one_of: [ 1, 2 ] }", "{ call: { procedure: Standard.Collection.contains, arguments: [ [ 1, 2 ], { ref: x } ] } }"),
        ("{ present: { ref: a } }", "{ call: { procedure: Standard.Logic.notEqual, arguments: [ { ref: a }, null ] } }"),
        ("{ of: { ref: x }, Lib.has: 1 }", "{ call: { procedure: Lib.has, arguments: [ { ref: x }, 1 ] } }"),
        (
            "{ not: { of: { ref: a }, is: { count: { ref: b } } } }",
            "{ call: { procedure: Standard.Logic.not, arguments: [ { call: { procedure: Standard.Logic.equal, arguments:"
                + " [ { ref: a }, { call: { procedure: Standard.Collection.count, arguments: [ { ref: b } ] } } ] } } ] } }"
        )
    ])
    func anOperatorMappingIsACall(written: String, spent: String) throws {
        // Given / When / Then
        #expect(try self.spent(written) == (try parser.parse(document(holding: spent))))
    }

    @Test("a closure an operator mapping holds has its statement shorthands spent in the same walk")
    func aClosureInAMappingIsSpentInOneWalk() throws {
        // Given
        let text = try parser.parse(text(holding: """
        { of: { ref: xs }, map: { closure: { parameters: [ s: String ], result: { of: { ref: s }, plus: 1 } } } }
        """))
        let naming = try Naming(of: text, leaningOn: Declarations())

        // When
        let spent = try Grammar().rewriting(
            try naming.prefixed(text),
            [StatementSugar().rewritten, ExpressionSugar(reading: naming).rewritten]
        )

        // Then
        #expect(spent == (try parser.parse(document(holding: """
        { call: { procedure: Standard.Collection.map, arguments: [ { ref: xs }, { closure: {
          parameters: [ { name: s, type: String } ],
          body: [ { value: { return: { call: { procedure: Standard.Numeric.plus, arguments: [ { ref: s }, 1 ] } } } } ]
        } } ] } }
        """))))
    }

    @Test("a connective's sides are each a closure returning it, its signature left to its slot")
    func aConnectivesSidesAreClosures() throws {
        // Given
        let side = "body: [ { value: { return: { ref: a } } } ]"

        // When / Then
        #expect(try spent("{ all_of: [ { ref: a } ] }") == (try parser.parse(document(holding: """
        { call: { procedure: Standard.Logic.and, arguments: [ [ { closure: { \(side) } } ] ] } }
        """))))
        #expect(try spent("{ try_any_of: [ { ref: a } ] }") == (try parser.parse(document(holding: """
        { call: { procedure: Standard.Logic.tryOr, arguments: [ [ { closure: { \(side) } } ] ] } }
        """))))
    }

    @Test("a key the text declares a procedure by reaches that procedure, the text's own by its full name")
    func aDeclaredKeyReachesTheDeclaration() throws {
        // Given / When / Then
        #expect(try spent("{ shout: { ref: a } }", declaring: "shout: {}") == (try parser.parse(document(holding: """
        { call: { procedure: App.shout, arguments: [ { ref: a } ] } }
        """, declaring: "App.shout: {}"))))
        #expect(try spent("{ of: { ref: a }, count: 1 }", declaring: "count: {}") == (try parser.parse(document(holding: """
        { call: { procedure: App.count, arguments: [ { ref: a }, 1 ] } }
        """, declaring: "App.count: {}"))))
    }

    @Test("a mapping that is no shorthand is left as written")
    func aMappingThatIsNoShorthandIsLeft() throws {
        // Given / When / Then. A form of the document, a key nothing names, and
        // a form's key beside others are the load's
        for written in ["{ ref: a }", "{ shout: 1 }", "{ of: 1, call: {} }"] {
            #expect(try spent(written) == (try parser.parse(document(holding: written))))
        }
    }

    @Test("an empty mapping is an empty dictionary wherever a value is wanted", arguments: [
        ("{}", "{ dictionary: [] }"),
        ("[ {}, 1 ]", "[ { dictionary: [] }, 1 ]"),
        ("{ struct: { env: {} } }", "{ struct: { env: { dictionary: [] } } }"),
        ("{ dictionary: [ [ a, {} ] ] }", "{ dictionary: [ [ a, { dictionary: [] } ] ] }"),
        ("{ of: { ref: a }, plus: {} }", "{ call: { procedure: Standard.Numeric.plus, arguments: [ { ref: a }, { dictionary: [] } ] } }")
    ])
    func anEmptyMappingIsAnEmptyDictionary(written: String, spent: String) throws {
        // Given / When / Then
        #expect(try self.spent(written) == (try parser.parse(document(holding: spent))))
    }

    @Test("an operator mapping written out of shape is refused at the mapping", arguments: [
        (
            "{ of: 1, plus: 2, minus: 3 }",
            "an operator mapping is one operator, with or without its subject."
                + " { of: <expression>, <operator>: <expression> } or { <operator>: <expression> };"
                + " found: [\"minus\", \"plus\"]"
        ),
        ("{ plus: 1 }", "plus needs a subject. { of: <expression>, plus: <expression> }"),
        ("{ of: 1, count: 2 }", "`of` does not accompany count. It takes what is written under it, not a subject"),
        ("{ all_of: 1 }", "all_of takes a list of expressions")
    ])
    func anOperatorMappingOutOfShapeIsRefused(written: String, message: String) throws {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try spent(written)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position != nil)
    }

    @Test("a key both the table's and a declaration's is refused where the text does not say which")
    func aKeyBothTheTablesAndADeclarationsIsRefused() throws {
        // Given / When
        let alone = #expect(throws: AuthoringError.self) {
            try spent("{ count: 1 }", declaring: "count: {}")
        }
        let connective = #expect(throws: AuthoringError.self) {
            try spent("{ all_of: [] }", declaring: "all_of: {}")
        }

        // Then
        #expect(alone?.message == "'count' alone is this notation's operator, and 'App.count' is declared by that name"
            + " too. Call the declared one with `call`, or write the operator beside `of`")
        #expect(connective?.message == "all_of is this notation's spelling. Write the declared 'App.all_of' by its full name")
    }

    @Test("a template is the text pieces and the values it reads, joined", arguments: [
        ("{ format: plain }", "plain"),
        ("{ format: \"costs $$1\" }", "costs $1"),
        (
            "{ format: \"hi ${n}!\", with: { n: { ref: name } } }",
            "{ call: { procedure: Standard.Text.joined, arguments: [ [ \"hi \","
                + " { call: { procedure: Standard.Text.text, arguments: [ { ref: name } ] } }, \"!\" ], \"\" ] } }"
        ),
        (
            "{ format: \"${u.name}\", with: { u: { ref: user } } }",
            "{ call: { procedure: Standard.Text.joined, arguments: [ [ { call: { procedure: Standard.Text.text,"
                + " arguments: [ { ref: user.name } ] } } ], \"\" ] } }"
        ),
        (
            "{ format: \"${xs[i]?.v}\", with: { xs: { ref: items }, i: { ref: k } } }",
            "{ call: { procedure: Standard.Text.joined, arguments: [ [ { call: { procedure: Standard.Text.text,"
                + " arguments: [ { ref: \"items[k]?.v\" } ] } } ], \"\" ] } }"
        ),
        (
            "{ format: \"${n}\", with: { n: { of: 1, plus: 2 } } }",
            "{ call: { procedure: Standard.Text.joined, arguments: [ [ { call: { procedure: Standard.Text.text,"
                + " arguments: [ { call: { procedure: Standard.Numeric.plus, arguments: [ 1, 2 ] } } ] } } ], \"\" ] } }"
        )
    ])
    func aTemplateIsJoined(written: String, spent: String) throws {
        // Given / When / Then
        #expect(try self.spent(written) == (try parser.parse(document(holding: spent))))
    }

    @Test("a mapping of one template key is a template, whatever the text declares by that name")
    func aTemplateKeyIsATemplate() throws {
        // Given / When / Then
        #expect(try spent("{ format: hello }", declaring: "format: {}") == (try parser.parse(document(
            holding: "hello",
            declaring: "App.format: {}"
        ))))
    }

    @Test("a template written out of shape is refused", arguments: [
        ("{ with: {} }", "`with` only accompanies `format` (found keys: [\"with\"])"),
        ("{ format: a, size: 1 }", "a mapping with `format` holds `format`, the template, and `with`, its bindings,"
            + " and nothing else (found keys: [\"format\", \"size\"])"),
        ("{ format: 1 }", "`format` takes a template string"),
        ("{ format: a, with: [] }", "`format`'s `with` takes a mapping of bindings"),
        ("{ format: \"${n}\" }", "`format`'s placeholder ${n} names no binding this template was given"),
        (
            "{ format: \"${n.v}\", with: { n: 1 } }",
            "`format`'s placeholder ${n.v} drills into 'n', which is bound to something other than a name"
        ),
        (
            "{ format: \"${xs[i]}\", with: { xs: { ref: a }, i: 1 } }",
            "`format`'s index ${i} is bound to something other than a name, and an index reads a name"
        )
    ])
    func aTemplateOutOfShapeIsRefused(written: String, message: String) throws {
        // Given / When
        let error = #expect(throws: AuthoringError.self) {
            try spent(written)
        }

        // Then
        #expect(error?.message == message)
        #expect(error?.position != nil)
    }

    // MARK: - Public
    // MARK: - Private
    // A text named `App` declaring `declaring` beside `f`, whose body is one
    // statement of `expression`.
    private func text(holding expression: String, declaring: String = "") -> String {
        """
        name: App
        procedures: { \(declaring.isEmpty ? "" : "\(declaring), ")f: { body: [ { value: \(expression) } ] } }
        """
    }

    // The same, as the document names it.
    private func document(holding expression: String, declaring: String = "") -> String {
        """
        procedures: { \(declaring.isEmpty ? "" : "\(declaring), ")App.f: { body: [ { value: \(expression) } ] } }
        """
    }

    private func spent(_ expression: String, declaring: String = "") throws -> Tree {
        let text = try parser.parse(text(holding: expression, declaring: declaring))
        let naming = try Naming(of: text, leaningOn: Declarations())

        return try ExpressionSugar(reading: naming).spent(try naming.prefixed(text))
    }
}
