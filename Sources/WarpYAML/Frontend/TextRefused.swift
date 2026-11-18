//
//  TextRefused.swift
//  WarpYAML
//
//  Created by JSilver on 11/3/26.
//

import Foundation

// What the Front refuses the texts handed to it with: every refusal it
// finds, once each, by the text each stands in and then by position. Declarations
// that do not read are refused alone, since every body reads them. Once
// they read, each procedure body is read on its own, and each body refused
// says why.
public struct TextRefused: Error, Sendable, Equatable, CustomStringConvertible {
    // MARK: - Property
    public let refusals: [AuthoringError]

    public var description: String {
        refusals.map(\.description).joined(separator: "\n")
    }

    // MARK: - Initializer
    init(_ refusals: [AuthoringError]) {
        let distinct = refusals.reduce(into: [AuthoringError]()) { distinct, refusal in
            if !distinct.contains(refusal) {
                distinct.append(refusal)
            }
        }

        self.refusals = distinct.sorted { first, second in
            let firstSpot = Self.spot(of: first)
            let secondSpot = Self.spot(of: second)

            guard firstSpot != secondSpot else { return first.message < second.message }

            return firstSpot.lexicographicallyPrecedes(secondSpot)
        }
    }

    // MARK: - Public
    // MARK: - Private
    // Where a refusal stands, to order by: a text alone before texts handed
    // together, and a refusal of a spot before one of no spot.
    private static func spot(of refusal: AuthoringError) -> [Int] {
        let position = refusal.position.map { position in [position.line, position.column] } ?? [Int.max, Int.max]

        return [refusal.text ?? -1] + position
    }
}
