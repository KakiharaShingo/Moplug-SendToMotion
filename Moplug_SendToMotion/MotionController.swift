import Cocoa
import UniformTypeIdentifiers

class MotionController {
    static let shared = MotionController()
    
    private init() {}
    
    func processDroppedFile(url: URL) {
        let panel = NSSavePanel()
        if let motnType = UTType(filenameExtension: "motn") {
            panel.allowedContentTypes = [motnType]
        } else {
            panel.allowedContentTypes = [.xml]
        }
        panel.nameFieldStringValue = url.deletingPathExtension().lastPathComponent + ".motn"
        
        panel.begin { response in
            if response == .OK, let outputURL = panel.url {
                self.generateAndOpen(mediaURL: url, outputURL: outputURL)
            }
        }
    }
    
    private func generateAndOpen(mediaURL: URL, outputURL: URL) {
        do {
            if mediaURL.pathExtension.lowercased() == "fcpxml" {
                if let project = FCPXMLParser.parse(url: mediaURL) {
                    try MotionProjectGenerator.generateProject(from: project, outputURL: outputURL)
                } else {
                    throw NSError(domain: "com.moplug", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse FCPXML"])
                }
            } else {
                try MotionProjectGenerator.generateProject(for: mediaURL, outputURL: outputURL)
            }
            NSWorkspace.shared.open(outputURL)
        } catch {
            print("Error generating project: \(error)")
            let alert = NSAlert()
            alert.messageText = "Error"
            alert.informativeText = "Failed to generate Motion project: \(error.localizedDescription)"
            alert.runModal()
        }
    }
}
