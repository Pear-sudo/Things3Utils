//
//  URL.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import Foundation

extension URL {
    /// call path() with percentEncoded set to false
    var p: String {
        self.path(percentEncoded: false)
    }
}
