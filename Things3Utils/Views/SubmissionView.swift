//
//  SubmissionView.swift
//  Things3Utils
//
//  Created by A on 06/09/2024.
//

import SwiftUI

struct SubmissionView: View {
    @Environment(ViewModel.self) private var viewModel
    var body: some View {
        if let jsonData = viewModel.jsonData {
            VStack {
                JsonView(jsonData: jsonData)
            }
        } else {
            Text("Data unavailable")
        }
    }
}
