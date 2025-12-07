import Cocoa
import UniformTypeIdentifiers
import UserNotifications

class MotionController {
    static let shared = MotionController()

    private init() {
        // Request notification permission
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                writeDebugLog("Notification permission error: \(error)")
            }
        }
    }

    private func showNotification(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                writeDebugLog("Notification error: \(error)")
            }
        }
    }
    
    func processDroppedFile(url: URL) {
        writeDebugLog("Processing dropped file: \(url.path)")

        let ext = url.pathExtension.lowercased()

        // If it's already an FCPXML file, process it directly
        if ext == "fcpxml" || ext == "fcpxmld" {
            writeDebugLog("Input is FCPXML file.")
            processFCPXML(url: url)
            return
        }

        // If called from FCPX Share menu, automatically export XML
        writeDebugLog("Called from Share menu. Automatically exporting FCPXML...")

        // Show notification to user
        showNotification(title: "Moplug Send Motion", message: "処理中です。Final Cut Proを操作しないでください...")

        // Trigger automatic XML export - use downloads folder (FCPX's default)
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let outputPath = downloadsURL.appendingPathComponent("moplug_auto_export.fcpxmld")

        if exportFCPXMLAutomatically(to: outputPath) {
            writeDebugLog("Successfully exported FCPXML to: \(outputPath.path)")

            // Wait a moment for file to be fully written
            Thread.sleep(forTimeInterval: 2.0)

            // Process the exported FCPXML
            if FileManager.default.fileExists(atPath: outputPath.path) {
                self.processFCPXML(url: outputPath)

                // Clean up temp file after processing
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    try? FileManager.default.removeItem(at: outputPath)
                }
            } else {
                writeDebugLog("ERROR: Exported file not found at \(outputPath.path)")
                showError(message: "XMLエクスポートに失敗しました。ファイルが見つかりません。")
            }
        } else {
            writeDebugLog("Failed to auto-export FCPXML")
            showError(message: "XMLの自動エクスポートに失敗しました。\n\nFinal Cut Proでタイムラインが開いているか確認してください。")
        }
    }

    private func exportFCPXMLAutomatically(to outputPath: URL) -> Bool {
        writeDebugLog("Attempting automatic FCPXML export to: \(outputPath.path)")

        let script = """
        tell application "Final Cut Pro" to activate
        delay 1.0

        tell application "System Events"
            tell process "Final Cut Pro"
                -- Keep Final Cut Pro in front
                set frontmost to true

                -- Select all timeline content (required for export to work)
                keystroke "a" using command down
                delay 0.5

                -- Click Export XML menu
                tell menu bar 1
                    tell menu bar item "ファイル"
                        tell menu "ファイル"
                            click menu item "XMLを書き出す…"
                        end tell
                    end tell
                end tell

                delay 2.5

                -- Keep Final Cut Pro in front during dialog
                set frontmost to true

                -- Find the "XMLの書き出し" window
                if exists window "XMLの書き出し" then
                    tell window "XMLの書き出し"
                        -- Simply set the filename - FCPX uses Downloads by default
                        try
                            set value of combo box 1 to "\(outputPath.lastPathComponent)"
                        on error
                            try
                                set value of text field 1 to "\(outputPath.lastPathComponent)"
                            end try
                        end try
                        delay 0.5

                        -- Click Save button
                        click button "保存"
                        delay 2.0
                    end tell
                    return "success"
                else
                    error "XMLの書き出し window not found"
                end if
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)

            if let error = error {
                writeDebugLog("AppleScript error: \(error)")
                return false
            }

            if result.stringValue == "success" {
                writeDebugLog("XML export dialog handled successfully")
                return true
            }
        }

        writeDebugLog("Failed to export XML automatically")
        return false
    }

    private func showError(message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "エラー"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
        }
    }

    private func promptForSavedFCPXML() {
        writeDebugLog("Prompting user to select saved FCPXML file...")

        let openPanel = NSOpenPanel()
        openPanel.message = "保存したFCPXMLファイルを選択してください"
        openPanel.allowedContentTypes = [
            UTType(filenameExtension: "fcpxml")!,
            UTType(filenameExtension: "fcpxmld")!
        ]
        openPanel.allowsMultipleSelection = false

        openPanel.begin { result in
            if result == .OK, let selectedURL = openPanel.url {
                writeDebugLog("User selected FCPXML: \(selectedURL.path)")
                self.processFCPXML(url: selectedURL)
            }
        }
    }

    private func processFCPXML(url: URL) {
        writeDebugLog("Processing FCPXML: \(url.path)")

        // Handle .fcpxmld bundle
        var fcpxmlFile = url
        if url.pathExtension == "fcpxmld" {
            let infoFile = url.appendingPathComponent("Info.fcpxml")
            if FileManager.default.fileExists(atPath: infoFile.path) {
                fcpxmlFile = infoFile
                writeDebugLog("Found Info.fcpxml inside bundle: \(infoFile.path)")
            }
        }

        // Automatically save to Downloads folder without showing dialog
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let suggestedName = url.deletingPathExtension().lastPathComponent + ".motn"
        let outputURL = downloadsURL.appendingPathComponent(suggestedName)

        // Delete existing file if it exists to avoid replace dialog
        if FileManager.default.fileExists(atPath: outputURL.path) {
            do {
                try FileManager.default.removeItem(at: outputURL)
                writeDebugLog("Deleted existing file: \(outputURL.path)")
            } catch {
                writeDebugLog("Failed to delete existing file: \(error)")
            }
        }

        writeDebugLog("Auto-saving Motion project to: \(outputURL.path)")
        self.generateAndOpen(inputURL: fcpxmlFile, outputURL: outputURL, isFCPXML: true)
    }

    private func generateAndOpen(inputURL: URL, outputURL: URL, isFCPXML: Bool) {
        do {
            if isFCPXML {
                writeDebugLog("Parsing FCPXML: \(inputURL.path)")
                if let project = FCPXMLParser.parse(url: inputURL) {
                    try MotionProjectGenerator.generateProject(from: project, outputURL: outputURL)
                    writeDebugLog("Generated Motion project from FCPXML.")
                } else {
                    throw NSError(domain: "com.moplug", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse FCPXML"])
                }
            } else {
                writeDebugLog("Generating from media file: \(inputURL.path)")
                try MotionProjectGenerator.generateProject(for: inputURL, outputURL: outputURL)
                writeDebugLog("Generated Motion project from media.")
            }
            
            NSWorkspace.shared.open(outputURL)
            writeDebugLog("Opened Motion project.")
            
        } catch {
            writeDebugLog("ERROR: \(error.localizedDescription)")
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to generate Motion project: \(error.localizedDescription)"
            alert.runModal()
        }
    }
}