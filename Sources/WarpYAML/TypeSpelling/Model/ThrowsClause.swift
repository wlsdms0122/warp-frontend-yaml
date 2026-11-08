//
//  ThrowsClause.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// What a procedure may fail with: anything, written `throws`, or the failures
// it lists, written `throws(…)` in the order written. A procedure that fails
// with nothing writes no clause.
enum ThrowsClause: Sendable, Hashable {
    case anything
    case names([String])
}
