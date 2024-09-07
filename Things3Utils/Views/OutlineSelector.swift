//
//  OutlineSelector.swift
//  Things3Utils
//
//  Created by A on 04/09/2024.
//

import SwiftUI
import PDFKit
import OSLog
import Dispatch
import DequeModule

fileprivate let logger = Logger(subsystem: "cyou.b612.things3.views", category: "OutlineSelector")

struct OutlineSelector: View {
    
    var outline: PDFOutline?
    
    init(outline: PDFOutline? = nil) {
        self.outline = outline
    }
    
    @State private var maxDepth: Int = 0
    
    @State private var todoRange: ClosedRange<Int>? = nil
    @State private var todoRangeText: String = ""
    @State private var headingSpan: Int? = nil
    @State private var checklistSpan: Int? = nil
    
    @State private var attributedString: NSAttributedString = .init()
    @State private var rangeIncluding: String = ""
    
    @State private var isUpdating: Bool = false
    
    @Environment(\.openWindow) private var openWindow
    @Environment(ViewModel.self) private var viewModel
    
    private let todoColor: NSColor = .cyan
    private let headingColor: NSColor = .orange
    private let checklistColor: NSColor = .magenta
    
    var body: some View {
        if outline != nil {
            VStack(alignment: .leading) {
                HStack {
                    VStack {
                        Text("Todo depth (0-\(maxDepth))")
                            .foregroundStyle(Color(nsColor: todoColor))
                        TextField("", text: $todoRangeText)
                            .labelsHidden()
                            .textFieldStyle(.roundedBorder)
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
                    .disabled(shouldSpanFieldBeDisabled())
                }
                HStack {
                    Text("Range (e.g. \"12-13,44-60\")")
                    TextField("", text: $rangeIncluding)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .onSubmit {
                            update()
                        }
                    Button("Submit") {
                        viewModel.isCalculatingJsonData = true
                        DispatchQueue.global(qos: .userInitiated).async {
                            viewModel.jsonData = getJsonData()
                            logger.debug("Json data is set to view model")
                            viewModel.isCalculatingJsonData = false
                            logger.debug("isCalculatingJsonData=false is set to view model")
                        }
                        openWindow(id: WindowID.submission.rawValue)
                    }
                    .disabled(todoRange == nil)
                }
                ScrollView {
                    AttributedStringViewRepresentable(attributedString: attributedString)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onChange(of: todoRangeText, initial: true) {
                handleTodoRangeTextChange()
            }
            .onChange(of: headingSpan) {
                update()
            }
            .onChange(of: checklistSpan) {
                update()
            }
            .onAppear(perform: handleOnAppear)
        } else {
            HStack {
                Spacer()
                Text("Cannot retrieve PDF outline")
                Spacer()
            }
        }
    }
    
    private func update() {
        guard let outline else {
            return
        }
        isUpdating = true
        Task(priority: .userInitiated) {
            attributedString = getOutlineAttributedString(outline: outline)
            isUpdating = false
        }
    }
    
    private func handleOnAppear() {
        update()
#if DEBUG
        print(flatten())
#endif
    }
    
    // MARK: - Validity check
    
    private func handleTodoRangeTextChange() {
        var ranges = string2Ranges(todoRangeText)
        if ranges.isEmpty {
            if let singleNumber = Int(todoRangeText) {
                ranges.append(singleNumber...singleNumber)
            } else {
                return
            }
        }
        let range = ranges.first!
        if isTodoRangeValid(range: range) {
            todoRange = range
            update()
        }
    }
    
    private func shouldSpanFieldBeDisabled() -> Bool {
        return todoRange == nil || isUpdating
    }
    
    private func isTodoRangeValid(range: ClosedRange<Int>) -> Bool {
        return range.lowerBound >= 0 && range.upperBound <= maxDepth
    }
    
    // MARK: - Helper
    
    private typealias Ranges = [ClosedRange<Int>]
    
    private func string2Ranges(_ rangeString: String) -> Ranges {
        let pattern = /(\d+)-(\d+)/
        let matches = rangeString.matches(of: pattern)
        var ranges = Ranges()
        for match in matches {
            let lhsS = cap(String(match.1)), rhsS = cap(String(match.2))
            guard let lhs = Int(lhsS), let rhs = Int(rhsS) else {
                logger.error("Cannot convert string to Int, this is a very unlikely event since the string is extracted from regex")
                return []
            }
            let range = lhs <= rhs ? lhs...rhs : rhs...lhs
            ranges.append(range)
        }
        return ranges
    }
    
    private func cap(_ number: String) -> String {
        number <= "9223372036854775807" ? number : "9223372036854775807"
    }
    
    // MARK: - Outline extraction
    
    private func recurseOutline (
        outline: PDFOutline,
        action: ((String, Int) -> Void)? = nil,
        postAction: ((String?, Int, Int) -> Void)? = nil
    ) {
        var maxDepth = 0
        func kernel(outline: PDFOutline, depth: Int) -> Int {
            var height = 0
            for i in 0..<outline.numberOfChildren {
                if let child = outline.child(at: i) {
                    if let label = child.label {
                        action?(label, depth)
                    }
                    let childHeight = kernel(outline: child, depth: depth + 1)
                    postAction?(child.label, depth, childHeight)
                    height = max(childHeight, height)
                }
            }
            return height + 1
        }
        maxDepth = kernel(outline: outline, depth: 0)
        maxDepth -= 2 // the outmost node is just a wrapper; we start from 0 (but kernel returns height, which starts from 1)
        self.maxDepth = maxDepth
    }
    
    private func flatten() -> [OutlineInfo] {
        guard let outline else {
            return []
        }
        
        typealias Infos =  Deque<Deque<OutlineInfo>>
        var infos: Infos = [[]]
        var previousDepth = 0
        
        recurseOutline(outline: outline, postAction: { label, depth, height in
            let info = OutlineInfo(label: label, depth: depth, height: height)
            switch depth {
            case previousDepth:
                var last = infos.popLast()!
                last.append(info)
                infos.append(last)
            case previousDepth - 1:
                previousDepth = depth
                let last = infos.popLast()!
                var secondLast = infos.popLast()!
                secondLast.append(info)
                secondLast.append(contentsOf: last)
                infos.append(secondLast)
            case (previousDepth + 1)...:
                infos.append(contentsOf: Infos(repeating: .init(), count: depth - previousDepth - 1))
                previousDepth = depth
                infos.append([info])
            default:
                logger.error("Unexpected recurse structure")
            }
        })
        
        return infos.flatMap({$0})
    }
    
    private struct OutlineInfo: CustomStringConvertible {
        var label: String?
        var depth: Int
        var height: Int
        
        var description: String {
            "\n\(label ?? "nil") (depth: \(depth) height \(height))"
        }
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
        
        let todoRange = todoRange ?? Int.min...Int.min

        recurseOutline(outline: outline) { label, depth in
            let indent = String(repeating: " ", count: depth * 4)
            let fullText = indent + label + "\n"
            var attributedText = AttributedString(fullText)
            
            attributedText.foregroundColor = {
                switch depth {
                case headingSpan:
                    return headingColor
                case todoRange:
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
        
        let todoRange: ClosedRange<Int> = todoRange ?? Int.min...Int.min
        var headingDepth: Int = .min
        var checklistDepth: Int = .min
        
        if self.todoRange != nil {
            headingDepth = headingSpan == nil ? todoRange.lowerBound : todoRange.lowerBound - headingSpan!
            checklistDepth = checklistSpan == nil ? todoRange.upperBound : todoRange.upperBound + checklistSpan!
        }
        
        let attributedString = NSMutableAttributedString()
        
        var count = 0
        let intervalTreeIncluding = rangeIncluding == "" ? nil : IntervalTree(ranges: string2Ranges(rangeIncluding))

        recurseOutline(outline: outline) { label, depth in
            
            defer {
                count += 1
            }
            
            guard intervalTreeIncluding == nil || intervalTreeIncluding!.has(count) else {
                return
            }
            
            let indent = String(repeating: " ", count: depth * 4)
            let fullText = indent + label + "\n"
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: {
                    switch depth {
                    case todoRange:
                        todoColor
                    case headingDepth...todoRange.lowerBound:
                        headingColor
                    case todoRange.upperBound...checklistDepth:
                        checklistColor
                    default:
                        NSColor.textColor
                    }
                }(),
                .paragraphStyle: paragraphStyle
            ]
            
            let attributedText = NSAttributedString(string: fullText, attributes: attributes)
            
            let countStr = String(format: "%4d", count) + "  "
            let countAttributed = NSAttributedString(string: countStr, attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .light),
                .foregroundColor: NSColor.secondaryLabelColor
            ])

            attributedString.append(countAttributed)
            attributedString.append(attributedText)
        }
        
        return attributedString
    }
    
    private func getJsonData() -> [Data] {
        guard let todoRange, let outline else {
            return []
        }
        
        let headingDepth = headingSpan == nil ? todoRange.lowerBound : max(todoRange.lowerBound - headingSpan!, 0)
        let checklistDepth = checklistSpan == nil ? todoRange.upperBound : todoRange.upperBound + checklistSpan!
        
        var headingStack: [String] = .init()
        var todoDepthCache: Int? = nil
        
        let project = TJSProject(title: "Imported Project \(Date().formatted(date: .abbreviated, time: .shortened))", items: [])
        
        var count = 0
        let intervalTreeIncluding = rangeIncluding == "" ? nil : IntervalTree(ranges: string2Ranges(rangeIncluding))
        
        recurseOutline(outline: outline) { label, depth in
            defer {
                count += 1
            }
            
            updateHeadingStack(label: label, depth: depth)
            guard intervalTreeIncluding == nil || intervalTreeIncluding!.has(count) else {
                return
            }
            
            if (headingDepth..<todoRange.lowerBound).contains(depth) {
                handleHeading(label: label, depth: depth)
            } else if todoRange.contains(depth) {
                handleTodo(label: label, depth: depth)
            } else if depth > todoRange.lowerBound && depth <= checklistDepth {
                handleChecklist(label: label, depth: depth)
            }
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = ThingsJSONDateEncodingStrategy()
        var data: [Data] = []
//        for start in stride(from: 0, to: project.items!.count, by: 250) {
//            let end = min(start + 250, project.items!.count)
//            let batch = Array(project.items![start..<end])
//            let project = TJSProject(title: "Imported Project \(Date().formatted(date: .abbreviated, time: .shortened))", items: batch)
//            data.append(try! encoder.encode([project]))
//        }
        data.append(try! encoder.encode([project])) // seems that things 3 isn't enforcing the 250 items per 10 seconds rule; then just let user confirm
        
        logger.debug("Calculated json date will return")
        return data
                        
        func handleHeading(label: String, depth: Int) {
            let headingStack = headingStack[headingDepth...depth]
            let heading = TJSHeading(title: headingStack.joined(separator: " -> "))
            project.items?.append(.heading(heading))
            
            todoDepthCache = nil
        }
        
        func updateHeadingStack(label: String, depth: Int) {
            let depth = depth + 1
            if headingStack.isEmpty {
                headingStack.append(label)
            }
            switch headingStack.count {
            case depth:
                headingStack.removeLast()
                headingStack.append(label)
            case (depth + 1)...:
                headingStack.removeLast(headingStack.count - depth + 1)
                headingStack.append(label)
            case depth - 1:
                headingStack.append(label)
            default:
                logger.error("Unexpected depth: \(depth) label: \(label) headingStack: \(headingStack)")
            }
        }
        
        func handleTodo(label: String, depth: Int) {
            let todo = TJSTodo(title: label)
            project.items?.append(.todo(todo))
            todoDepthCache = depth
        }
        
        func handleChecklist(label: String, depth: Int) {
            guard let todoDepthCache else {
                logger.error("Estranged checklist at depth \(depth) with label \(label)")
                return
            }
            guard todoDepthCache == depth - 1 else {
                logger.error("Checklist depth mismatch: checklist depth: \(depth) todoDepthCache: \(todoDepthCache)")
                return
            }
            guard let lastProjectItem = project.items?.last else {
                logger.error("Project items list is empty")
                return
            }
            guard case .todo(let todo) = lastProjectItem else {
                logger.error("Last project item is not a todo")
                return
            }
            let checklistItem = TJSChecklistItem(title: label)
            if todo.checklistItems == nil {
                todo.checklistItems = []
            }
            todo.checklistItems?.append(checklistItem)
            project.items?.removeLast()
            project.items?.append(.todo(todo))
        }
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
        let size = nsView.sizeThatFits()
        return .init(width: size.width + 3, height: size.height + 3) // sometimes the text would disappear randomly if the size is too tight or 'just right'
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
        .environment(ViewModel())
}
