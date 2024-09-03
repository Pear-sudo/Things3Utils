//
//  AccessibleIndicator.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import OSLog

struct AccessibilityIndicator: View {
    private let logger = Logger(subsystem: "cyou.b612.things3.views", category: "AccessibilityIndicator")
    
    var url: URL?
    var body: some View {
        if url == nil {
            EmptyView()
        } else {
            if testURLAccessibility() {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "x.circle")
                    .foregroundStyle(.red)
            }
        }
    }
    
    private func testURLAccessibility() -> Bool {
        guard let url else {
            return false
        }
        guard !FileManager.default.isReadableFile(atPath: url.p) else {
            logger.log("File is directly readable: \(url.p)")
            return true
        }
        logger.log("File cannot be read directly, will try using security scope: \(url.p)")
        let gotAccess =  url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        return gotAccess
    }
}

#Preview {
    AccessibilityIndicator(url: .currentDirectory())
}
