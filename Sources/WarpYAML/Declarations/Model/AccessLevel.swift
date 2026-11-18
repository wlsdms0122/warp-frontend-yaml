//
//  AccessLevel.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// Who may send a procedure: any document, the documents of its module, or
// its own document alone.
enum AccessLevel: String, Sendable, Hashable {
    case `public`
    case `internal`
    case `private`
}
