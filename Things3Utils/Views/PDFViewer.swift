//
//  PDFViewer.swift
//  Things3Utils
//
//  Created by A on 03/09/2024.
//

import SwiftUI
import PDFKit
import OSLog

fileprivate let logger = Logger(subsystem: "cyou.b612.things3.views", category: "PDFViewer")

struct PDFViewer: View {
    
    var url: URL
    
    init(url: URL) {
        self.url = url
        logger.log("PDFViewer received URL: \(url.p)")
        
        self.pdfDocument = Self.getPDFDocument(url: url)
        self.pdfView.document = pdfDocument
        self.pdfThumbnail.pdfView = pdfView
        
    }
    
    private let pdfDocument: PDFDocument?
    private let pdfView: PDFView = Self.configurePDFView()
    private let pdfThumbnail: PDFThumbnailView = Self.configurePDFThumbnail()
    
    @State private var thumbnailWidth: CGFloat = 100
    
    var body: some View {
        if pdfDocument == nil {
            Text("PDF cannot be opened")
        } else {
            HStack(spacing: 0) {
                PDFThumbnailWrapper(pdfView: pdfView, thumbnailWidth: thumbnailWidth)
                    .frame(width: thumbnailWidth)
                Color(.gray)
                    .frame(width: 2)
                    .onHover(perform: handleOnHover)
                    .gesture(DragGesture().onChanged(handleOnDrag))
                Spacer()
            }
        }
    }
    
    private func handleOnDrag(value: DragGesture.Value) {
        let delta = value.location.x - value.startLocation.x
        thumbnailWidth += delta
    }
    
    private func handleOnHover(hover: Bool) {
        DispatchQueue.main.async {
            if hover {
                NSCursor(image: NSImage(systemSymbolName: "arrow.left.and.right", accessibilityDescription: nil)!, hotSpot: NSPoint(x: 8, y: 8)).push()
            } else {
                NSCursor.pop()
            }
        }
    }
    
    static private func configurePDFView() -> PDFView {
        let pdfView = PDFView()
        return pdfView
    }
    
    static private func configurePDFThumbnail() -> PDFThumbnailView {
        let thumbnail = PDFThumbnailView()
        
        thumbnail.allowsDragging = false
        thumbnail.allowsMultipleSelection = true
        
        return thumbnail
    }
    
    static private func getPDFDocument(url: URL) -> PDFDocument? {
        guard !FileManager.default.isReadableFile(atPath: url.p) else {
            return PDFDocument(url: url)
        }
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            url.stopAccessingSecurityScopedResource()
        }
        guard canAccess else {
            return nil
        }
        return PDFDocument(url: url)
    }
}

struct PDFThumbnailWrapper: NSViewRepresentable {
    
    var pdfView: PDFView
    var thumbnailWidth: CGFloat
    
    init(pdfView: PDFView, thumbnailWidth: CGFloat) {
        self.pdfView = pdfView
        self.thumbnailWidth = thumbnailWidth
        logger.debug("PDFThumbnailWrapper init")
    }
    
    func makeNSView(context: Context) -> PDFThumbnailView {
        let thumbnail = PDFThumbnailView()
        thumbnail.pdfView = pdfView
        return thumbnail
    }
    
    func updateNSView(_ thumbnail: PDFThumbnailView, context: Context) {
        thumbnail.pdfView = pdfView
        thumbnail.thumbnailSize = .init(width: thumbnailWidth, height: thumbnail.thumbnailSize.height * thumbnailWidth / thumbnail.thumbnailSize.width)
        logger.debug("updateNSView")
    }
}

// MARK: - Preview

fileprivate let samplePDF = URL.documentsDirectory.appending(path: "Introduction.to.Algorithms.4th.Leiserson.Stein.Rivest.Cormen.MIT.Press.9780262046305.EBooksWorld.ir.pdf")
#Preview {
    PDFViewer(url: samplePDF)
}
