//
//  URLView.swift
//  Things3Utils
//
//  Created by A on 05/09/2024.
//

import SwiftUI
import Highlightr

struct JsonView: View {
    var jsonData: Data
    
    var body: some View {
        VStack(alignment: .center) {
            Text("Code for nerds")
                .font(.title)
            HStack {
                VStack {
                    Text("JSON")
                        .font(.title2)
                    ScrollView {
                        Text(attributedString)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }
                VStack {
                    Text("URL")
                        .font(.title2)
                    ScrollView {
                        Text(generateJsonURL(jsonData: jsonData).absoluteString)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
    
    private var attributedString: AttributedString {
        let highlightr = Highlightr()!
        highlightr.setTheme(to: "xcode")
        let highlightedCode = highlightr.highlight(pretty, as: "json")!
        return AttributedString(highlightedCode)
    }
    
    private var pretty: String {
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData)
            let data = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(data: data, encoding: .utf8)!
        } catch {
            
        }
        return .init()
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
    JsonView(jsonData: generateSampleJsonData())
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
