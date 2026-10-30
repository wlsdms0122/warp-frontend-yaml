//
//  EachFormTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Testing
import WarpYAML

// A walk over an array, written as the walk and spent as the counter and the
// loop it is.
@Suite("The walk this notation spells")
struct EachFormTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("each is a loop reading each element at the walk's index, and the position beside it")
    func eachWalksEveryElement() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            parameters: [ names: Array<String> ]
            returns: Array<String>
            body:
              - var: seen
                type: Array<String>
                value: []
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: name
                    index: at
                    body:
                      - set: seen
                        value: { of: { ref: seen }, appending: { format: "${at}:${name}", with: { at: { ref: at }, name: { ref: name } } } }
            result: { ref: seen }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports:
          - Standard.Collection.appending
          - Standard.Collection.count
          - Standard.Comparable.lessThan
          - Standard.Text.joined
          - Standard.Text.text
        procedures:
          entry:
            access: public
            parameters: [ { name: names, type: "Array<String>" } ]
            returns: "Array<String>"
            body:
              - { var: seen, type: "Array<String>", value: [] }
              - value:
                  conditional:
                    then:
                      - { let: name, value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: name, value: { ref: "name[walk.index]" } }
                              - { let: at, value: { ref: walk.index } }
                              - set: seen
                                value:
                                  call:
                                    procedure: Standard.Collection.appending
                                    arguments:
                                      - { ref: seen }
                                      - call:
                                          procedure: Standard.Text.joined
                                          arguments:
                                            - [ { call: { procedure: Standard.Text.text, arguments: [ { ref: at } ] } }, ":", { call: { procedure: Standard.Text.text, arguments: [ { ref: name } ] } } ]
                                            - ""
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: name } ] } }
                    when: true
              - { value: { return: { ref: seen } } }
        """)
    }

    @Test("a continue is written into the loop's body as it is")
    func continueMovesOn() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            parameters: [ numbers: Array<Int> ]
            returns: Int
            body:
              - var: total
                value: 0
              - let: walk
                value:
                  each:
                    of: { ref: numbers }
                    as: n
                    body:
                      - value:
                          conditional:
                            when: { of: { ref: n }, less_than: 0 }
                            then: [ { value: { continue: null } } ]
                      - set: total
                        value: { of: { ref: total }, plus: { ref: n } }
            result: { ref: total }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.count, Standard.Comparable.lessThan, Standard.Numeric.plus ]
        procedures:
          entry:
            access: public
            parameters: [ { name: numbers, type: "Array<Int>" } ]
            returns: Int
            body:
              - { var: total, value: 0 }
              - value:
                  conditional:
                    then:
                      - { let: "n", value: { ref: numbers } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: "n", value: { ref: "n[walk.index]" } }
                              - value:
                                  conditional:
                                    then: [ { value: { continue: null } } ]
                                    when:
                                      call:
                                        procedure: Standard.Comparable.lessThan
                                        arguments: [ { ref: "n" }, 0 ]
                              - set: total
                                value:
                                  call:
                                    procedure: Standard.Numeric.plus
                                    arguments: [ { ref: total }, { ref: "n" } ]
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: "n" } ] } }
                    when: true
              - { value: { return: { ref: total } } }
        """)
    }

    @Test("the array is bound once before the loop, whatever the body sets")
    func theWalkReadsTheArrayOnce() throws {
        // Given / When. The body appends to the variable it walks
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            returns: Int
            body:
              - var: numbers
                type: Array<Int>
                value: [1, 2]
              - var: seen
                value: 0
              - let: walk
                value:
                  each:
                    of: { ref: numbers }
                    as: n
                    body:
                      - set: numbers
                        value: { of: { ref: numbers }, appending: { ref: n } }
                      - set: seen
                        value: { of: { ref: seen }, plus: 1 }
            result: { ref: seen }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports:
          - Standard.Collection.appending
          - Standard.Collection.count
          - Standard.Comparable.lessThan
          - Standard.Numeric.plus
        procedures:
          entry:
            access: public
            returns: Int
            body:
              - { var: numbers, type: "Array<Int>", value: [ 1, 2 ] }
              - { var: seen, value: 0 }
              - value:
                  conditional:
                    then:
                      - { let: "n", value: { ref: numbers } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: "n", value: { ref: "n[walk.index]" } }
                              - set: numbers
                                value:
                                  call:
                                    procedure: Standard.Collection.appending
                                    arguments: [ { ref: numbers }, { ref: "n" } ]
                              - set: seen
                                value: { call: { procedure: Standard.Numeric.plus, arguments: [ { ref: seen }, 1 ] } }
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: "n" } ] } }
                    when: true
              - { value: { return: { ref: seen } } }
        """)
    }

    @Test("the loop is bound under the walk's name, which the body reads its round by")
    func theLoopTakesTheWalksName() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            parameters: [ names: Array<String> ]
            failing: [aborted]
            body:
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: name
                    body:
                      - value:
                          conditional:
                            when: { of: { ref: name }, is: "b" }
                            then: [ { value: { abort: { ref: name } } } ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports:
          - Standard.Collection.count
          - Standard.Comparable.lessThan
          - Standard.Control.abort
          - Standard.Logic.equal
        procedures:
          entry:
            access: public
            parameters: [ { name: names, type: "Array<String>" } ]
            failing: [ aborted ]
            body:
              - value:
                  conditional:
                    then:
                      - { let: name, value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: name, value: { ref: "name[walk.index]" } }
                              - value:
                                  conditional:
                                    then:
                                      - value:
                                          call: { procedure: Standard.Control.abort, arguments: [ { ref: name } ] }
                                    when:
                                      call: { procedure: Standard.Logic.equal, arguments: [ { ref: name }, b ] }
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: name } ] } }
                    when: true
        """)
    }

    @Test("a walk is an arm holding the array and the loop over it")
    func aWalkIsAnArmAndALoop() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            parameters: [ names: Array<String> ]
            body:
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: name
                    body: []
        """)

        // Then. In an arm that always runs, the array is bound once under the
        // element's name, and the loop is bound under the statement's name and
        // reads its own round. Nothing else is declared
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.count, Standard.Comparable.lessThan ]
        procedures:
          entry:
            parameters: [ { name: names, type: "Array<String>" } ]
            body:
              - value:
                  conditional:
                    then:
                      - { let: name, value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            body: [ { let: name, value: { ref: "name[walk.index]" } } ]
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: name } ] } }
                    when: true
        """)
    }

    @Test("a walk under a statement that introduces no name is refused", arguments: [
        "value",
        "set: names\n        value"
    ])
    func aNamelessWalkIsRefused(statement: String) {
        // Given / When / Then. A `set` writes a name and introduces none
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ names: Array<String> ]
                body:
                  - \(statement):
                      each:
                        of: { ref: names }
                        as: name
                        body: []
            """)
        } throws: { error in
            "\(error)".contains("each is named")
        }
    }

    @Test("the element and the position take two names")
    func oneNameForBothIsRefused() {
        // Given / When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ names: Array<String> ]
                body:
                  - let: walk
                    value:
                      each:
                        of: { ref: names }
                        as: index
                        index: index
                        body: []
            """)
        } throws: { error in
            "\(error)".contains("separate names") && "\(error)".contains("'index'")
        }
    }

    @Test("the element is any name a path reads")
    func theElementIsAValueName() throws {
        // Given / When. A name a `let` may take, the walk may bind
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            parameters: [ names: Array<String> ]
            returns: Array<String>
            body:
              - var: seen
                type: Array<String>
                value: []
              - let: walk
                value:
                  each:
                    of: { ref: names }
                    as: café
                    body:
                      - set: seen
                        value: { of: { ref: seen }, appending: { ref: café } }
            result: { ref: seen }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Collection.appending, Standard.Collection.count, Standard.Comparable.lessThan ]
        procedures:
          entry:
            access: public
            parameters: [ { name: names, type: "Array<String>" } ]
            returns: "Array<String>"
            body:
              - { var: seen, type: "Array<String>", value: [] }
              - value:
                  conditional:
                    then:
                      - { let: "café", value: { ref: names } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: "café", value: { ref: "café[walk.index]" } }
                              - set: seen
                                value:
                                  call:
                                    procedure: Standard.Collection.appending
                                    arguments: [ { ref: seen }, { ref: "café" } ]
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: "café" } ] } }
                    when: true
              - { value: { return: { ref: seen } } }
        """)

        // And one no path reaches is refused
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ names: Array<String> ]
                body:
                  - let: walk
                    value:
                      each:
                        of: { ref: names }
                        as: a.b
                        body: []
            """)
        } throws: { error in
            "\(error)".contains("'a.b' is no name a path reads") && "\(error)".hasPrefix("9:13: ")
        }
    }

    @Test("the element may not be called what the walk is called")
    func anElementNamedLikeTheWalkIsRefused() {
        // Given / When / Then
        #expect {
            try sut.document(from: """
            procedures:
              entry:
                parameters: [ names: Array<String> ]
                body:
                  - let: walk
                    value:
                      each:
                        of: { ref: names }
                        as: walk
                        body: []
            """)
        } throws: { error in
            "\(error)".contains("separate names")
        }
    }

    @Test("each binds what `of` computes once, before the loop")
    func eachWalksAComputedArray() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            access: public
            parameters: [ text: String ]
            returns: String
            body:
              - var: backwards
                value: ""
              - let: walk
                value:
                  each:
                    of: { characters: { ref: text } }
                    as: ch
                    body:
                      - set: backwards
                        value: { format: "${ch}${rest}", with: { ch: { ref: ch }, rest: { ref: backwards } } }
            result: { ref: backwards }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports:
          - Standard.Collection.count
          - Standard.Comparable.lessThan
          - Standard.Text.characters
          - Standard.Text.joined
          - Standard.Text.text
        procedures:
          entry:
            access: public
            parameters: [ { name: text, type: String } ]
            returns: String
            body:
              - { var: backwards, value: "" }
              - value:
                  conditional:
                    then:
                      - let: ch
                        value: { call: { procedure: Standard.Text.characters, arguments: [ { ref: text } ] } }
                      - let: walk
                        value:
                          loop:
                            body:
                              - { let: ch, value: { ref: "ch[walk.index]" } }
                              - set: backwards
                                value:
                                  call:
                                    procedure: Standard.Text.joined
                                    arguments:
                                      - [ { call: { procedure: Standard.Text.text, arguments: [ { ref: ch } ] } }, { call: { procedure: Standard.Text.text, arguments: [ { ref: backwards } ] } } ]
                                      - ""
                            while:
                              call:
                                procedure: Standard.Comparable.lessThan
                                arguments:
                                  - { ref: walk.index }
                                  - { call: { procedure: Standard.Collection.count, arguments: [ { ref: ch } ] } }
                    when: true
              - { value: { return: { ref: backwards } } }
        """)
    }

    // MARK: - Public
    // MARK: - Private
}
