//
//  ImportButton.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import OSLog

struct ImportButton: View {
    @State private var fileImporterIsPresented = false
    @Binding var url: URL?
    
    private let logger = Logger(subsystem: "cyou.b612.things3.views", category: "ImportButton")
    
    var body: some View {
        Button("Select PDF") {
            fileImporterIsPresented = true
        }
        .fileImporter(isPresented: $fileImporterIsPresented, allowedContentTypes: [.pdf], onCompletion: fileImporterCompletionHandler)
    }
    
    private func fileImporterCompletionHandler(result: Result<URL, any Error>) {
        switch result {
        case .success(let url):
            logger.log("Selected URL: \(url.path(percentEncoded: false))")
            self.url = url
        case .failure(let error):
            logger.error("Cannot import file: \(error.localizedDescription)")
        }
    }
}

#Preview {
    @Previewable @State var url: URL?
    ImportButton(url: $url)
        .padding()
}
