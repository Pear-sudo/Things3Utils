//
//  IntervalTree.swift
//  Things3Utils
//
//  Created by A on 04/09/2024.
//

import Foundation
import OSLog

fileprivate let logger = Logger(subsystem: "cyou.b612.things3.algorithms", category: "IntervalTree")

class IntervalTree<T> where T: Comparable {
    
    /// For small datasets, the costs of constructing red black tree and interval tree might be overkilling
    var optimizationOn: Bool = true
    
    init(ranges: [ClosedRange<T>]) {
        self.ranges = ranges
    }
    
    private let ranges: [ClosedRange<T>]
    private let optimizationThreshold = 3
    
    func has(_ element: T) -> Bool {
        if optimizationOn && ranges.count <= optimizationThreshold {
            return naiveHas(element)
        }
        logger.error("has() is not complete")
        return true
    }
    
    @inline(__always)
    private func naiveHas(_ element: T) -> Bool {
        for range in ranges {
            if range.contains(element) {
                return true
            }
        }
        return false
    }
}
