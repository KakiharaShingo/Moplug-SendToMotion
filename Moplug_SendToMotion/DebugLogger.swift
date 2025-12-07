//
//  DebugLogger.swift
//  Moplug_On_Motion
//
//  Created by 垣原親伍 on 2025/12/06.
//

import Foundation

func writeDebugLog(_ message: String) {
    let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    let logMessage = "[\(timestamp)] \(message)\n"

    let fileManager = FileManager.default
    if let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
        let appLogDirectory = appSupportDirectory.appendingPathComponent("Moplug Send Motion")
        try? fileManager.createDirectory(at: appLogDirectory, withIntermediateDirectories: true, attributes: nil)
        let logFileURL = appLogDirectory.appendingPathComponent("debug.log")

        if let logData = logMessage.data(using: .utf8) {
            if fileManager.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(logData)
                    fileHandle.closeFile()
                }
            } else {
                try? logData.write(to: logFileURL)
            }
        }
    }

    // Also print to console
    print(logMessage)
}
