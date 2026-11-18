//
//  Refusal.swift
//  WarpYAMLTests
//
//  Created by JSilver on 11/3/26.
//

import Foundation
import Testing
@testable import WarpYAML

// Expects the Front to refuse what `spend` hands it with one refusal, and
// gives that refusal.
@discardableResult
func refusal<Spent>(
    sourceLocation: SourceLocation = #_sourceLocation,
    _ spend: () throws -> Spent
) -> AuthoringError? {
    let refused = #expect(throws: TextRefused.self, sourceLocation: sourceLocation) {
        _ = try spend()
    }

    #expect(refused?.refusals.count == 1, sourceLocation: sourceLocation)

    return refused?.refusals.first
}
