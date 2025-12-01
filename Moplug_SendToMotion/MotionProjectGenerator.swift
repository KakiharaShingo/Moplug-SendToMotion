import Foundation

class MotionProjectGenerator {
    
    static func generateProject(for mediaURL: URL, outputURL: URL) throws {
        // Single file fallback
        let asset = FCPXMLAsset(id: "1", src: mediaURL.absoluteString, start: 0.0, duration: 10.0)
        let clip = FCPXMLClip(name: mediaURL.lastPathComponent, ref: "1", offset: 0.0, duration: 10.0, start: 0.0, text: nil, type: "video")
        let project = FCPXMLProject(assets: [asset], clips: [clip])
        try generateProject(from: project, outputURL: outputURL)
    }

    static func generateProject(from project: FCPXMLProject, outputURL: URL) throws {
        // Map FCPXML IDs to Motion Integer IDs
        var idMap: [String: Int] = [:]
        var nextId = 10000 // Start IDs higher to avoid conflicts
        
        let timeScale = 30000.0
        let ticksPerFrame = timeScale / project.frameRate
        
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
            
            // Ensure pathURL is a valid file URL
            var pathURLString = asset.src
            if let url = URL(string: asset.src), url.scheme == nil {
                // If no scheme, assume file path
                pathURLString = URL(fileURLWithPath: asset.src).absoluteString
            } else if !asset.src.hasPrefix("file://") {
                 // Fallback for simple paths
                 pathURLString = URL(fileURLWithPath: asset.src).absoluteString
            }
            
            clipsXML += """
                <clip name="\(URL(string: asset.src)?.lastPathComponent ?? "Media")" id="\(mediaId)">
                    <pathURL>\(pathURLString)</pathURL>
                    <missingWidth>\(width)</missingWidth>
                    <missingHeight>\(height)</missingHeight>
                    <missingDuration>\(asset.duration)</missingDuration>
                    <missingDynamicRangeType>0</missingDynamicRangeType>
                    <creationDuration>0</creationDuration>
                    <mediaID></mediaID>
                    <flags>0</flags>
                    <timing in="0 \(Int(timeScale)) 1 0" out="\(assetDurationFrames) \(Int(timeScale)) 1 0" offset="\(footageOffset) \(Int(timeScale)) 1 0"/>
                    <foldFlags>0</foldFlags>
                    <baseFlags>524304</baseFlags>
                    <parameter name="情報" id="1" flags="8589938704"/>
                    <parameter name="オブジェクト" id="2" flags="8589938704">
                        <parameter name="ピクセルのアスペクト比" id="104" flags="12884901888" default="1" value="1"/>
                    </parameter>
                </clip>
            """
        }
        
        var sceneNodes = ""
        var audioTracksXML = ""
        
        // Create asset map for quick lookup
        let assetMap = Dictionary(uniqueKeysWithValues: project.assets.map { ($0.id, $0) })
        
        var currentId = 11000
        
        for clip in project.clips {
            let groupId = currentId
            let nodeId = currentId + 1
            currentId += 2
            
            // Timeline position is determined by clip.offset
            let inTime = Int(clip.offset * timeScale)
            
            // Align duration to frame grid (round up to nearest frame)
            // This matches XsendMotion behavior where audio/video duration is snapped to frame boundaries
            let rawDurationTicks = clip.duration * timeScale
            let frameCount = ceil(rawDurationTicks / ticksPerFrame)
            let durationFrames = Int(frameCount * ticksPerFrame)
            
            // Motion uses exclusive out point (start of the last frame), so subtract 1 frame tick
            let outTime = inTime + durationFrames - Int(ticksPerFrame)
            
            // Determine if it's a text clip or video clip
            if clip.type == "title" {
                // Text Node
                sceneNodes += """
                    <group name="\(clip.name)" id="\(groupId)">
                        <scenenode name="\(clip.name)" id="\(nodeId)" factoryID="18" version="0">
                            <aspectRatio>0</aspectRatio>
                            <flags>0</flags>
                            <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="0 1 1 0"/>
                            <foldFlags>0</foldFlags>
                            <baseFlags>34078736</baseFlags>
                            <style name="Style" id="1" factoryID="1">
                                <copyFlags>65535</copyFlags>
                                <previewWidth>0</previewWidth>
                                <previewHeight>0</previewHeight>
                                <presetName>標準</presetName>
                                <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="0 1 1 0"/>
                                <baseFlags>8657043504</baseFlags>
                                <foldFlags>786432</foldFlags>
                                <parameter name="フォント" id="83" flags="12884906000">
                                    <font>Helvetica</font>
                                    <defaultFont>Helvetica</defaultFont>
                                </parameter>
                                <parameter name="サイズ" id="3" flags="8589934608" default="48" value="100"/>
                            </style>
                            <styleRun style="1" offset="0" length="\((clip.text ?? "").count)"/>
                            <parameter name="情報" id="1" flags="8589938704"/>
                            <parameter name="オブジェクト" id="2" flags="8589938704">
                                <parameter name="テキスト" id="369" flags="8590000128">
                                    <text>\(clip.text ?? "")</text>
                                </parameter>
                                <parameter name="テキストをレンダリング" id="360" flags="8590000146" default="0" value="0"/>
                            </parameter>
                        </scenenode>
                        <aspectRatio>1</aspectRatio>
                        <flags>0</flags>
                        <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="0 1 1 0"/>
                        <foldFlags>0</foldFlags>
                        <baseFlags>524304</baseFlags>
                        <parameter name="情報" id="1" flags="8589938704">
                            <parameter name="ライティング" id="230" flags="8589938706">
                                <foldFlags>15</foldFlags>
                            </parameter>
                            <parameter name="シャドウ" id="234" flags="8589938706">
                                <foldFlags>15</foldFlags>
                            </parameter>
                            <parameter name="反射" id="223" flags="8589971474">
                                <foldFlags>131087</foldFlags>
                            </parameter>
                        </parameter>
                        <parameter name="オブジェクト" id="2" flags="8589938704">
                            <parameter name="固定幅" id="302" flags="12884901908" default="\(project.width)" value="\(project.width)"/>
                            <parameter name="固定高さ" id="303" flags="12884901908" default="\(project.height)" value="\(project.height)"/>
                            <parameter name="平坦化" id="311" flags="8589934610" default="0" value="0"/>
                            <parameter name="レイヤーの順番" id="305" flags="8589934610" default="0" value="0"/>
                            <parameter name="絞りの幅" id="312" flags="12884901906" default="\(project.width)" value="\(project.width)"/>
                            <parameter name="絞りの高さ" id="313" flags="12884901906" default="\(project.height)" value="\(project.height)"/>
                            <parameter name="新規固定解像度ビヘイビア" id="315" flags="8594194480" default="1" value="0"/>
                        </parameter>
                    </group>
                """
            } else {
                // Video or Audio Node
                var sourceId = 0
                var width = Double(project.width)
                var height = Double(project.height)
                var nodeOffset = 0
                var hasAudio = false
                var isAudioOnly = false
                let audioTrackId = currentId
                currentId += 1
                
                if let asset = assetMap[clip.ref] {
                    if let assetIndex = project.assets.firstIndex(where: { $0.id == clip.ref }) {
                        sourceId = 10000 + assetIndex
                    }
                    if asset.width > 0 { width = Double(asset.width) }
                    if asset.height > 0 { height = Double(asset.height) }
                    
                    let ext = URL(string: asset.src)?.pathExtension.lowercased() ?? ""
                    let audioExtensions = ["wav", "mp3", "m4a", "aiff", "caf", "aac"]
                    let videoExtensions = ["mov", "mp4", "m4v", "avi"]
                    
                    if audioExtensions.contains(ext) {
                        hasAudio = true
                        isAudioOnly = true
                    } else if videoExtensions.contains(ext) {
                        hasAudio = true // Most video containers have audio, assume true for now or check metadata if possible
                        isAudioOnly = false
                    }
                    
                    // Calculate offset for scenenode
                    let clipOffsetFrames = Int(clip.offset * timeScale)
                    let clipStartFrames = Int(clip.start * timeScale)
                    let assetStartFrames = Int(asset.start * timeScale)
                    
                    nodeOffset = clipOffsetFrames - clipStartFrames + assetStartFrames
                }
                
                // Only generate Scene Node if it's NOT audio only
                if !isAudioOnly {
                    let linkedObjectTag = hasAudio ? "<linkedobjects>\(audioTrackId)</linkedobjects>" : ""
                    
                    // Calculate Retime Value keypoints
                    let startLocalTime = Double(inTime - nodeOffset)
                    let endLocalTime = Double(outTime - nodeOffset)
                    let startFrame = Int(startLocalTime / ticksPerFrame) + 1
                    let endFrame = Int(endLocalTime / ticksPerFrame) + 1
                    
                    sceneNodes += """
                        <group name="\(clip.name)" id="\(groupId)">
                            <scenenode name="\(clip.name)" id="\(nodeId)" factoryID="11" version="0">
                                <validTracks>1</validTracks>
                                <aspectRatio>0</aspectRatio>
                                <flags>0</flags>
                                \(linkedObjectTag)
                                <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="\(nodeOffset) \(Int(timeScale)) 1 0"/>
                                <foldFlags>16384</foldFlags>
                                <baseFlags>524304</baseFlags>
                                <parameter name="情報" id="1" flags="8589938704">
                                    <parameter name="メディア" id="324" flags="8589938704">
                                        <parameter name="ソースメディア" id="300" flags="77309476880" default="0" value="\(sourceId)"/>
                                        <parameter name="ソースメディア" id="325" flags="8590000146"/>
                                    </parameter>
                                    <parameter name="リタイミング値" id="304" flags="8590066066">
                                        <curve type="1" default="1" value="1" round="0">
                                            <numberOfKeypoints>2</numberOfKeypoints>
                                            <keypoint flags="0">
                                                <time>\(inTime - nodeOffset) \(Int(timeScale)) 1 0</time>
                                                <value>\(startFrame)</value>
                                            </keypoint>
                                            <keypoint flags="0">
                                                <time>\(outTime - nodeOffset) \(Int(timeScale)) 1 0</time>
                                                <value>\(endFrame)</value>
                                            </keypoint>
                                        </curve>
                                    </parameter>
                                    <parameter name="リタイミング値のキャッシュ" id="319" flags="8590065810" default="1" value="1"/>
                                </parameter>
                                <parameter name="オブジェクト" id="2" flags="8589938704">
                                    <parameter name="幅" id="313" flags="8589934610" default="1" value="\(Int(width))"/>
                                    <parameter name="高さ" id="314" flags="8589934610" default="1" value="\(Int(height))"/>
                                </parameter>
                            </scenenode>
                            <aspectRatio>1</aspectRatio>
                            <flags>0</flags>
                            <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="0 1 1 0"/>
                            <foldFlags>0</foldFlags>
                            <baseFlags>524304</baseFlags>
                            <parameter name="情報" id="1" flags="8589938704">
                                <parameter name="ライティング" id="230" flags="8589938706">
                                    <foldFlags>15</foldFlags>
                                </parameter>
                                <parameter name="シャドウ" id="234" flags="8589938706">
                                    <foldFlags>15</foldFlags>
                                </parameter>
                                <parameter name="反射" id="223" flags="8589971474">
                                    <foldFlags>131087</foldFlags>
                                </parameter>
                            </parameter>
                            <parameter name="オブジェクト" id="2" flags="8589938704">
                                <parameter name="固定幅" id="302" flags="12884901908" default="\(project.width)" value="\(project.width)"/>
                                <parameter name="固定高さ" id="303" flags="12884901908" default="\(project.height)" value="\(project.height)"/>
                                <parameter name="平坦化" id="311" flags="8589934610" default="0" value="0"/>
                                <parameter name="レイヤーの順番" id="305" flags="8589934610" default="0" value="0"/>
                                <parameter name="絞りの幅" id="312" flags="12884901906" default="\(project.width)" value="\(project.width)"/>
                                <parameter name="絞りの高さ" id="313" flags="12884901906" default="\(project.height)" value="\(project.height)"/>
                                <parameter name="新規固定解像度ビヘイビア" id="315" flags="8594194480" default="1" value="0"/>
                            </parameter>
                        </group>
                    """
                }
                
                if hasAudio {
                    let linkedObjectTag = isAudioOnly ? "" : "<linkedobjects>\(nodeId)</linkedobjects>"
                    
                    // For audio tracks, we also need retime value
                    // If it's audio only, we calculate frames same way
                    let startLocalTime = Double(inTime - nodeOffset)
                    let endLocalTime = Double(outTime - nodeOffset)
                    let startFrame = Int(startLocalTime / ticksPerFrame) + 1
                    let endFrame = Int(endLocalTime / ticksPerFrame) + 1

                    audioTracksXML += """
                        <audioTrack name="\(clip.name)" id="\(audioTrackId)">
                            \(linkedObjectTag)
                            <flags>0</flags>
                            <timing in="\(inTime) \(Int(timeScale)) 1 0" out="\(outTime) \(Int(timeScale)) 1 0" offset="\(nodeOffset) \(Int(timeScale)) 1 0"/>
                            <foldFlags>16384</foldFlags>
                            <baseFlags>524304</baseFlags>
                            <parameter name="情報" id="1" flags="8589938704">
                                <parameter name="メディア" id="324" flags="8589938704">
                                    <parameter name="ソースメディア" id="104" flags="77309476880" default="0" value="\(sourceId)"/>
                                    <parameter name="ソースメディア" id="325" flags="8590000146"/>
                                </parameter>
                                <parameter name="スピード" id="111" flags="8589967376" default="1" value="1"/>
                                <parameter name="リタイミング値" id="304" flags="8590066066">
                                    <curve type="1" default="1" value="1" round="0">
                                        <numberOfKeypoints>2</numberOfKeypoints>
                                        <keypoint flags="0">
                                            <time>\(inTime - nodeOffset) \(Int(timeScale)) 1 0</time>
                                            <value>\(startFrame)</value>
                                        </keypoint>
                                        <keypoint flags="0">
                                            <time>\(outTime - nodeOffset) \(Int(timeScale)) 1 0</time>
                                            <value>\(endFrame)</value>
                                        </keypoint>
                                    </curve>
                                </parameter>
                                <parameter name="リタイミング値のキャッシュ" id="319" flags="8590065810" default="1" value="1"/>
                            </parameter>
                            <parameter name="オブジェクト" id="2" flags="8589938704">
                                <parameter name="レベル" id="102" flags="8589967376" default="1" value="1"/>
                            </parameter>
                        </audioTrack>
                    """
                }
            }
        }

        let template = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE ozxmlscene>
<ozml version="5.14">
  <displayversion>5.10</displayversion>

  <factory id="1" uuid="044beba5ad3211d7ac9b000393833f6a">
    <description>スタイル</description>
    <manufacturer>Apple</manufacturer>
    <version>1</version>
  </factory>
  <factory id="11" uuid="66fc0d6af6a911d6a7a7000393670732">
    <description>イメージ</description>
    <manufacturer>Apple</manufacturer>
    <version>1</version>
  </factory>
  <factory id="13" uuid="6b337e9c21aa11d7a08700039375d2ba">
    <description>出力</description>
    <manufacturer>Apple</manufacturer>
    <version>1</version>
  </factory>
  <factory id="17" uuid="aee0a63927494ed19a9667c9f83badfd">
    <description>素材</description>
    <manufacturer>Apple</manufacturer>
    <version>1</version>
  </factory>
  <factory id="18" uuid="babfc7777f4711d7aaa7000393833f6a">
    <description>テキスト</description>
    <manufacturer>Apple</manufacturer>
    <version>1</version>
  </factory>

  <build></build>
  <description></description>

  <canvas>
    <layout>1</layout>
    <activeView>0</activeView>
  </canvas>

  <viewer subview="0">
    <resolutionMode>0</resolutionMode>
    <dynamicResolution>1</dynamicResolution>
    <viewmode>0</viewmode>
    <overlayOptions>125452</overlayOptions>
    <oscOptions>30</oscOptions>
    <compensateAspectRatio>1</compensateAspectRatio>
    <renderFields>0</renderFields>
    <showMotionBlur>0</showMotionBlur>
    <showFrameBlending>1</showFrameBlending>
    <showLighting>1</showLighting>
    <showShadows>1</showShadows>
    <showReflection>1</showReflection>
    <showDepthOfField>0</showDepthOfField>
    <renderFullView>0</renderFullView>
    <renderQuality>2</renderQuality>
    <textRenderQuality>2</textRenderQuality>
    <showHighQualityResampling>0</showHighQualityResampling>
    <showShapeAntialiasing>1</showShapeAntialiasing>
    <show3DIntersectionAntialiasing>0</show3DIntersectionAntialiasing>
    <cameraType>0</cameraType>
    <cameraName>アクティブカメラ</cameraName>
    <mirrorHMD>0</mirrorHMD>
    <panZoom camera="0" zoom="0.66388887166976929" panX="186" panY="5" mode="2" centered="1"/>
  </viewer>

  <projectPanel>
    <layersPreviewColumn>1</layersPreviewColumn>
    <layersOpacityColumn>0</layersOpacityColumn>
    <layersBlendColumn>0</layersBlendColumn>
    <displayMasks>1</displayMasks>
    <displayBehaviors>1</displayBehaviors>
    <displayEffects>1</displayEffects>
    <layersVerticalZoom>1.7999999523162842</layersVerticalZoom>
    <mediaPreviewColumn>1</mediaPreviewColumn>
    <mediaTypeColumn>1</mediaTypeColumn>
    <mediaDurationColumn>1</mediaDurationColumn>
    <mediaInUseColumn>1</mediaInUseColumn>
    <mediaFrameSizeColumn>1</mediaFrameSizeColumn>
    <mediaCompressorColumn>1</mediaCompressorColumn>
    <mediaDepthColumn>1</mediaDepthColumn>
    <mediaFrameRateColumn>1</mediaFrameRateColumn>
    <mediaDataRateColumn>1</mediaDataRateColumn>
    <mediaAudioRateColumn>1</mediaAudioRateColumn>
    <mediaAudioFormatColumn>1</mediaAudioFormatColumn>
    <mediaFileSizeColumn>1</mediaFileSizeColumn>
    <mediaFileCreatedColumn>1</mediaFileCreatedColumn>
    <mediaDileModifiedColumn>1</mediaDileModifiedColumn>
    <mediaVerticalZoom>1.7999999523162842</mediaVerticalZoom>
  </projectPanel>

  <timeline>
    <displayVideo>1</displayVideo>
    <displayAudio>0</displayAudio>
    <displayKeyframes>0</displayKeyframes>
    <displayMasks>1</displayMasks>
    <displayBehaviors>1</displayBehaviors>
    <displayEffects>1</displayEffects>
    <videoVerticalZoom>2.2222222222222223</videoVerticalZoom>
    <audioVerticalZoom>2.2222222222222223</audioVerticalZoom>
    <displayRange in="-2552104997 1729492187 3 0" out="59300071684 1000000000 3 0"/>
  </timeline>

  <curveeditor>
    <autozoom>0</autozoom>
    <snapping>0</snapping>
    <displayAudioWaveform>0</displayAudioWaveform>
    <lockKeyframesInTime>0</lockKeyframesInTime>
    <displayRange in="-2552104997 1729492187 3 0" out="59300071684 1000000000 3 0"/>
    <currentviewvolume originx="-1.4756383499060004" originy="-62.5" width="60.775710033999999" height="125"/>
    <snapshotChannels>0</snapshotChannels>
  </curveeditor>

  <inspector>
    <collapseState id="./1/100" state="1"/>
    <collapseState id="./1/200" state="1"/>
    <collapseState id="./1/344" state="1"/>
  </inspector>

  <scene>
    <sceneSettings>
      <width>\(project.width)</width>
      <height>\(project.height)</height>
      <duration>\(Int(project.duration * timeScale))</duration>
      <shouldOverrideFCDuration>0</shouldOverrideFCDuration>
      <frameRate>\(project.frameRate)</frameRate>
      <NTSC>1</NTSC>
      <pixelAspectRatio>1</pixelAspectRatio>
      <workingGamut>0</workingGamut>
      <viewGamut>0</viewGamut>
      <optimizeForDisplay>0</optimizeForDisplay>
      <backgroundColor red="0" green="0" blue="0" alpha="1"/>
      <audioChannels>2</audioChannels>
      <audioBitsPerSample>32</audioBitsPerSample>
      <fieldRenderingMode>0</fieldRenderingMode>
      <motionBlurSamples>8</motionBlurSamples>
      <motionBlurDuration>1</motionBlurDuration>
      <sharpScaling>0</sharpScaling>
      <startTimecode>0</startTimecode>
      <presetPath></presetPath>
      <backgroundMode>0</backgroundMode>
      <reflectionRecursionLimit>2</reflectionRecursionLimit>
      <glyphOSCMode>0</glyphOSCMode>
      <animateFlag>0</animateFlag>
      <parameterColorSpaceID>3</parameterColorSpaceID>
      <savePreviewMovie>0</savePreviewMovie>
      <Object3DEnvironments>100</Object3DEnvironments>
      <DRTSupport>0</DRTSupport>
      <onHDRDisplay>0</onHDRDisplay>
    </sceneSettings>
    <publishSettings>
      <version>2</version>
    </publishSettings>
    <currentFrame>0 \(Int(timeScale)) 1 0</currentFrame>
    <activeLayer>0</activeLayer>
    <timeRange offset="0 \(Int(timeScale)) 1 0" duration="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0"/>
    <playRange offset="0 \(Int(timeScale)) 1 0" duration="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0"/>
    <flags>1</flags>
    <audioTracks>28</audioTracks>
    <timemarkerset/>
    <guideset/>
    <curvesets selected="1"/>
    \(sceneNodes)
    <scenenode name="Master" factoryID="13" id="9999">
        <flags>0</flags>
        <timing in="0 \(Int(timeScale)) 1 0" out="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0" offset="0 \(Int(timeScale)) 1 0"/>
        <foldFlags>0</foldFlags>
        <baseFlags>524304</baseFlags>
        <parameter name="情報" id="1" flags="8589938704"/>
        <parameter name="オブジェクト" id="2" flags="8589938704"/>
    </scenenode>
    <audio name="Audio Layer" id="11042">
        \(audioTracksXML)
        <scenenode name="Master" factoryID="13" id="9998">
            <flags>0</flags>
            <timing in="0 \(Int(timeScale)) 1 0" out="\(Int(project.duration * timeScale)) \(Int(timeScale)) 1 0" offset="0 \(Int(timeScale)) 1 0"/>
            <foldFlags>0</foldFlags>
            <baseFlags>524304</baseFlags>
            <parameter name="情報" id="1" flags="8589938704"/>
            <parameter name="オブジェクト" id="2" flags="8589938704"/>
        </scenenode>
        <flags>0</flags>
        <timing in="0 1 1 0" out="-4004 120000 1 0" offset="0 1 1 0"/>
        <foldFlags>0</foldFlags>
        <baseFlags>524304</baseFlags>
        <parameter name="情報" id="1" flags="8589938704"/>
        <parameter name="オブジェクト" id="2" flags="8589938704"/>
    </audio>

    <footage name="" id="3">
\(clipsXML)
    </footage>
  </scene>
</ozml>
"""
        try template.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
