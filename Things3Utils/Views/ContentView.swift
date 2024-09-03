//
//  ContentView.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import OSLog

struct ContentView: View {
    @State private var url: URL?
    
    private let logger = Logger(subsystem: "cyou.b612.things3.views", category: "MainView")

    var body: some View {
        VStack {
            ImportArea(url: $url)
            if let url {
                PDFViewer(url: url)
            }
            Spacer()
        }
        .padding()
    }
    
    private func openURL() {
        guard let url else {
            return
        }
        let gotAccess = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        if !gotAccess {
            logger.error("Cannot access security scoped resource at: \(url.path(percentEncoded: false))")
        }
        logger.log("Accessing url: \(url.path(percentEncoded: false))")
    }
}

#Preview {
    ContentView()
        .padding()
}
