//
//  CasesFormTests.swift
//  WarpYAMLTests
//
//  Created by JSilver on 9/22/26.
//

import Foundation
import Testing
import WarpYAML

// A conditional with several ways through, written flat and spent as the
// nested conditionals it is.
@Suite("The cases this notation spells")
struct CasesFormTests {
    // MARK: - Property
    private let sut: YAMLFrontend

    // MARK: - Initializer
    init() throws {
        self.sut = try YAMLFrontend()
    }

    // MARK: - Test
    @Test("cases are the conditionals they stand for, one inside the next")
    func casesNestOnePerArm() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            parameters: [ n: Int ]
            returns: String
            body:
              - var: said
                value: none
              - value:
                  cases:
                    - when: { of: { ref: n }, is: 1 }
                      then: [ { set: said, value: one } ]
                    - when: { of: { ref: n }, is: 2 }
                      then: [ { set: said, value: two } ]
                    - else: [ { set: said, value: many } ]
            result: { ref: said }
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: [ Standard.Logic.equal ]
        procedures:
          entry:
            parameters: [ { name: "n", type: Int } ]
            returns: String
            body:
              - { var: said, value: none }
              - value:
                  conditional:
                    else:
                      - value:
                          conditional:
                            else: [ { set: said, value: many } ]
                            then: [ { set: said, value: two } ]
                            when: { call: { procedure: Standard.Logic.equal, arguments: [ { ref: "n" }, 2 ] } }
                    then: [ { set: said, value: one } ]
                    when: { call: { procedure: Standard.Logic.equal, arguments: [ { ref: "n" }, 1 ] } }
              - { value: { return: { ref: said } } }
        """)
    }

    @Test("cases written with a name is written as the named conditional it is, for the load to refuse")
    func aNamedCasesIsWrittenThrough() throws {
        // Given / When
        let document = try sut.document(from: """
        procedures:
          entry:
            body:
              - let: picked
                value:
                  cases:
                    - when: true
                      then: [ { value: 1 } ]
        """)

        // Then
        try expectDocument(document, is: """
        warp: 1
        imports: []
        procedures:
          entry:
            body: [ { let: picked, value: { conditional: { then: [ { value: 1 } ], when: true } } } ]
        """)
    }

    @Test("cases with no case is refused")
    func noCaseIsRefused() {
        // Given / When / Then
        #expect(throws: TextRefused.self) {
            try sut.document(from: """
            procedures:
              entry:
                body:
                  - value:
                      cases:
                        - else: []
            """)
        }
    }

    // MARK: - Public
    // MARK: - Private
}
