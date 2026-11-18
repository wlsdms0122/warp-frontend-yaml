//
//  ProcedureModifier.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

// A word a procedure type is written after, `const` or `isolated`.
enum ProcedureModifier: String, Sendable, Hashable {
    case const
    case isolated
}
