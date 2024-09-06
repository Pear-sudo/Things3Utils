//
//  URLView.swift
//  Things3Utils
//
//  Created by A on 05/09/2024.
//

import SwiftUI
import Highlightr
import OSLog

fileprivate let logger = Logger(subsystem: "cyou.b612.things3.views", category: "JsonView")

struct JsonView: View {
    var jsonData: [Data]
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var isSending = false
    @State private var progress = 0.0
    
    var body: some View {
        VStack(alignment: .center) {
            Button("Confirm") {
                let total = jsonData.count
                withAnimation {
                    isSending.toggle()
                }
                Task {
                    for (i, data) in jsonData.enumerated() {
                        data2Things3(data: data)
                        progress = Double(i + 1) / Double(total)
                        if i + 1 != total {
                            try? await Task.sleep(for: .seconds(11))
                        }
                    }
                    withAnimation {
                        isSending.toggle()
                    }
                }
            }
            if isSending {
                ProgressView(value: progress)
            }
            HStack {
                VStack {
                    Text("JSON")
                        .font(.title2)
                    ScrollView([.horizontal, .vertical]) {
                        AttributedStringViewRepresentable(attributedString: attributedString)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                VStack {
                    Text("URL")
                        .font(.title2)
                    ScrollView {
                        Text(getURLStr())
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .padding()
    }
    
    private func getURLStr() -> String {
        var s = ""
        for data in jsonData {
            print(generateJsonURL(jsonData: data).absoluteString, terminator: String(repeating: "\n", count: 3), to: &s)
        }
        return s
    }
    
    private func data2Things3(data: Data) {
        let url = generateJsonURL(jsonData: data)
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open(url, configuration: config) { (app, error) in
            if let error {
                logger.error("\(error.localizedDescription)")
            }
        }
    }
    
    private var attributedString: NSAttributedString {
        let highlightr = Highlightr()!
        highlightr.setTheme(to: "xcode")
        let highlightedCode = highlightr.highlight(pretty, as: "json")!
        logger.debug("attributedString computed")
        return highlightedCode
    }
    
    private var pretty: String {
        var s = ""
        for data in jsonData {
            print(data2prettyJson(data: data), terminator: String(repeating: "\n", count: 3), to: &s)
        }
        return s
    }
    
    private func data2prettyJson(data: Data) -> String {
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            logger.debug("pretty json computed")
            return String(data: data, encoding: .utf8)!
        } catch {
            
        }
        return ""
    }
}

func generateJsonURL(jsonData: Data) -> URL {
    let json = String(data: jsonData, encoding: .utf8)!
    var components = URLComponents(string: "things:///add-json")!
    let queryItem = URLQueryItem(name: "data", value: json)
    components.queryItems = [queryItem]
    let url = components.url!
    return url
}

#Preview {
    JsonView(jsonData: [generateSampleJsonData()])
}

fileprivate func generateSampleJsonData() -> Data {
    let todo1 = TJSTodo(title: "Pick up dry cleaning", when: "today")
    let todo2 = TJSTodo(title: "Pack for vacation",
                        checklistItems: [TJSChecklistItem(title: "Camera"),
                                         TJSChecklistItem(title: "Passport")])

    let project = TJSProject(title: "Go Shopping",
                             items: [.heading(TJSHeading(title: "Dairy")),
                                     .todo(TJSTodo(title: "Milk"))])

    let container = TJSContainer(items: [.todo(todo1),
                                         .todo(todo2),
                                         .project(project)])
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = ThingsJSONDateEncodingStrategy()
    let data = try! encoder.encode(container)
    return data
//        UIApplication.shared.open(url, options: [:], completionHandler: nil)

}
