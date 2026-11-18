//
//  Atom.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// An atom of the text's first layer, by the kind its first characters say.
enum Atom: Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case bytes([UInt8])
    // A name, written bare or in backticks.
    case name(String)
}
