//
//  Token.swift
//  Things3Utils
//
//  Created by A on 05/09/2024.
//

import Foundation
import SwiftData

@Model
class Token {
    
    var token: String
    
    init(token: String) {
        self.token = token
    }
    
    private var creationDate: Date = Date()
}
