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
        if !viewModel.jsonData.isEmpty {
            VStack {
                JsonView(jsonData: viewModel.jsonData)
            }
        } else {
            if viewModel.isCalculatingJsonData {
                ProgressView()
            } else {
                Text("Data unavailable")
            }
        }
    }
}
