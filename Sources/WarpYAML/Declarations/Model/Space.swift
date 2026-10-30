//
//  Space.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// Where a name is declared: among types and contracts, which share one
// space, or among procedures. A name may stand for a type and a procedure
// at once, one in each.
public enum Space: Sendable, Hashable {
    case type
    case procedure
}
