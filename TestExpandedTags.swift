import Foundation

struct FCPXMLAsset {
    let id: String
    let src: String
    let start: Double
    let duration: Double
    var width: Int = 0
    var height: Int = 0
}

struct FCPXMLClip {
    let name: String
    let ref: String
    let offset: Double
    let duration: Double
    let start: Double
    var text: String?
}

struct FCPXMLProject {
    var assets: [FCPXMLAsset] = []
    var clips: [FCPXMLClip] = []
    var duration: Double = 10.0
    var frameRate: Double = 30.0
    var width: Int = 1920
    var height: Int = 1080
    var startTime: Double = 0.0
}

class FCPXMLParser: NSObject, XMLParserDelegate {
    
    private var project = FCPXMLProject()
    private var currentElement = ""
    private var currentClip: FCPXMLClip?
    private var currentText: String = ""
    private var isParsingText = false
    
    // Asset parsing state
    private var currentAssetId: String?
    private var currentAssetStart: Double = 0.0
    private var currentAssetDuration: Double = 0.0
    private var currentAssetSrc: String?
    private var currentAssetFormatId: String?
    
    // Format parsing state
    private var formats: [String: (width: Int, height: Int)] = [:]
    
    static func parse(url: URL) -> FCPXMLProject? {
        let parser = FCPXMLParser()
        if let project = parser.parseFile(url: url) {
            // Calculate project start time (minimum of all clips)
            var minStart = Double.greatestFiniteMagnitude
            for clip in project.clips {
                if clip.start < minStart {
                    minStart = clip.start
                }
            }
            var finalProject = project
            finalProject.startTime = minStart == .greatestFiniteMagnitude ? 0 : minStart
            return finalProject
        }
        return nil
    }
    
    private func parseFile(url: URL) -> FCPXMLProject? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        parser.delegate = self
        return parser.parse() ? project : nil
    }
    
    private func parseTime(_ timeString: String) -> Double {
        let clean = timeString.replacingOccurrences(of: "s", with: "")
        if clean.contains("/") {
            let parts = clean.components(separatedBy: "/")
            if parts.count == 2, let num = Double(parts[0]), let den = Double(parts[1]), den != 0 {
                return num / den
            }
        }
        return Double(clean) ?? 0.0
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        // Strip namespace if present (e.g. "fcpxml:asset" -> "asset")
        let cleanName = elementName.components(separatedBy: ":").last ?? elementName
        currentElement = cleanName
        
        print("DEBUG: Found element \(cleanName)")
        
        if cleanName == "asset" {
            if let id = attributeDict["id"] {
                currentAssetId = id
                currentAssetStart = parseTime(attributeDict["start"] ?? "0s")
                currentAssetDuration = parseTime(attributeDict["duration"] ?? "0s")
                currentAssetSrc = attributeDict["src"] // FCPXML 1.9+ might have src here
                currentAssetFormatId = attributeDict["format"]
            }
        } else if cleanName == "media-rep" {
            // Check if we are inside an asset and look for src
            if currentAssetId != nil {
                if let src = attributeDict["src"] {
                    // Prefer original-media, or take if no src found yet
                    let kind = attributeDict["kind"]
                    if kind == "original-media" || currentAssetSrc == nil {
                        currentAssetSrc = src
                    }
                }
            }
        } else if cleanName == "format" {
             if let id = attributeDict["id"], let width = attributeDict["width"], let height = attributeDict["height"] {
                 let w = Int(width) ?? 1920
                 let h = Int(height) ?? 1080
                 formats[id] = (w, h)
                 
                 // Also set project default if not set (or just take the first one as main)
                 // Usually the sequence format is what matters, but for now let's just keep the last one or default
                 project.width = w
                 project.height = h
             }
        } else if cleanName == "video" || cleanName == "asset-clip" || cleanName == "title" {
            // Basic clip handling
            // Titles might not have 'ref' but usually have 'name', 'offset', 'duration'
            let name = attributeDict["name"] ?? "Untitled"
            let ref = attributeDict["ref"] ?? "" // Titles might not have ref
            let offset = parseTime(attributeDict["offset"] ?? "0s")
            let duration = parseTime(attributeDict["duration"] ?? "0s")
            let start = parseTime(attributeDict["start"] ?? "0s")
            
            print("DEBUG: Found clip/title \(name) ref \(ref)")
            
            var clip = FCPXMLClip(name: name, ref: ref, offset: offset, duration: duration, start: start, text: nil)
            
            if cleanName == "title" {
                currentClip = clip
            } else {
                project.clips.append(clip)
            }
        } else if cleanName == "text" {
            isParsingText = true
            currentText = ""
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isParsingText {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let cleanName = elementName.components(separatedBy: ":").last ?? elementName
        
        if cleanName == "text" {
            isParsingText = false
            if var clip = currentClip {
                let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedText.isEmpty {
                    if clip.text == nil {
                        clip.text = trimmedText
                    } else {
                        clip.text! += trimmedText
                    }
                }
                currentClip = clip
            }
        } else if cleanName == "title" {
            if let clip = currentClip {
                project.clips.append(clip)
                currentClip = nil
            }
        } else if cleanName == "asset" {
            if let id = currentAssetId, let src = currentAssetSrc {
                print("DEBUG: Found asset \(id) - \(src)")
                
                var width = 0
                var height = 0
                if let formatId = currentAssetFormatId, let dims = formats[formatId] {
                    width = dims.width
                    height = dims.height
                }
                
                let asset = FCPXMLAsset(id: id, src: src, start: currentAssetStart, duration: currentAssetDuration, width: width, height: height)
                project.assets.append(asset)
            }
            // Reset asset state
            currentAssetId = nil
            currentAssetSrc = nil
            currentAssetStart = 0.0
            currentAssetDuration = 0.0
            currentAssetFormatId = nil
        }
    }
}
import Foundation

class MotionProjectGenerator {
    
    static func generateProject(for mediaURL: URL, outputURL: URL) throws {
        // Single file fallback
        let asset = FCPXMLAsset(id: "1", src: mediaURL.absoluteString, start: 0.0, duration: 10.0)
        let clip = FCPXMLClip(name: mediaURL.lastPathComponent, ref: "1", offset: 0.0, duration: 10.0, start: 0.0, text: nil)
        let project = FCPXMLProject(assets: [asset], clips: [clip])
        try generateProject(from: project, outputURL: outputURL)
    }

    static func generateProject(from project: FCPXMLProject, outputURL: URL) throws {
        // Map FCPXML IDs to Motion Integer IDs
        var idMap: [String: Int] = [:]
        var nextId = 10000 // Start IDs higher to avoid conflicts
        
        let timeScale = 30000.0
        
        // Generate Footage/Clips
        var clipsXML = ""
        for asset in project.assets {
            let mediaId = nextId
            idMap[asset.id] = mediaId
            nextId += 1
            
            let width = asset.width > 0 ? asset.width : project.width
            let height = asset.height > 0 ? asset.height : project.height
            
            // Calculate clip timing based on asset start/duration
            // Offset in footage clip is negative of asset start time
            let assetStartFrames = Int(asset.start * timeScale)
            let assetDurationFrames = Int(asset.duration * timeScale)
            let footageOffset = -assetStartFrames
            
            // Note: pathURL needs to be a file URL string
            clipsXML += """
                <clip name="\(URL(string: asset.src)?.lastPathComponent ?? "Media")" id="\(mediaId)">
                    <pathURL>\(asset.src)</pathURL>
                    <missingWidth>\(width)</missingWidth>
                    <missingHeight>\(height)</missingHeight>
                    <missingDuration>\(asset.duration)</missingDuration>
                    <creationDuration>0.000000</creationDuration>
                    <timing in="0 \(Int(timeScale)) 1 0" out="\(assetDurationFrames) \(Int(timeScale)) 1 0" offset="\(footageOffset) \(Int(timeScale)) 1 0"></timing>
                    <parameter name="Object" id="2">
                        <parameter name="Pixel Aspect Ratio" id="104" value="1.000000"></parameter>
                        <parameter name="Field Order" id="105" value="0.000000"></parameter>
                    </parameter>
                </clip>
            """
        }
        
        var sceneNodes = ""
        // Create asset map for quick lookup
        let assetMap = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.id, $0) })
        
        var currentId = 11000
        
        for clip in project.clips {
            let groupId = currentId
            let nodeId = currentId + 1
            currentId += 2
            
            // Timeline position is determined by clip.offset
            let inTime = Int(clip.offset * timeScale)
            let durationFrames = Int(clip.duration * timeScale)
            let outTime = inTime + durationFrames
            
            // Determine if it's a text clip or video clip
            if let textContent = clip.text {
                // Text Node
                sceneNodes += """
                    <group name="Group-\(clip.name)" id="\(groupId)">
                        <scenenode name="\(clip.name)" id="\(nodeId)" factoryID="8">
                            <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="0 1 1 0"></timing>
                    <style name="Style" id="1" factoryID="7">
                        <parameter name="Font" id="83">
                            <font>Helvetica</font>
                            <defaultFont>Helvetica</defaultFont>
                        </parameter>
                        <parameter name="Size" id="3" value="100"></parameter>
                        <parameter name="Face" id="14">
                            <parameter name="Color" id="16">
                                <parameter name="Red" id="1" value="1"></parameter>
                                <parameter name="Green" id="2" value="1"></parameter>
                                <parameter name="Blue" id="3" value="1"></parameter>
                            </parameter>
                        </parameter>
                    </style>
                    <parameter name="Object" id="2">
                        <parameter name="Text" id="369">
                            <text>\(clip.text ?? "")</text>
                        </parameter>
                    </parameter>
                        </scenenode>
                    </group>
                """
            } else {
                // Video Node
                var sourceId = 0
                var width = Double(project.width)
                var height = Double(project.height)
                var nodeOffset = 0
                
                if let asset = assetMap[clip.ref] {
                    if let assetIndex = project.assets.firstIndex(where: { $0.id == clip.ref }) {
                        sourceId = 10000 + assetIndex
                    }
                    if asset.width > 0 { width = Double(asset.width) }
                    if asset.height > 0 { height = Double(asset.height) }
                    
                    // Calculate offset for scenenode
                    // We want the media at (clip.start - asset.start) to appear at clip.offset
                    // Motion Offset = TimelineTime - MediaLocalTime
                    // MediaLocalTime = clip.start - asset.start
                    // Motion Offset = clip.offset - (clip.start - asset.start)
                    // Motion Offset = clip.offset - clip.start + asset.start
                    
                    let clipOffsetFrames = Int(clip.offset * timeScale)
                    let clipStartFrames = Int(clip.start * timeScale)
                    let assetStartFrames = Int(asset.start * timeScale)
                    
                    nodeOffset = clipOffsetFrames - clipStartFrames + assetStartFrames
                }
                
                sceneNodes += """
                    <group name="Group-\(clip.name)" id="\(groupId)">
                        <scenenode name="\(clip.name)" id="\(nodeId)" factoryID="1">
                            <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="\(nodeOffset) \(Int(timeScale)) 1 0"></timing>
                            <parameter name="Properties" id="1">
                                <parameter name="Media" id="300" value="\(sourceId).000000"></parameter>
                            </parameter>
                            <parameter name="Object" id="2">
                                <parameter name="Width" id="313" value="\(width)"></parameter>
                                <parameter name="Height" id="314" value="\(height)"></parameter>
                            </parameter>
                        </scenenode>
                    </group>
                """
            }
        }

        let template = """
<?xml version="1.0" encoding="UTF-8"?>
<ozml version="5.7">
  <factory id="1" uuid="66fc0d6af6a911d6a7a7000393670732">
    <description>Image</description>
  </factory>
    <factory id="3" uuid="6b337e9c21aa11d7a08700039375d2ba">
    <description>Master</description>
  </factory>
  <factory id="7" uuid="044beba5ad3211d7ac9b000393833f6a">
    <description>Style</description>
  </factory>
  <factory id="8" uuid="babfc7777f4711d7aaa7000393833f6a">
    <description>Text</description>
  </factory>
  <scene>
    <sceneSettings>
      <width>\(project.width)</width>
      <height>\(project.height)</height>
      <duration>\(Int(project.duration * timeScale))</duration>
      <frameRate>\(project.frameRate)</frameRate>
      <NTSC>1</NTSC>
      <channels>4</channels>
      <audioChannels>2</audioChannels>
      <audioBitsPerSample>32</audioBitsPerSample>
      <pixelAspectRatio>1.000000</pixelAspectRatio>
      <fieldRenderingMode>0</fieldRenderingMode>
      <startTimecode>0.000000</startTimecode>
      <workingGamut>0</workingGamut>
      <viewGamut>0</viewGamut>
    </sceneSettings>
    <currentFrame>0 \(Int(timeScale)) 1 0</currentFrame>
    <timeRange offset="0 \(Int(timeScale)) 1 0" duration="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0"></timeRange>
    <playRange offset="0 \(Int(timeScale)) 1 0" duration="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0"></playRange>
    \(sceneNodes)
    <scenenode name="Master" factoryID="3" id="9999">
        <flags>0</flags>
        <foldFlags>0</foldFlags>
        <baseFlags>524304</baseFlags>
        <timing in="0 \(Int(timeScale)) 1 0" out="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0" offset="0 \(Int(timeScale)) 1 0"></timing>
        <parameter name="Properties" id="1"></parameter>
        <parameter name="Object" id="2"></parameter>
    </scenenode>
    <footage>
    \(clipsXML)
    </footage>
  </scene>
</ozml>
"""
        try template.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}

// Test Expanded Tags
let outputURL = URL(fileURLWithPath: "/Users/shingo/Xcode_Local/git/Moplug_On_Motion/test_expanded.motn")

var project = FCPXMLProject()
project.width = 1920
project.height = 1080
project.frameRate = 30.0
project.duration = 100.0

do {
    try MotionProjectGenerator.generateProject(from: project, outputURL: outputURL)
    let xml = try String(contentsOf: outputURL, encoding: .utf8)
    
    print("--- Master Node ---")
    if let range = xml.range(of: "<scenenode name=\"Master\"") {
        print("Found Master Node")
    } else {
        print("Master Node NOT FOUND")
    }
    
    print("
--- Parameter Tags ---")
    if xml.contains("</parameter>") {
        print("Found expanded parameter tags")
    } else {
        print("Expanded parameter tags NOT FOUND")
    }

    print("
--- Timing Tags ---")
    if xml.contains("</timing>") {
        print("Found expanded timing tags")
    } else {
        print("Expanded timing tags NOT FOUND")
    }
    
} catch {
    print("Error: \(error)")
}

