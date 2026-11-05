//
//  Declarations+Standard.swift
//  WarpYAML
//
//  Created by JSilver on 10/26/26.
//

import Foundation

extension Declarations {
    // `Standard`'s interface as the IR holds it, byte for byte:
    // `lib/standard/interface/standard.interface.warpt` in the `warp`
    // submodule. A test holds the two equal.
    static let standardInterface = #"""
    (interface 1)

    (contract Standard.Collection
      (procedure count
        (const)
        (isolated)
        (parameter collection (type Self))
        (returns Int)))

    (contract Standard.Comparable
      (procedure lessThan
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Bool)))

    (contract Standard.Numeric
      (procedure dividedBy
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Double))
      (procedure minus
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Self))
      (procedure plus
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Self))
      (procedure remainder
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Self))
      (procedure times
        (const)
        (isolated)
        (parameter lhs (type Self))
        (parameter rhs (type Self))
        (returns Self)))

    (extension
      (head Array)
      (satisfies Standard.Collection)
      (procedure count
        (const)
        (isolated)
        (parameter collection (type (array Any)))
        (returns Int)))

    (extension
      (head Dictionary)
      (satisfies Standard.Collection)
      (procedure count
        (const)
        (isolated)
        (parameter collection (type (dictionary (some Key Hashable) Any)))
        (returns Int)))

    (extension
      (head Double)
      (satisfies Standard.Comparable Standard.Numeric)
      (procedure dividedBy
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Double))
      (procedure lessThan
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Bool))
      (procedure minus
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Double))
      (procedure plus
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Double))
      (procedure remainder
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Double))
      (procedure times
        (const)
        (isolated)
        (parameter lhs (type Double))
        (parameter rhs (type Double))
        (returns Double)))

    (extension
      (head Int)
      (satisfies Standard.Comparable Standard.Numeric)
      (procedure dividedBy
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Double))
      (procedure lessThan
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Bool))
      (procedure minus
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Int))
      (procedure plus
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Int))
      (procedure remainder
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Int))
      (procedure times
        (const)
        (isolated)
        (parameter lhs (type Int))
        (parameter rhs (type Int))
        (returns Int)))

    (extension
      (head String)
      (satisfies Standard.Collection Standard.Comparable)
      (procedure count
        (const)
        (isolated)
        (parameter collection (type String))
        (returns Int))
      (procedure lessThan
        (const)
        (isolated)
        (parameter lhs (type String))
        (parameter rhs (type String))
        (returns Bool)))

    (procedure Standard.Collection.append
      (isolated)
      (parameter array (type (inout (array (some Element)))))
      (parameter element (type (some Element))))

    (procedure Standard.Collection.appending
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter element (type (some Element)))
      (returns (array (some Element))))

    (procedure Standard.Collection.contains
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter element (type (some Element)))
      (returns Bool))

    (procedure Standard.Collection.dropFirst
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (returns (array (some Element))))

    (procedure Standard.Collection.dropLast
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (returns (array (some Element))))

    (procedure Standard.Collection.filter
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter isIncluded (type (procedure (const) (isolated) (parameters (some Element)) (returns Bool))))
      (returns (array (some Element))))

    (procedure Standard.Collection.first
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (returns (optional (some Element))))

    (procedure Standard.Collection.gathering
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter positions (type (array Int)))
      (returns (array (some Element))))

    (procedure Standard.Collection.keys
      (const)
      (isolated)
      (parameter dictionary (type (dictionary (some Key Hashable) Any)))
      (returns (array (some Key))))

    (procedure Standard.Collection.last
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (returns (optional (some Element))))

    (procedure Standard.Collection.map
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (returns (some Result)))))
      (returns (array (some Result))))

    (procedure Standard.Collection.prepending
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter element (type (some Element)))
      (returns (array (some Element))))

    (procedure Standard.Collection.reduce
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter initialResult (type (some Carried)))
      (parameter nextPartialResult (type (procedure (const) (isolated) (parameters (some Carried) (some Element)) (returns (some Carried)))))
      (returns (some Carried)))

    (procedure Standard.Collection.reversed
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (returns (array (some Element))))

    (procedure Standard.Collection.setting
      (const)
      (isolated)
      (parameter dictionary (type (dictionary (some Key Hashable) (some Value))))
      (parameter key (type (some Key)))
      (parameter value (type (some Value)))
      (returns (dictionary (some Key) (some Value))))

    (procedure Standard.Collection.sorted
      (const)
      (isolated)
      (parameter array (type (array (some Element Standard.Comparable))))
      (returns (array (some Element))))

    (procedure Standard.Collection.tryFilter
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter isIncluded (type (procedure (const) (isolated) (parameters (some Element)) (failing (anything)) (returns Bool))))
      (returns (array (some Element)))
      (failing (anything)))

    (procedure Standard.Collection.tryMap
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter transform (type (procedure (const) (isolated) (parameters (some Element)) (failing (anything)) (returns (some Result)))))
      (returns (array (some Result)))
      (failing (anything)))

    (procedure Standard.Collection.tryReduce
      (const)
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter initialResult (type (some Carried)))
      (parameter nextPartialResult (type (procedure (const) (isolated) (parameters (some Carried) (some Element)) (failing (anything)) (returns (some Carried)))))
      (returns (some Carried))
      (failing (anything)))

    (procedure Standard.Collection.values
      (const)
      (isolated)
      (parameter dictionary (type (dictionary (some Key Hashable) (some Entry))))
      (returns (array (some Entry))))

    (procedure Standard.Concurrent.all
      (isolated)
      (parameter pieces (type (array (procedure (isolated) (parameters) (failing (anything)) (returns (some Result))))))
      (returns (array (some Result)))
      (failing concurrent_failed))

    (procedure Standard.Concurrent.allKeyed
      (isolated)
      (parameter pieces (type (dictionary (some Key Hashable) (procedure (isolated) (parameters) (failing (anything)) (returns (some Result))))))
      (returns (dictionary (some Key) (some Result)))
      (failing concurrent_failed))

    (procedure Standard.Concurrent.first
      (isolated)
      (parameter pieces (type (array (procedure (isolated) (parameters) (failing (anything)) (returns (some Result))))))
      (returns (some Result))
      (failing concurrent_failed))

    (procedure Standard.Concurrent.firstKeyed
      (isolated)
      (parameter pieces (type (dictionary (some Key Hashable) (procedure (isolated) (parameters) (failing (anything)) (returns (some Result))))))
      (returns (some Result))
      (failing concurrent_failed))

    (procedure Standard.Concurrent.map
      (isolated)
      (parameter array (type (array (some Element))))
      (parameter transform (type (procedure (isolated) (parameters (some Element) Int) (failing (anything)) (returns (some Result)))))
      (returns (array (some Result)))
      (failing concurrent_failed))

    (procedure Standard.Control.abort
      (const)
      (isolated)
      (parameter message)
      (returns Never)
      (failing aborted))

    (procedure Standard.Logic.and
      (const)
      (isolated)
      (parameter conditions (type (array (procedure (const) (isolated) (parameters) (returns Bool)))))
      (returns Bool))

    (procedure Standard.Logic.equal
      (const)
      (isolated)
      (parameter lhs)
      (parameter rhs)
      (returns Bool))

    (procedure Standard.Logic.not
      (const)
      (isolated)
      (parameter value (type Bool))
      (returns Bool))

    (procedure Standard.Logic.notEqual
      (const)
      (isolated)
      (parameter lhs)
      (parameter rhs)
      (returns Bool))

    (procedure Standard.Logic.or
      (const)
      (isolated)
      (parameter conditions (type (array (procedure (const) (isolated) (parameters) (returns Bool)))))
      (returns Bool))

    (procedure Standard.Logic.select
      (const)
      (isolated)
      (parameter condition (type Bool))
      (parameter then (type (procedure (const) (isolated) (parameters) (returns (some Result)))))
      (parameter else (type (procedure (const) (isolated) (parameters) (returns (some Result)))))
      (returns (some Result)))

    (procedure Standard.Logic.tryAnd
      (const)
      (isolated)
      (parameter conditions (type (array (procedure (const) (isolated) (parameters) (failing (anything)) (returns Bool)))))
      (returns Bool)
      (failing (anything)))

    (procedure Standard.Logic.tryOr
      (const)
      (isolated)
      (parameter conditions (type (array (procedure (const) (isolated) (parameters) (failing (anything)) (returns Bool)))))
      (returns Bool)
      (failing (anything)))

    (procedure Standard.Logic.trySelect
      (const)
      (isolated)
      (parameter condition (type Bool))
      (parameter then (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Result)))))
      (parameter else (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Result)))))
      (returns (some Result))
      (failing (anything)))

    (procedure Standard.Math.absolute
      (const)
      (isolated)
      (parameter number (type (some N Standard.Comparable Standard.Numeric)))
      (returns (some N)))

    (procedure Standard.Math.floored
      (const)
      (isolated)
      (parameter number (type Double))
      (returns Int))

    (procedure Standard.Math.greaterThan
      (const)
      (isolated)
      (parameter lhs (type (some T Standard.Comparable)))
      (parameter rhs (type (some T)))
      (returns Bool))

    (procedure Standard.Math.max
      (const)
      (isolated)
      (parameter lhs (type (some T Standard.Comparable)))
      (parameter rhs (type (some T)))
      (returns (some T)))

    (procedure Standard.Math.min
      (const)
      (isolated)
      (parameter lhs (type (some T Standard.Comparable)))
      (parameter rhs (type (some T)))
      (returns (some T)))

    (procedure Standard.Math.rounded
      (const)
      (isolated)
      (parameter number (type Double))
      (returns Int))

    (procedure Standard.Optional.tryUnwrapped
      (const)
      (isolated)
      (parameter optional (type (optional (some Wrapped))))
      (parameter else (type (procedure (const) (isolated) (parameters) (failing (anything)) (returns (some Wrapped)))))
      (returns (some Wrapped))
      (failing (anything)))

    (procedure Standard.Optional.unwrapped
      (const)
      (isolated)
      (parameter optional (type (optional (some Wrapped))))
      (parameter else (type (procedure (const) (isolated) (parameters) (returns (some Wrapped)))))
      (returns (some Wrapped)))

    (procedure Standard.Text.characters
      (const)
      (isolated)
      (parameter text (type String))
      (returns (array String)))

    (procedure Standard.Text.contains
      (const)
      (isolated)
      (parameter text (type String))
      (parameter other (type String))
      (returns Bool))

    (procedure Standard.Text.decoded
      (const)
      (isolated)
      (parameter bytes (type (array Int)))
      (parameter encoding (type String))
      (returns String))

    (procedure Standard.Text.encoded
      (const)
      (isolated)
      (parameter text (type String))
      (parameter encoding (type String))
      (returns (array Int)))

    (procedure Standard.Text.joined
      (const)
      (isolated)
      (parameter strings (type (array String)))
      (parameter separator (type String))
      (returns String))

    (procedure Standard.Text.lowercased
      (const)
      (isolated)
      (parameter text (type String))
      (returns String))

    (procedure Standard.Text.replacing
      (const)
      (isolated)
      (parameter text (type String))
      (parameter target (type String))
      (parameter replacement (type String))
      (returns String)
      (failing aborted))

    (procedure Standard.Text.split
      (const)
      (isolated)
      (parameter text (type String))
      (parameter separator (type String))
      (returns (array String))
      (failing aborted))

    (procedure Standard.Text.startsWith
      (const)
      (isolated)
      (parameter text (type String))
      (parameter prefix (type String))
      (returns Bool))

    (procedure Standard.Text.text
      (const)
      (isolated)
      (parameter value)
      (returns String))

    (procedure Standard.Text.trimmed
      (const)
      (isolated)
      (parameter text (type String))
      (returns String))

    (procedure Standard.Text.uppercased
      (const)
      (isolated)
      (parameter text (type String))
      (returns String))

    """#

    // `Standard`'s declarations, read from its interface.
    static func standard() throws -> Declarations {
        try Declarations().adding(InterfaceReader().read(Data(standardInterface.utf8)))
    }
}
