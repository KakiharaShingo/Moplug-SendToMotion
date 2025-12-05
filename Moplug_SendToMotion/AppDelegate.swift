//
//  AppDelegate.swift
//  Moplug_On_Motion
//
//  Created by 垣原親伍 on 2025/12/01.
//

import Cocoa
import os.log

// MARK: - Application Class

@objc(MoplugApplication)
class MoplugApplication: NSApplication {

    @objc var assets = [MoplugAsset]()

    override init() {
        super.init()
        os_log("Moplug Send Motion: Application initialized", log: OSLog.default, type: .info)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - App Delegate

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationWillFinishLaunching(_ notification: Notification) {
        os_log("Moplug Send Motion: Application will finish launching", log: OSLog.default, type: .info)
        writeDebugLog("=== Application will finish launching ===")
        writeDebugLog("Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        writeDebugLog("Principal Class: \(NSStringFromClass(type(of: NSApp)))")

        // Register for Apple Events EARLY
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kCoreEventClass),
            andEventID: AEEventID(kAEOpenDocuments)
        )
        writeDebugLog("Apple Event handler registered for kAEOpenDocuments")
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        os_log("Moplug Send Motion: Application finished launching", log: OSLog.default, type: .info)
        writeDebugLog("=== Application did finish launching ===")
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        MotionController.shared.processDroppedFile(url: url)
    }

    // Handle Apple Event directly
    @objc func handleOpenDocumentEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        os_log("Moplug Send Motion: Received Apple Event", log: OSLog.default, type: .info)
        writeDebugLog("=== RECEIVED APPLE EVENT ===")
        writeDebugLog("Event Class: \(event.eventClass)")
        writeDebugLog("Event ID: \(event.eventID)")
        writeDebugLog("Event Description: \(event.description)")

        guard let fileListDescriptor = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            os_log("Moplug Send Motion: No file list in event", log: OSLog.default, type: .error)
            writeDebugLog("ERROR: No file list in event")
            return
        }

        writeDebugLog("File list has \(fileListDescriptor.numberOfItems) items")

        for i in 1...fileListDescriptor.numberOfItems {
            if let fileDescriptor = fileListDescriptor.atIndex(i),
               let fileURLString = fileDescriptor.stringValue {
                os_log("Moplug Send Motion: Processing file from Apple Event: %{public}@", log: OSLog.default, type: .info, fileURLString)
                writeDebugLog("Processing file: \(fileURLString)")

                // Convert file:// URL to path
                if let url = URL(string: fileURLString) {
                    let path = url.path
                    writeDebugLog("Converted to path: \(path)")
                    DispatchQueue.main.async {
                        MotionController.shared.processDroppedFile(url: URL(fileURLWithPath: path))
                    }
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}

// MARK: - Asset Class

@objc(MoplugAsset)
class MoplugAsset: NSObject {
    @objc var uniqueID: String = UUID().uuidString
    @objc var name: String = ""
    @objc var locationInfo: [String: Any] = [:]
    @objc var metadata: [String: Any] = [:]
    @objc var dataOptions: [String: Any] = [:]

    override init() {
        super.init()
    }
}

// MARK: - Make Command

@objc(MoplugMakeCommand)
class MoplugMakeCommand: NSCreateCommand {
    override func performDefaultImplementation() -> Any? {
        os_log("Moplug Send Motion: Make command received", log: OSLog.default, type: .info)
        writeDebugLog("=== Make command received ===")
        return super.performDefaultImplementation()
    }
}

// MARK: - Debug Logging

private func writeDebugLog(_ message: String) {
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

