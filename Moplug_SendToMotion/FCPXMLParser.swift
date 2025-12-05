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
    let offset: Double // Absolute timeline start time (or relative if inside a resource)
    let duration: Double
    let start: Double // Source start time
    var text: String?
    let type: String // "video", "asset-clip", "title", "ref-clip"
    var lane: Int = 0
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
    
    // Resource parsing state
    private var isParsingResources = false
    private var currentMediaId: String?
    private var mediaDefinitions: [String: [FCPXMLClip]] = [:]
    
    // Nested clip context
    struct ClipContext {
        let absoluteStart: Double // When this clip starts on the main timeline
        let sourceStart: Double   // The 'start' attribute of this clip (time into its source)
    }
    private var contextStack: [ClipContext] = []
    
    static func parse(url: URL) -> FCPXMLProject? {
        let parser = FCPXMLParser()
        if let project = parser.parseFile(url: url) {
            // Calculate project start time (minimum of all clips)
            var minStart = Double.greatestFiniteMagnitude
            for clip in project.clips {
                if clip.offset < minStart {
                    minStart = clip.offset
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
        
        // print("DEBUG: Found element \(cleanName)")
        
        if cleanName == "resources" {
            isParsingResources = true
        } else if cleanName == "media" {
            if isParsingResources, let id = attributeDict["id"] {
                currentMediaId = id
                mediaDefinitions[id] = []
            }
        } else if cleanName == "asset" {
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
             if let id = attributeDict["id"] {
                 var w = 1920
                 var h = 1080
                 if let width = attributeDict["width"], let height = attributeDict["height"] {
                     w = Int(width) ?? 1920
                     h = Int(height) ?? 1080
                 }
                 formats[id] = (w, h)
                 
                 // Set project dimensions
                 project.width = w
                 project.height = h
                 
                 // Parse frame rate
                 if let frameDuration = attributeDict["frameDuration"] {
                     let duration = parseTime(frameDuration)
                     if duration > 0 {
                         project.frameRate = 1.0 / duration
                     }
                 }
             }
        } else if cleanName == "sequence" {
            if !isParsingResources {
                if let durationString = attributeDict["duration"] {
                    project.duration = parseTime(durationString)
                }
            }
        } else if cleanName == "video" || cleanName == "asset-clip" || cleanName == "title" || cleanName == "ref-clip" {
            // Basic clip handling
            let name = attributeDict["name"] ?? "Untitled"
            let ref = attributeDict["ref"] ?? "" // Titles might not have ref
            let offset = parseTime(attributeDict["offset"] ?? "0s")
            let duration = parseTime(attributeDict["duration"] ?? "0s")
            let start = parseTime(attributeDict["start"] ?? "0s")
            let lane = Int(attributeDict["lane"] ?? "0") ?? 0
            
            // Calculate absolute timeline start time
            var absoluteOffset = offset
            if let parent = contextStack.last {
                // ChildSeqStart = ParentSeqStart + (ChildOffset - ParentStart)
                absoluteOffset = parent.absoluteStart + (offset - parent.sourceStart)
            }
            
            // Push context for potential children
            contextStack.append(ClipContext(absoluteStart: absoluteOffset, sourceStart: start))
            
            // print("DEBUG: Found clip/title \(name) ref \(ref) absOffset \(absoluteOffset) type \(cleanName)")
            
            let clip = FCPXMLClip(name: name, ref: ref, offset: absoluteOffset, duration: duration, start: start, text: nil, type: cleanName, lane: lane)
            
            if isParsingResources {
                if let mediaId = currentMediaId {
                    // Store in definition, relative to its container (offset is relative here)
                    // Note: For definitions, we want the offset as is, not absolute.
                    // But our calculation above used contextStack.
                    // Inside a media definition, the context stack should be empty or relative to the media.
                    // Since we process media definitions sequentially, contextStack should be managed correctly.
                    // However, 'absoluteOffset' here means 'relative to the start of the media timeline'.
                    mediaDefinitions[mediaId]?.append(clip)
                }
            } else {
                // Main project parsing
                if cleanName == "ref-clip" {
                    // Expand ref-clip
                    if let referencedClips = mediaDefinitions[ref] {
                        for subClip in referencedClips {
                            // Calculate new absolute offset for the subclip
                            // NewOffset = RefClip.AbsoluteStart + (SubClip.Offset - RefClip.Start)
                            let newOffset = absoluteOffset + (subClip.offset - start)
                            
                            // Create a new clip instance with adjusted offset
                            // We keep the subClip's duration and start (source time)
                            let newClip = FCPXMLClip(
                                name: subClip.name,
                                ref: subClip.ref,
                                offset: newOffset,
                                duration: subClip.duration,
                                start: subClip.start,
                                text: subClip.text,
                                type: subClip.type,
                                lane: clip.lane + subClip.lane
                            )
                            project.clips.append(newClip)
                            print("DEBUG: Expanded ref-clip \(name) -> \(subClip.name) at \(newOffset)")
                        }
                    } else {
                        print("WARNING: ref-clip references unknown media \(ref)")
                    }
                } else {
                    if cleanName == "title" {
                        currentClip = clip
                    } else {
                        project.clips.append(clip)
                    }
                }
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
        
        if cleanName == "resources" {
            isParsingResources = false
        } else if cleanName == "media" {
            currentMediaId = nil
        } else if cleanName == "text" {
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
                if isParsingResources {
                    if let mediaId = currentMediaId {
                        mediaDefinitions[mediaId]?.append(clip)
                    }
                } else {
                    project.clips.append(clip)
                }
                currentClip = nil
            }
            // Pop context
            if !contextStack.isEmpty {
                contextStack.removeLast()
            }
        } else if cleanName == "video" || cleanName == "asset-clip" || cleanName == "ref-clip" {
            // Pop context
            if !contextStack.isEmpty {
                contextStack.removeLast()
            }
        } else if cleanName == "asset" {
            if let id = currentAssetId, let src = currentAssetSrc {
                // print("DEBUG: Found asset \(id) - \(src)")
                
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
