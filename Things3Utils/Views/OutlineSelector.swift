//
//  OutlineSelector.swift
//  Things3Utils
//
//  Created by A on 04/09/2024.
//

import SwiftUI
import PDFKit
import OSLog

fileprivate let logger = Logger(subsystem: "cyou.b612.things3.views", category: "OutlineSelector")

struct OutlineSelector: View {
    
    var outline: PDFOutline?
    
    init(outline: PDFOutline? = nil) {
        self.outline = outline
    }
    
    @State private var maxDepth: Int = 0
    
    @State private var todoDepth: Int? = nil
    @State private var headingSpan: Int? = nil
    @State private var checklistSpan: Int? = nil
    
    @State private var attributedString: NSAttributedString = .init()
    
    @State private var isUpdating: Bool = false
    
    private let todoColor: NSColor = .cyan
    private let headingColor: NSColor = .orange
    private let checklistColor: NSColor = .magenta
    
    var body: some View {
        if outline != nil {
            VStack(alignment: .leading) {
                HStack {
                    NumberField(number: $todoDepth) {
                        Text("Todo depth (0-\(maxDepth))")
                            .foregroundStyle(Color(nsColor: todoColor))
                    }
                        .disabled(isUpdating)
                    Group {
                        NumberField(number: $headingSpan) {
                            Text("Heading span")
                                .foregroundStyle(Color(nsColor: headingColor))
                        }
                        NumberField(number: $checklistSpan) {
                            Text("Checklist span")
                                .foregroundStyle(Color(nsColor: checklistColor))
                        }
                    }
                    .disabled({
                        guard let todoDepth else {
                            return true
                        }
                        return !(todoDepth <= maxDepth && todoDepth >= 0) || isUpdating
                    }())
                }
                HStack {
                    ScrollView {
                        AttributedStringViewRepresentable(attributedString: attributedString)
                    }
                }
            }
            .onChange(of: todoDepth, initial: true) {
                update()
            }
            .onChange(of: headingSpan) {
                update()
            }
            .onChange(of: checklistSpan) {
                update()
            }
        } else {
            Text("Cannot retrieve PDF outline")
        }
    }
    
    private func update() {
        guard let outline else {
            return
        }
        isUpdating = true
        print("updating")
        Task(priority: .userInitiated) {
            attributedString = getOutlineAttributedString(outline: outline)
            isUpdating = false
        }
    }
    
    // MARK: - Outline extraction
    
    private func recurseOutline (
        outline: PDFOutline,
        action: ((String, Int) -> Void)? = nil
    ) {
        var maxDepth = 0
        func kernel(outline: PDFOutline, depth: Int) {
            for i in 0..<outline.numberOfChildren {
                if let child = outline.child(at: i) {
                    if let label = child.label {
                        if let action {
                            action(label, depth)
                        }
                    }
                    kernel(outline: child, depth: depth + 1)
                }
            }
            maxDepth = max(depth, maxDepth)
        }
        kernel(outline: outline, depth: 0)
        maxDepth -= 1 // the outmost node is just a wrapper
        self.maxDepth = maxDepth
    }
    
    private func printOutline(outline: PDFOutline) {
        recurseOutline(outline: outline, action: { label, depth in
            print(String(repeating: " ", count: depth) + label)
        })
    }
    
    private func getOutlineString(outline: PDFOutline) -> String {
        var s = ""
        recurseOutline(outline: outline) { label, depth in
            s = s + String(repeating: " ", count: depth * 4) + label +  "\n"
        }
        return s
    }
    
    private func getOutlineAttributedString(outline: PDFOutline) -> AttributedString {
        var attributedString = AttributedString()

        recurseOutline(outline: outline) { label, depth in
            let indent = String(repeating: " ", count: depth * 4)
            let fullText = indent + label + "\n"
            var attributedText = AttributedString(fullText)
            
            attributedText.foregroundColor = {
                switch depth {
                case headingSpan:
                    return headingColor
                case todoDepth:
                    return todoColor
                case checklistSpan:
                    return checklistColor
                default:
                    return .black
                }
            }()
            
            attributedString.append(attributedText)
        }

        return attributedString
    }
    
    private func getOutlineAttributedString(outline: PDFOutline) -> NSAttributedString {
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4.0
        
        guard let todoDepth else {
            return NSAttributedString(string: getOutlineString(outline: outline), attributes: [
                .foregroundColor: NSColor.textColor,
                .paragraphStyle: paragraphStyle
            ])
        }
        
        let headingDepth = headingSpan == nil ? todoDepth : todoDepth - headingSpan!
        let checklistDepth = checklistSpan == nil ? todoDepth : todoDepth + checklistSpan!
        
        let attributedString = NSMutableAttributedString()

        recurseOutline(outline: outline) { label, depth in
            let indent = String(repeating: " ", count: depth * 4)
            let fullText = indent + label + "\n"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: {
                    switch depth {
                    case todoDepth:
                        todoColor
                    case headingDepth...todoDepth:
                        headingColor
                    case todoDepth...checklistDepth:
                        checklistColor
                    default:
                        NSColor.textColor
                    }
                }(),
                .paragraphStyle: paragraphStyle
            ]
            let attributedText = NSAttributedString(string: fullText, attributes: attributes)
            attributedString.append(attributedText)
        }
        
        return attributedString
    }
}

// MARK: - Views

class AttributedStringView: NSView {
    var attributedString: NSAttributedString

    init(attributedString: NSAttributedString) {
        self.attributedString = attributedString
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        drawText(attributedString: attributedString, in: context, bounds: self.bounds)
        print("bounds", bounds)
        print("frame", frame)
    }

    private func drawText(attributedString: NSAttributedString, in context: CGContext, bounds: CGRect) {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGMutablePath()
        path.addRect(bounds)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        CTFrameDraw(frame, context)
    }
    
    func sizeThatFits() -> CGSize {
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, attributedString.length), nil, maxSize, nil)
        return suggestedSize
    }
}

struct AttributedStringViewRepresentable: NSViewRepresentable {
    var attributedString: NSAttributedString

    func makeNSView(context: Context) -> AttributedStringView {
        return AttributedStringView(attributedString: attributedString)
    }

    func updateNSView(_ nsView: AttributedStringView, context: Context) {
        nsView.attributedString = attributedString
        nsView.needsDisplay = true
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: AttributedStringView, context: Context) -> CGSize? {
        nsView.sizeThatFits()
    }
}

struct NumberField<V>: View where V: View {
    
    var number: Binding<Int?>
    var label: V? = nil
    var title: String? = nil
    
    init(number: Binding<Int?>, title: String? = nil) where V == EmptyView {
        self.number = number
        self.title = title
    }
    
    init(number: Binding<Int?>, @ViewBuilder label: () -> V) {
        self.number = number
        self.label = label()
    }
    
    var body: some View {
        if let label {
            VStack(spacing: .zero) {
                label
                TextField("", value: number, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
        } else if let title {
            VStack(spacing: .zero) {
                Text(title)
                TextField("", value: number, format: .number)
                    .textFieldStyle(.roundedBorder)
            }
        } else {
            TextField("", value: number, format: .number)
                .textFieldStyle(.roundedBorder)
        }
    }
}

// MARK: - Preview

fileprivate struct OutlineSelectorWrapper: View {
    /// Please keep a reference to doc and do not use PDFDocument(url: samplePDF)?.outlineRoot
    ///
    /// Otherwise the outline will not be complete, at most 1 level of outline can be shown
    private let doc = PDFDocument(url: samplePDF)
    var body: some View {
        OutlineSelector(outline: doc?.outlineRoot)
    }
}

fileprivate let samplePDF = URL.documentsDirectory.appending(path: "algorithm.pdf")

#Preview {
    OutlineSelectorWrapper()
}
