//
//  LargeStack.swift
//  WarpYAMLTests
//
//  Created by JSilver on 10/26/26.
//

import Foundation
@testable import WarpYAML

// What `read` gives on a thread of the stack a spend runs on, for a part of
// the front end read on its own. A debug build's frames over a text nested
// to the bound outgrow a test's own thread.
func onALargeStack<Read: Sendable>(
    _ read: @escaping @Sendable () throws -> Read
) async -> Result<Read, any Error> {
    await withCheckedContinuation { continuation in
        let thread = Thread {
            continuation.resume(returning: Result { try read() })
        }

        thread.stackSize = SpendingThread.stackSize
        thread.start()
    }
}
