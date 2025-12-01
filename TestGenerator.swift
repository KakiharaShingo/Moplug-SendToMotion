import Foundation

// Mock FCPXMLParser if needed or rely on compiled file
// We will compile this with FCPXMLParser.swift and MotionProjectGenerator.swift

func main() {
    let inputPath = "/Users/shingo/Xcode_Local/git/Moplug_On_Motion/ファイル関連/理想ファイル/読み込んだファイル/スノーラック.fcpxml"
    let outputPath = "/Users/shingo/Xcode_Local/git/Moplug_On_Motion/ファイル関連/アウトプットファイル/スノーラック_verify.motn"
    
    let inputURL = URL(fileURLWithPath: inputPath)
    let outputURL = URL(fileURLWithPath: outputPath)
    
    do {
        print("Parsing FCPXML...")
        let parser = FCPXMLParser(url: inputURL)
        guard let project = parser.parse() else {
            print("Error: Failed to parse FCPXML")
            exit(1)
        }
        
        print("Generating Motion Project...")
        try MotionProjectGenerator.generateProject(from: project, outputURL: outputURL)
        print("Success! Generated project at: \(outputPath)")
        
    } catch {
        print("Error: \(error)")
        exit(1)
    }
}

main()
