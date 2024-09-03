//
//  ImportArea.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import UniformTypeIdentifiers
import OSLog
import Foundation

struct ImportArea: View {
    @Binding var url: URL?
    
    @State private var isTargeted: Bool = false
    
    private let logger = Logger(subsystem: "cyou.b612.things3.views", category: "ImportArea")
    
    var body: some View {
        VStack {
            Text("Or Drag and Drop the PDF here")
                .foregroundStyle(.secondary)
                .font(.custom("Kalam-Light", size: 24))
            HStack {
                Text("Selected PDF: ") +
                Text(url == nil ? "None" : url!.lastPathComponent)
                AccessibilityIndicator(url: url)
                ImportButton(url: $url)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .fill(.clear)
                .stroke(.gray, style: .init(lineWidth: 2, dash: [4]))
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleOnDrop)
    }
    
    private func handleOnDrop(providers: [NSItemProvider], position: CGPoint) -> Bool {
        guard providers.count == 1 else {
            return false
        }
        guard let provider = providers.first else {
            return false
        }
        logger.log("Received drop")
        var isValid = true // false TODO: the async code below cannot update isValid in time before it is returned; you need to work out a way
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
            if let error {
                logger.error("Cannot extract content in NSItemProvider: \(error.localizedDescription)")
                return
            }
            guard let data = item as? Data else {
                logger.error("Cannot extract content in NSItemProvider")
                return
            }
            guard let url = URL(dataRepresentation: data, relativeTo: nil) else {
                logger.error("Cannot convert data to URL")
                return
            }
            guard url.pathExtension == "pdf" else {
                logger.log("The url is not a pdf: \(url.path(percentEncoded: false))")
                return
            }
            isValid = true
            self.url = url
            logger.log("Received URL: \(url.p)")
        }
        return isValid
    }
}

#Preview {
    @Previewable @State var url: URL? = nil
    ImportArea(url: $url)
        .frame(width: 400)
        .padding()
}
