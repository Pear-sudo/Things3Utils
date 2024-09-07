//
//  Communication.swift
//  Things3Utils
//
//  Created by A on 07/09/2024.
//

import Foundation
import Network

func startListen() throws {
    let listener = try NWListener(using: .tcp, on: 8080)

    listener.newConnectionHandler = { connection in
        connection.start(queue: .main)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { data, _, isComplete, _ in
            if let data = data, let message = String(data: data, encoding: .utf8) {
                print("Received: \(message)")
            }
            if isComplete {
                connection.cancel()
            }
        }
    }

    listener.start(queue: .main)
    RunLoop.main.run()
}
