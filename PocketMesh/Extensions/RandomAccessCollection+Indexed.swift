import Foundation

/// A lightweight, allocation-free alternative to `Array(enumerated())` for SwiftUI `ForEach`.
///
/// Produces tuples of `(offset: Int, element: Element)` while retaining random-access
/// characteristics so SwiftUI can efficiently diff and render.
struct IndexedCollection<Base: RandomAccessCollection>: RandomAccessCollection where Base.Index == Int {
    let base: Base

    var startIndex: Int { base.startIndex }
    var endIndex: Int { base.endIndex }

    subscript(position: Int) -> (offset: Int, element: Base.Element) {
        (position - base.startIndex, base[position])
    }

    func index(after i: Int) -> Int {
        base.index(after: i)
    }

    func index(before i: Int) -> Int {
        base.index(before: i)
    }
}

extension RandomAccessCollection where Index == Int {
    func indexed() -> IndexedCollection<Self> {
        IndexedCollection(base: self)
    }
}
