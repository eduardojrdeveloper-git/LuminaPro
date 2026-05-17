import Flutter
import UIKit
import AVFoundation
import MediaPlayer
import Accelerate
import Gobackend  // Import Go framework

@main
@objc class AppDelegate: FlutterAppDelegate {
var engine = AVAudioEngine()
    var playerNode = AVAudioPlayerNode()
    var eqNode = AVAudioUnitEQ(numberOfBands: 10)
    var positionChannel: FlutterEventChannel?
    var stateChannel: FlutterEventChannel?
    var positionSink: FlutterEventSink?
    var stateSink: FlutterEventSink?
    var methodChannel: FlutterMethodChannel?
    
    var currentTimer: Timer?
    var audioFile: AVAudioFile?
    
    var currentTitle: String = "Unknown"
    var currentArtist: String = "Unknown"
    var currentAlbum: String = "Unknown"
    var currentPath: String = ""
    var currentCoverArt: Data?
    var isSeeking = false
    
    // FIX: Track seek offset so position reports are correct after playerNode.stop()
    // playerNode.playerTime.sampleTime resets to 0 after each stop/play cycle.
    // seekOffsetMs is the base position we seeked to; elapsed is added on top.
    var seekOffsetMs: Int = 0

    private let CHANNEL = "com.zarz.spotiflac/backend"
    private let DOWNLOAD_PROGRESS_STREAM_CHANNEL = "com.zarz.spotiflac/download_progress_stream"
    private let LIBRARY_SCAN_PROGRESS_STREAM_CHANNEL = "com.zarz.spotiflac/library_scan_progress_stream"
    private let LARGE_JSON_RESULT_FILE_KEY = "__json_file"
    private let LARGE_JSON_RESULT_FILE_THRESHOLD_BYTES = 256 * 1024
    private let streamQueue = DispatchQueue(label: "com.zarz.spotiflac.progress_stream", qos: .utility)
    private var downloadProgressTimer: DispatchSourceTimer?
    private var downloadProgressEventSink: FlutterEventSink?
    private var lastDownloadProgressPayload: String?
    private var lastDownloadProgressSeq: Int64 = 0
    private var libraryScanProgressTimer: DispatchSourceTimer?
    private var libraryScanProgressEventSink: FlutterEventSink?
    private var lastLibraryScanProgressPayload: String?
    
    /// Currently accessed security-scoped URL for library folder
    private var activeSecurityScopedURL: URL?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            GobackendSetAppVersion(version)
        }
        
        let controller = window?.rootViewController as! FlutterViewController

methodChannel = FlutterMethodChannel(name: "com.luminapro/audio", binaryMessenger: controller.binaryMessenger)
        positionChannel = FlutterEventChannel(name: "com.luminapro/audio_position", binaryMessenger: controller.binaryMessenger)
        stateChannel = FlutterEventChannel(name: "com.luminapro/audio_state", binaryMessenger: controller.binaryMessenger)
        
        positionChannel?.setStreamHandler(PositionStreamHandler(appDelegate: self))
        stateChannel?.setStreamHandler(StateStreamHandler(appDelegate: self))
        
        setupAudioEngine()
        setupRemoteCommandCenter()
        
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            // Pause on disconnect. User manually resumes. Maintains position.
            if reason == .oldDeviceUnavailable {
                self.pauseAudio()
                self.methodChannel?.invokeMethod("playPause", arguments: nil)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateAudioPathInfo()
            }
        }
        
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            guard let self = self else { return }
            let wasPlaying = self.playerNode.isPlaying
            self.isSeeking = true // Prevent 'finished' callback triggering track change
            self.setupAudioEngine() 
            if wasPlaying {
                self.resumeAudio()
            }
            self.isSeeking = false
            self.updateAudioPathInfo()
        }

methodChannel?.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            guard let self = self else { return }
            switch call.method {
            case "play":
                if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
                    self.currentTitle = args["title"] as? String ?? "Unknown"
                    self.currentArtist = args["artist"] as? String ?? "Unknown"
                    self.currentAlbum = args["album"] as? String ?? "Unknown"
                    self.currentPath = path
                    if let coverData = args["coverArt"] as? FlutterStandardTypedData {
                        self.currentCoverArt = coverData.data
                    } else {
                        self.currentCoverArt = nil
                    }
                    self.playAudio(path: path)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "updateEQFromContent":
                if let args = call.arguments as? [String: Any], let content = args["content"] as? String {
                    // Parsing logic for APO text -> AVAudioUnitEQ
                    let lines = content.components(separatedBy: .newlines)
                    var bands: [[String: Any]] = []
                    for line in lines {
                        if line.contains("Filter:") && line.contains("ON") {
                            let parts = line.components(separatedBy: " ")
                            var fc: Double = 1000, gain: Double = 0, q: Double = 1, type = "PK"
                            if let fcIdx = parts.firstIndex(of: "Fc") { fc = Double(parts[fcIdx+1]) ?? 1000 }
                            if let gnIdx = parts.firstIndex(of: "Gain") { gain = Double(parts[gnIdx+1]) ?? 0 }
                            if let qIdx = parts.firstIndex(of: "Q") { q = Double(parts[qIdx+1]) ?? 1 }
                            if line.contains(" LSC") { type = "LSC" }
                            else if line.contains(" LS") { type = "LSC" } // Simplified
                            bands.append(["fc": fc, "gain": gain, "q": q, "type": type])
                        } else if line.contains("Preamp:") {
                            let parts = line.components(separatedBy: " ")
                            if let db = Double(parts.last?.replacingOccurrences(of: "dB", with: "") ?? "0") {
                                self.engine.mainMixerNode.outputVolume = Float(pow(10.0, db / 20.0))
                            }
                        }
                    }
                    self.updateEQ(bands: bands)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            // ... rest of cases ...
            case "pause":
                self.pauseAudio()
                result(nil)
            case "resume":
                self.resumeAudio()
                result(nil)
            case "seek":
                if let args = call.arguments as? [String: Any], let pos = args["position"] as? Int {
                    self.seekAudio(toMs: pos)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "updateEQ":
                if let args = call.arguments as? [String: Any], let bands = args["bands"] as? [[String: Any]] {
                    self.updateEQ(bands: bands)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "updatePreamp":
                if let args = call.arguments as? [String: Any], let db = args["gain"] as? Double {
                    self.engine.mainMixerNode.outputVolume = Float(pow(10.0, db / 20.0))
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "setVolume":
                if let args = call.arguments as? [String: Any], let volume = args["volume"] as? Double {
                    self.playerNode.volume = Float(volume)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "setPan":
                if let args = call.arguments as? [String: Any], let pan = args["pan"] as? Double {
                    self.playerNode.pan = Float(pan)
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "setMono":
                if let args = call.arguments as? [String: Any], let mono = args["mono"] as? Bool {
                    let wasPlaying = self.playerNode.isPlaying
                    if wasPlaying { self.playerNode.pause() }
                    
                    self.engine.disconnectNodeInput(self.eqNode)
                    if mono {
                        let hwFormat = self.engine.outputNode.outputFormat(forBus: 0)
                        let monoFormat = AVAudioFormat(standardFormatWithSampleRate: hwFormat.sampleRate, channels: 1)
                        self.engine.connect(self.playerNode, to: self.eqNode, format: monoFormat)
                    } else {
                        self.engine.connect(self.playerNode, to: self.eqNode, format: nil)
                    }
                    
                    if wasPlaying { self.playerNode.play() }
                    result(nil)
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            case "generateSpek":
                if let args = call.arguments as? [String: Any], let path = args["path"] as? String {
                    DispatchQueue.global(qos: .userInitiated).async {
                        if let imageBytes = self.generateSpectrogram(from: path) {
                            DispatchQueue.main.async { result(FlutterStandardTypedData(bytes: imageBytes)) }
                        } else {
                            DispatchQueue.main.async { result(FlutterError(code: "SPEK_ERROR", message: "Failed to generate", details: nil)) }
                        }
                    }
                } else { result(FlutterError(code: "INVALID_ARGS", message: nil, details: nil)) }
            default:
                result(FlutterMethodNotImplemented)
            }
        })

        let channel = FlutterMethodChannel(
            name: CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        let downloadProgressEvents = FlutterEventChannel(
            name: DOWNLOAD_PROGRESS_STREAM_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        let libraryScanProgressEvents = FlutterEventChannel(
            name: LIBRARY_SCAN_PROGRESS_STREAM_CHANNEL,
            binaryMessenger: controller.binaryMessenger
        )
        
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handleMethodCall(call: call, result: result)
        }
        downloadProgressEvents.setStreamHandler(
            ClosureStreamHandler(
                onListen: { [weak self] _, events in
                    self?.startDownloadProgressStream(events)
                    return nil
                },
                onCancel: { [weak self] _ in
                    self?.stopDownloadProgressStream()
                    return nil
                }
            )
        )
        libraryScanProgressEvents.setStreamHandler(
            ClosureStreamHandler(
                onListen: { [weak self] _, events in
                    self?.startLibraryScanProgressStream(events)
                    return nil
                },
                onCancel: { [weak self] _ in
                    self?.stopLibraryScanProgressStream()
                    return nil
                }
            )
        )
        
        GeneratedPluginRegistrant.register(with: self)
        if let url = launchOptions?[.url] as? URL {
            _ = handleExtensionOAuthRedirect(url: url)
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    /// PKCE OAuth return URL: spotiflac://callback?code=...&state=<extension_id>
    @discardableResult
    private func handleExtensionOAuthRedirect(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "spotiflac" else { return false }
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let ok =
            host == "callback" || host == "spotify-callback" || path.contains("callback")
        guard ok else { return false }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        let q = components.queryItems ?? []
        let code =
            q.first { $0.name == "code" }?.value?.trimmingCharacters(
                in: .whitespacesAndNewlines) ?? ""
        let state =
            q.first { $0.name == "state" }?.value?.trimmingCharacters(
                in: .whitespacesAndNewlines) ?? ""
        if code.isEmpty { return false }
        if state.isEmpty {
            NSLog("SpotiFLAC: Extension OAuth redirect missing state (extension id)")
            return false
        }
        streamQueue.async {
            var err: NSError?
            GobackendSetExtensionAuthCodeByID(state, code)
            _ = GobackendInvokeExtensionActionJSON(state, "completeSpotifyLogin", &err)
            if let err = err {
                NSLog(
                    "SpotiFLAC: Extension OAuth complete failed: \(err.localizedDescription)")
            }
        }
        return true
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        if handleExtensionOAuthRedirect(url: url) {
            return true
        }
        return super.application(app, open: url, options: options)
    }

    deinit {
        stopDownloadProgressStream()
        stopLibraryScanProgressStream()
    }

    private func startDownloadProgressStream(_ eventSink: @escaping FlutterEventSink) {
        stopDownloadProgressStream()
        downloadProgressEventSink = eventSink
        lastDownloadProgressPayload = nil
        lastDownloadProgressSeq = 0

        let timer = DispatchSource.makeTimerSource(queue: streamQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(800))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let payload = GobackendGetAllDownloadProgressDelta(self.lastDownloadProgressSeq) as String? ?? ""
            if payload.isEmpty || payload == self.lastDownloadProgressPayload {
                return
            }
            self.updateDownloadProgressSeq(payload)
            self.lastDownloadProgressPayload = payload
            DispatchQueue.main.async { [weak self] in
                self?.downloadProgressEventSink?(self?.parseJsonPayload(payload))
            }
        }
        downloadProgressTimer = timer
        timer.resume()
    }

    private func stopDownloadProgressStream() {
        downloadProgressTimer?.setEventHandler {}
        downloadProgressTimer?.cancel()
        downloadProgressTimer = nil
        downloadProgressEventSink = nil
        lastDownloadProgressPayload = nil
        lastDownloadProgressSeq = 0
    }

    private func startLibraryScanProgressStream(_ eventSink: @escaping FlutterEventSink) {
        stopLibraryScanProgressStream()
        libraryScanProgressEventSink = eventSink
        lastLibraryScanProgressPayload = nil

        let timer = DispatchSource.makeTimerSource(queue: streamQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(800))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let payload = GobackendGetLibraryScanProgressJSON() as String? ?? "{}"
            if payload == self.lastLibraryScanProgressPayload {
                return
            }
            self.lastLibraryScanProgressPayload = payload
            DispatchQueue.main.async { [weak self] in
                self?.libraryScanProgressEventSink?(self?.parseJsonPayload(payload))
            }
        }
        libraryScanProgressTimer = timer
        timer.resume()
    }

    private func stopLibraryScanProgressStream() {
        libraryScanProgressTimer?.setEventHandler {}
        libraryScanProgressTimer?.cancel()
        libraryScanProgressTimer = nil
        libraryScanProgressEventSink = nil
        lastLibraryScanProgressPayload = nil
    }

    private func parseJsonPayload(_ payload: String) -> Any {
        guard let data = payload.data(using: .utf8) else {
            return payload
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            return payload
        }
    }

    private func updateDownloadProgressSeq(_ payload: String) {
        guard let data = payload.data(using: .utf8) else { return }
        do {
            if let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) as? [String: Any],
               let seq = obj["seq"] as? NSNumber,
               seq.int64Value > lastDownloadProgressSeq {
                lastDownloadProgressSeq = seq.int64Value
            }
        } catch {
        }
    }

    private func bridgeJsonResult(_ payload: String) -> Any {
        if payload.utf8.count < LARGE_JSON_RESULT_FILE_THRESHOLD_BYTES {
            return payload
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("bridge_json_\(UUID().uuidString).json")
            try payload.write(to: url, atomically: true, encoding: .utf8)
            return [LARGE_JSON_RESULT_FILE_KEY: url.path]
        } catch {
            NSLog("SpotiFLAC: failed to spill large bridge JSON result to file: \(error.localizedDescription)")
            return payload
        }
    }
    
    private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let response = try self.invokeGoMethod(call: call)
                DispatchQueue.main.async {
                    result(response)
                }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                }
            }
        }
    }
    
    private func invokeGoMethod(call: FlutterMethodCall) throws -> Any? {
        var error: NSError?
        
        switch call.method {
        case "checkAvailability":
            let args = call.arguments as! [String: Any]
            let spotifyId = args["spotify_id"] as! String
            let isrc = args["isrc"] as! String
            let response = GobackendCheckAvailability(spotifyId, isrc, &error)
            if let error = error { throw error }
            return response
            
        case "downloadByStrategy":
            let requestJson = call.arguments as! String
            let response = GobackendDownloadByStrategy(requestJson, &error)
            if let error = error { throw error }
            return response

        case "getDownloadProgress":
            let response = GobackendGetDownloadProgress()
            return parseJsonPayload(response as String? ?? "{}")
            
        case "getAllDownloadProgress":
            let response = GobackendGetAllDownloadProgress()
            return parseJsonPayload(response as String? ?? "{}")
            
        case "initItemProgress":
            let args = call.arguments as! [String: Any]
            let itemId = args["item_id"] as! String
            GobackendInitItemProgress(itemId)
            return nil
            
        case "finishItemProgress":
            let args = call.arguments as! [String: Any]
            let itemId = args["item_id"] as! String
            GobackendFinishItemProgress(itemId)
            return nil
            
        case "clearItemProgress":
            let args = call.arguments as! [String: Any]
            let itemId = args["item_id"] as! String
            GobackendClearItemProgress(itemId)
            return nil

        case "cancelDownload":
            let args = call.arguments as! [String: Any]
            let itemId = args["item_id"] as! String
            GobackendCancelDownload(itemId)
            return nil
            
        case "setDownloadDirectory":
            let args = call.arguments as! [String: Any]
            let path = args["path"] as! String
            GobackendSetDownloadDirectory(path, &error)
            if let error = error { throw error }
            return nil

        case "setNetworkCompatibilityOptions", "setSongLinkNetworkOptions":
            let args = call.arguments as! [String: Any]
            let allowHTTP = args["allow_http"] as? Bool ?? false
            let insecureTLS = args["insecure_tls"] as? Bool ?? false
            GobackendSetNetworkCompatibilityOptions(allowHTTP, insecureTLS)
            return nil
            
        case "checkDuplicate":
            let args = call.arguments as! [String: Any]
            let outputDir = args["output_dir"] as! String
            let isrc = args["isrc"] as! String
            let response = GobackendCheckDuplicate(outputDir, isrc, &error)
            if let error = error { throw error }
            return response
            
        case "checkDuplicatesBatch":
            let args = call.arguments as! [String: Any]
            let outputDir = args["output_dir"] as! String
            let tracksJson = args["tracks"] as? String ?? "[]"
            let response = GobackendCheckDuplicatesBatch(outputDir, tracksJson, &error)
            if let error = error { throw error }
            return response
            
        case "preBuildDuplicateIndex":
            let args = call.arguments as! [String: Any]
            let outputDir = args["output_dir"] as! String
            GobackendPreBuildDuplicateIndex(outputDir, &error)
            if let error = error { throw error }
            return nil
            
        case "invalidateDuplicateIndex":
            let args = call.arguments as! [String: Any]
            let outputDir = args["output_dir"] as! String
            GobackendInvalidateDuplicateIndex(outputDir)
            return nil
            
        case "buildFilename":
            let args = call.arguments as! [String: Any]
            let template = args["template"] as! String
            let metadata = args["metadata"] as! String
            let response = GobackendBuildFilename(template, metadata, &error)
            if let error = error { throw error }
            return response
            
        case "sanitizeFilename":
            let args = call.arguments as! [String: Any]
            let filename = args["filename"] as! String
            let response = GobackendSanitizeFilename(filename)
            return response
            
        case "fetchLyrics":
            let args = call.arguments as! [String: Any]
            let spotifyId = args["spotify_id"] as! String
            let trackName = args["track_name"] as! String
            let artistName = args["artist_name"] as! String
            let durationMs = args["duration_ms"] as? Int64 ?? 0
            let response = GobackendFetchLyrics(spotifyId, trackName, artistName, durationMs, &error)
            if let error = error { throw error }
            return response
            
        case "getLyricsLRC":
            let args = call.arguments as! [String: Any]
            let spotifyId = args["spotify_id"] as! String
            let trackName = args["track_name"] as! String
            let artistName = args["artist_name"] as! String
            let filePath = args["file_path"] as? String ?? ""
            let durationMs = args["duration_ms"] as? Int64 ?? 0
            let response = GobackendGetLyricsLRC(spotifyId, trackName, artistName, filePath, durationMs, &error)
            if let error = error { throw error }
            return response

        case "getLyricsLRCWithSource":
            let args = call.arguments as! [String: Any]
            let spotifyId = args["spotify_id"] as! String
            let trackName = args["track_name"] as! String
            let artistName = args["artist_name"] as! String
            let filePath = args["file_path"] as? String ?? ""
            let durationMs = args["duration_ms"] as? Int64 ?? 0
            let response = GobackendGetLyricsLRCWithSource(spotifyId, trackName, artistName, filePath, durationMs, &error)
            if let error = error { throw error }
            return response
            
        case "embedLyricsToFile":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let lyrics = args["lyrics"] as! String
            let response = GobackendEmbedLyricsToFile(filePath, lyrics, &error)
            if let error = error { throw error }
            return response
            
        case "rewriteSplitArtistTags":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let artist = args["artist"] as! String
            let albumArtist = args["album_artist"] as! String
            let response = GobackendRewriteSplitArtistTagsExport(filePath, artist, albumArtist, &error)
            if let error = error { throw error }
            return response
            
        case "cleanupConnections":
            GobackendCleanupConnections()
            return nil

        case "downloadCoverToFile":
            let args = call.arguments as! [String: Any]
            let coverURL = args["cover_url"] as! String
            let outputPath = args["output_path"] as! String
            let maxQuality = args["max_quality"] as? Bool ?? true
            GobackendDownloadCoverToFile(coverURL, outputPath, maxQuality, &error)
            if let error = error { throw error }
            return "{\"success\":true}"

        case "extractCoverToFile":
            let args = call.arguments as! [String: Any]
            let audioPath = args["audio_path"] as! String
            let outputPath = args["output_path"] as! String
            GobackendExtractCoverToFile(audioPath, outputPath, &error)
            if let error = error { throw error }
            return "{\"success\":true}"

        case "fetchAndSaveLyrics":
            let args = call.arguments as! [String: Any]
            let trackName = args["track_name"] as! String
            let artistName = args["artist_name"] as! String
            let spotifyId = args["spotify_id"] as! String
            let durationMs = args["duration_ms"] as? Int64 ?? 0
            let outputPath = args["output_path"] as! String
            let audioFilePath = args["audio_file_path"] as? String ?? ""
            GobackendFetchAndSaveLyrics(trackName, artistName, spotifyId, durationMs, outputPath, audioFilePath, &error)
            if let error = error { throw error }
            return "{\"success\":true}"

        case "reEnrichFile":
            let args = call.arguments as! [String: Any]
            let requestJson = args["request_json"] as? String ?? "{}"
            let response = GobackendReEnrichFile(requestJson, &error)
            if let error = error { throw error }
            return response
            
        case "readFileMetadata":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let response = GobackendReadFileMetadata(filePath, &error)
            if let error = error { throw error }
            return response
            
        case "editFileMetadata":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let metadataJson = args["metadata_json"] as? String ?? "{}"
            let response = GobackendEditFileMetadata(filePath, metadataJson, &error)
            if let error = error { throw error }
            return response
            
        case "getDeezerRelatedArtists":
            let args = call.arguments as! [String: Any]
            let artistId = args["artist_id"] as! String
            let limit = args["limit"] as? Int ?? 12
            let response = GobackendGetDeezerRelatedArtists(artistId, Int(limit), &error)
            if let error = error { throw error }
            return response

        case "getProviderMetadata":
            let args = call.arguments as! [String: Any]
            let providerId = args["provider_id"] as! String
            let resourceType = args["resource_type"] as! String
            let resourceId = args["resource_id"] as! String
            let response = GobackendGetProviderMetadataJSON(providerId, resourceType, resourceId, &error)
            if let error = error { throw error }
            return response

        case "searchDeezerByISRC":
            let args = call.arguments as! [String: Any]
            let isrc = args["isrc"] as! String
            let itemId = args["item_id"] as? String ?? ""
            let response = GobackendSearchDeezerByISRCForItemID(isrc, itemId, &error)
            if let error = error { throw error }
            return response

        case "getDeezerExtendedMetadata":
            let args = call.arguments as! [String: Any]
            let trackId = args["track_id"] as! String
            let response = GobackendGetDeezerExtendedMetadata(trackId, &error)
            if let error = error { throw error }
            return response

        case "convertSpotifyToDeezer":
            let args = call.arguments as! [String: Any]
            let resourceType = args["resource_type"] as! String
            let spotifyId = args["spotify_id"] as! String
            let response = GobackendConvertSpotifyToDeezer(resourceType, spotifyId, &error)
            if let error = error { throw error }
            return response

        case "checkAvailabilityFromDeezerID":
            let args = call.arguments as! [String: Any]
            let deezerTrackId = args["deezer_track_id"] as! String
            let response = GobackendCheckAvailabilityFromDeezerID(deezerTrackId, &error)
            if let error = error { throw error }
            return response
            
        case "checkAvailabilityByPlatformID":
            let args = call.arguments as! [String: Any]
            let platform = args["platform"] as! String
            let entityType = args["entity_type"] as! String
            let entityId = args["entity_id"] as! String
            let response = GobackendCheckAvailabilityByPlatformID(platform, entityType, entityId, &error)
            if let error = error { throw error }
            return response
            
        case "getSpotifyIDFromDeezerTrack":
            let args = call.arguments as! [String: Any]
            let deezerTrackId = args["deezer_track_id"] as! String
            let response = GobackendGetSpotifyIDFromDeezerTrack(deezerTrackId, &error)
            if let error = error { throw error }
            return response
            
        case "getTidalURLFromDeezerTrack":
            let args = call.arguments as! [String: Any]
            let deezerTrackId = args["deezer_track_id"] as! String
            let response = GobackendGetTidalURLFromDeezerTrack(deezerTrackId, &error)
            if let error = error { throw error }
            return response
            
        case "preWarmTrackCache":
            let args = call.arguments as! [String: Any]
            let tracksJson = args["tracks"] as! String
            let _ = GobackendPreWarmTrackCacheJSON(tracksJson, &error)
            if let error = error { throw error }
            return nil
            
        case "getTrackCacheSize":
            let response = GobackendGetTrackCacheSize()
            return response
            
        case "clearTrackCache":
            GobackendClearTrackCache()
            return nil
            
        // Log methods
        case "getLogs":
            let response = GobackendGetLogs()
            return response
            
        case "getLogsSince":
            let args = call.arguments as! [String: Any]
            let index = args["index"] as? Int ?? 0
            let response = GobackendGetLogsSince(Int(index))
            return response
            
        case "clearLogs":
            GobackendClearLogs()
            return nil
            
        case "getLogCount":
            let response = GobackendGetLogCount()
            return response
            
        case "setLoggingEnabled":
            let args = call.arguments as! [String: Any]
            let enabled = args["enabled"] as? Bool ?? false
            GobackendSetLoggingEnabled(enabled)
            return nil
            
        // Extension System methods
        case "initExtensionSystem":
            let args = call.arguments as! [String: Any]
            let extensionsDir = args["extensions_dir"] as! String
            let dataDir = args["data_dir"] as! String
            GobackendInitExtensionSystem(extensionsDir, dataDir, &error)
            if let error = error { throw error }
            return nil
            
        case "loadExtensionsFromDir":
            let args = call.arguments as! [String: Any]
            let dirPath = args["dir_path"] as! String
            let response = GobackendLoadExtensionsFromDir(dirPath, &error)
            if let error = error { throw error }
            return response
            
        case "loadExtensionFromPath":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let response = GobackendLoadExtensionFromPath(filePath, &error)
            if let error = error { throw error }
            return response
            
        case "unloadExtension":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            GobackendUnloadExtensionByID(extensionId, &error)
            if let error = error { throw error }
            return nil
            
        case "getInstalledExtensions":
            let response = GobackendGetInstalledExtensions(&error)
            if let error = error { throw error }
            return response
            
        case "setExtensionEnabled":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let enabled = args["enabled"] as? Bool ?? false
            GobackendSetExtensionEnabledByID(extensionId, enabled, &error)
            if let error = error { throw error }
            return nil
            
        case "setProviderPriority":
            let args = call.arguments as! [String: Any]
            let priorityJson = args["priority"] as! String
            GobackendSetProviderPriorityJSON(priorityJson, &error)
            if let error = error { throw error }
            return nil
            
        case "getProviderPriority":
            let response = GobackendGetProviderPriorityJSON(&error)
            if let error = error { throw error }
            return response

        case "setDownloadFallbackExtensionIds":
            let args = call.arguments as! [String: Any]
            let extensionIdsJson = args["extension_ids"] as? String ?? ""
            GobackendSetExtensionFallbackProviderIDsJSON(extensionIdsJson, &error)
            if let error = error { throw error }
            return nil
            
        case "setMetadataProviderPriority":
            let args = call.arguments as! [String: Any]
            let priorityJson = args["priority"] as! String
            GobackendSetMetadataProviderPriorityJSON(priorityJson, &error)
            if let error = error { throw error }
            return nil
            
        case "getMetadataProviderPriority":
            let response = GobackendGetMetadataProviderPriorityJSON(&error)
            if let error = error { throw error }
            return response
            
        case "getExtensionSettings":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let response = GobackendGetExtensionSettingsJSON(extensionId, &error)
            if let error = error { throw error }
            return response

        case "checkExtensionHealth":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let response = GobackendCheckExtensionHealthJSON(extensionId, &error)
            if let error = error { throw error }
            return response
            
        case "setExtensionSettings":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let settingsJson = args["settings"] as! String
            GobackendSetExtensionSettingsJSON(extensionId, settingsJson, &error)
            if let error = error { throw error }
            return nil
            
        case "invokeExtensionAction":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let actionName = args["action"] as! String
            let response = GobackendInvokeExtensionActionJSON(extensionId, actionName, &error)
            if let error = error { throw error }
            return response
            
        case "searchTracksWithExtensions":
            let args = call.arguments as! [String: Any]
            let query = args["query"] as! String
            let limit = args["limit"] as? Int ?? 20
            let response = GobackendSearchTracksWithExtensionsJSON(query, Int(limit), &error)
            if let error = error { throw error }
            return response

        case "searchTracksWithMetadataProviders":
            let args = call.arguments as! [String: Any]
            let query = args["query"] as! String
            let limit = args["limit"] as? Int ?? 20
            let includeExtensions = args["include_extensions"] as? Bool ?? true
            let response = GobackendSearchTracksWithMetadataProvidersJSON(
                query,
                Int(limit),
                includeExtensions,
                &error
            )
            if let error = error { throw error }
            return response
            
        case "enrichTrackWithExtension":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let trackJson = args["track"] as? String ?? "{}"
            let response = GobackendEnrichTrackWithExtensionJSON(extensionId, trackJson, &error)
            if let error = error { throw error }
            return response

        case "downloadWithExtensions":
            let requestJson = call.arguments as! String
            let response = GobackendDownloadWithExtensionsJSON(requestJson, &error)
            if let error = error { throw error }
            return response
            
        case "removeExtension":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            GobackendRemoveExtensionByID(extensionId, &error)
            if let error = error { throw error }
            return nil
            
        case "upgradeExtension":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let response = GobackendUpgradeExtensionFromPath(filePath, &error)
            if let error = error { throw error }
            return response
            
        case "checkExtensionUpgrade":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let response = GobackendCheckExtensionUpgradeFromPath(filePath, &error)
            if let error = error { throw error }
            return response
            
        case "cleanupExtensions":
            GobackendCleanupExtensions()
            return nil
            
        // Extension Auth API
        case "getExtensionPendingAuth":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let response = GobackendGetExtensionPendingAuthJSON(extensionId, &error)
            if let error = error { throw error }
            return response
            
        case "setExtensionAuthCode":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let authCode = args["auth_code"] as! String
            GobackendSetExtensionAuthCodeByID(extensionId, authCode)
            return nil
            
        case "setExtensionTokens":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let accessToken = args["access_token"] as! String
            let refreshToken = args["refresh_token"] as? String ?? ""
            let expiresIn = args["expires_in"] as? Int ?? 0
            GobackendSetExtensionTokensByID(extensionId, accessToken, refreshToken, Int(expiresIn))
            return nil
            
        case "clearExtensionPendingAuth":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            GobackendClearExtensionPendingAuthByID(extensionId)
            return nil
            
        case "isExtensionAuthenticated":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let response = GobackendIsExtensionAuthenticatedByID(extensionId)
            return response
            
        case "getAllPendingAuthRequests":
            let response = GobackendGetAllPendingAuthRequestsJSON(&error)
            if let error = error { throw error }
            return response
            
        // Extension FFmpeg API
        case "getPendingFFmpegCommand":
            let args = call.arguments as! [String: Any]
            let commandId = args["command_id"] as! String
            let response = GobackendGetPendingFFmpegCommandJSON(commandId, &error)
            if let error = error { throw error }
            return response
            
        case "setFFmpegCommandResult":
            let args = call.arguments as! [String: Any]
            let commandId = args["command_id"] as! String
            let success = args["success"] as? Bool ?? false
            let output = args["output"] as? String ?? ""
            let errorMsg = args["error"] as? String ?? ""
            GobackendSetFFmpegCommandResult(commandId, success, output, errorMsg)
            return nil
            
        case "getAllPendingFFmpegCommands":
            let response = GobackendGetAllPendingFFmpegCommandsJSON(&error)
            if let error = error { throw error }
            return response
            
        // Extension Custom Search API
        case "customSearchWithExtension":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let query = args["query"] as! String
            let optionsJson = args["options"] as? String ?? ""
            let requestId = args["request_id"] as? String ?? ""
            let response = GobackendCustomSearchWithExtensionJSONWithRequestID(extensionId, query, optionsJson, requestId, &error)
            if let error = error { throw error }
            return response

        case "cancelExtensionRequest":
            let args = call.arguments as! [String: Any]
            let requestId = args["request_id"] as? String ?? ""
            GobackendCancelExtensionRequestJSON(requestId)
            return nil

        case "getSearchProviders":
            let response = GobackendGetSearchProvidersJSON(&error)
            if let error = error { throw error }
            return response
            
        // Extension URL Handler API
        case "handleURLWithExtension":
            let args = call.arguments as! [String: Any]
            let url = args["url"] as! String
            let response = GobackendHandleURLWithExtensionJSON(url, &error)
            if let error = error { throw error }
            return response
            
        case "findURLHandler":
            let args = call.arguments as! [String: Any]
            let url = args["url"] as! String
            let response = GobackendFindURLHandlerJSON(url)
            return response
            
        case "getURLHandlers":
            let response = GobackendGetURLHandlersJSON(&error)
            if let error = error { throw error }
            return response
            
        // Extension Post-Processing API
        case "runPostProcessing":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let metadataJson = args["metadata"] as? String ?? ""
            let response = GobackendRunPostProcessingJSON(filePath, metadataJson, &error)
            if let error = error { throw error }
            return response

        case "runPostProcessingV2":
            let args = call.arguments as! [String: Any]
            let inputJson = args["input"] as? String ?? ""
            let metadataJson = args["metadata"] as? String ?? ""
            let response = GobackendRunPostProcessingV2JSON(inputJson, metadataJson, &error)
            if let error = error { throw error }
            return response
            
        case "getPostProcessingProviders":
            let response = GobackendGetPostProcessingProvidersJSON(&error)
            if let error = error { throw error }
            return response
            
        // Extension Store
        case "initExtensionStore":
            let args = call.arguments as! [String: Any]
            let cacheDir = args["cache_dir"] as! String
            GobackendInitExtensionStoreJSON(cacheDir, &error)
            if let error = error { throw error }
            return nil
            
        case "setStoreRegistryUrl":
            let args = call.arguments as! [String: Any]
            let registryUrl = args["registry_url"] as? String ?? ""
            GobackendSetStoreRegistryURLJSON(registryUrl, &error)
            if let error = error { throw error }
            return nil
            
        case "getStoreRegistryUrl":
            let response = GobackendGetStoreRegistryURLJSON(&error)
            if let error = error { throw error }
            return response
            
        case "clearStoreRegistryUrl":
            GobackendClearStoreRegistryURLJSON(&error)
            if let error = error { throw error }
            return nil
            
        case "getStoreExtensions":
            let args = call.arguments as! [String: Any]
            let forceRefresh = args["force_refresh"] as? Bool ?? false
            let response = GobackendGetStoreExtensionsJSON(forceRefresh, &error)
            if let error = error { throw error }
            return response
            
        case "searchStoreExtensions":
            let args = call.arguments as! [String: Any]
            let query = args["query"] as? String ?? ""
            let category = args["category"] as? String ?? ""
            let response = GobackendSearchStoreExtensionsJSON(query, category, &error)
            if let error = error { throw error }
            return response
            
        case "getStoreCategories":
            let response = GobackendGetStoreCategoriesJSON(&error)
            if let error = error { throw error }
            return response
            
        case "downloadStoreExtension":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let destDir = args["dest_dir"] as! String
            let response = GobackendDownloadStoreExtensionJSON(extensionId, destDir, &error)
            if let error = error { throw error }
            return response
            
        case "clearStoreCache":
            GobackendClearStoreCacheJSON(&error)
            if let error = error { throw error }
            return nil
            
        // Extension Home Feed API
        case "getExtensionHomeFeed":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let requestId = args["request_id"] as? String ?? ""
            let response = GobackendGetExtensionHomeFeedJSONWithRequestID(extensionId, requestId, &error)
            if let error = error { throw error }
            return response
            
        case "getExtensionBrowseCategories":
            let args = call.arguments as! [String: Any]
            let extensionId = args["extension_id"] as! String
            let response = GobackendGetExtensionBrowseCategoriesJSON(extensionId, &error)
            if let error = error { throw error }
            return response
            
        // Local Library Scanning
        case "setLibraryCoverCacheDir":
            let args = call.arguments as! [String: Any]
            let cacheDir = args["cache_dir"] as! String
            GobackendSetLibraryCoverCacheDirJSON(cacheDir)
            return nil
            
        case "scanLibraryFolder":
            let args = call.arguments as! [String: Any]
            let folderPath = args["folder_path"] as! String
            let response = GobackendScanLibraryFolderJSON(folderPath, &error)
            if let error = error { throw error }
            return bridgeJsonResult(response as String? ?? "[]")
            
        case "scanLibraryFolderIncremental":
            let args = call.arguments as! [String: Any]
            let folderPath = args["folder_path"] as! String
            let existingFiles = args["existing_files"] as? String ?? "{}"
            let response = GobackendScanLibraryFolderIncrementalJSON(folderPath, existingFiles, &error)
            if let error = error { throw error }
            return bridgeJsonResult(response as String? ?? "{}")
            
        case "getLibraryScanProgress":
            let response = GobackendGetLibraryScanProgressJSON()
            return parseJsonPayload(response as String? ?? "{}")
            
        case "cancelLibraryScan":
            GobackendCancelLibraryScanJSON()
            return nil
            
        case "readAudioMetadata":
            let args = call.arguments as! [String: Any]
            let filePath = args["file_path"] as! String
            let response = GobackendReadAudioMetadataJSON(filePath, &error)
            if let error = error { throw error }
            return response
        
        // iOS Security-Scoped Bookmark for Local Library
        case "resolveIosBookmark":
            let args = call.arguments as! [String: Any]
            let bookmarkBase64 = args["bookmark"] as! String
            return try resolveIosBookmark(bookmarkBase64)
            
        case "startAccessingIosBookmark":
            let args = call.arguments as! [String: Any]
            let bookmarkBase64 = args["bookmark"] as! String
            return try startAccessingIosBookmark(bookmarkBase64)
            
        case "stopAccessingIosBookmark":
            stopAccessingIosBookmark()
            return nil
            
        case "createIosBookmarkFromPath":
            let args = call.arguments as! [String: Any]
            let path = args["path"] as! String
            return try createIosBookmarkFromPath(path)
            
        // Lyrics Provider Settings
        case "setLyricsProviders":
            let args = call.arguments as! [String: Any]
            let providersJson = args["providers_json"] as? String ?? "[]"
            GobackendSetLyricsProvidersJSON(providersJson, &error)
            if let error = error { throw error }
            return "{\"success\":true}"
            
        case "getLyricsProviders":
            let response = GobackendGetLyricsProvidersJSON(&error)
            if let error = error { throw error }
            return response
            
        case "getAvailableLyricsProviders":
            let response = GobackendGetAvailableLyricsProvidersJSON(&error)
            if let error = error { throw error }
            return response
            
        case "setLyricsFetchOptions":
            let args = call.arguments as! [String: Any]
            let optionsJson = args["options_json"] as? String ?? "{}"
            GobackendSetLyricsFetchOptionsJSON(optionsJson, &error)
            if let error = error { throw error }
            return "{\"success\":true}"
            
        case "getLyricsFetchOptions":
            let response = GobackendGetLyricsFetchOptionsJSON(&error)
            if let error = error { throw error }
            return response
            
        // CUE Sheet Parsing
        case "parseCueSheet":
            let args = call.arguments as! [String: Any]
            let cuePath = args["cue_path"] as! String
            let audioDir = args["audio_dir"] as? String ?? ""
            let response = GobackendParseCueSheet(cuePath, audioDir, &error)
            if let error = error { throw error }
            return response
            
        default:
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Method not implemented: \(call.method)"]
            )
        }
    }
    
    // MARK: - iOS Security-Scoped Bookmark Helpers
    
    /// Create a security-scoped bookmark from a filesystem path (e.g. from FilePicker).
    /// The path must currently be accessible (within the same picker session).
    /// Returns base64-encoded bookmark data.
    private func createIosBookmarkFromPath(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        do {
            #if os(macOS)
            let options: URL.BookmarkCreationOptions = .withSecurityScope
            #else
            let options: URL.BookmarkCreationOptions = []
            #endif
            let bookmarkData = try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return bookmarkData.base64EncodedString()
        } catch {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create bookmark for path \(path): \(error.localizedDescription)"]
            )
        }
    }
    
    /// Resolve a base64-encoded security-scoped bookmark and return the resolved path.
    /// Does NOT start accessing the resource.
    private func resolveIosBookmark(_ bookmarkBase64: String) throws -> String {
        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid base64 bookmark data"]
            )
        }
        
        var isStale = false
        let url: URL
        do {
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = .withSecurityScope
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve bookmark: \(error.localizedDescription)"]
            )
        }
        
        return url.path
    }
    
    /// Resolve a base64-encoded bookmark, start accessing the security-scoped resource,
    /// and return the resolved filesystem path. The resource stays accessed until
    /// `stopAccessingIosBookmark()` is called.
    private func startAccessingIosBookmark(_ bookmarkBase64: String) throws -> String {
        // Stop any previously accessed resource first
        stopAccessingIosBookmark()
        
        guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid base64 bookmark data"]
            )
        }
        
        var isStale = false
        let url: URL
        do {
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = .withSecurityScope
            #else
            let options: URL.BookmarkResolutionOptions = []
            #endif
            url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
        } catch {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to resolve bookmark: \(error.localizedDescription)"]
            )
        }
        
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "SpotiFLAC",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to start accessing security-scoped resource at \(url.path)"]
            )
        }
        
        activeSecurityScopedURL = url
        return url.path
    }
    
    /// Stop accessing the currently active security-scoped resource, if any.
    private func stopAccessingIosBookmark() {
        if let url = activeSecurityScopedURL {
            url.stopAccessingSecurityScopedResource()
            activeSecurityScopedURL = nil
        }
    }

func setupAudioEngine() {
        if playerNode.engine == nil { engine.attach(playerNode) }
        if eqNode.engine == nil { engine.attach(eqNode) }
        
        // Disconnect first to ensure we use new device formats
        engine.disconnectNodeInput(eqNode)
        engine.disconnectNodeInput(engine.mainMixerNode)
        
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, policy: .longFormAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            if engine.isRunning { engine.stop() }
            try engine.start()
        } catch {
            print("Audio Engine setup error: \(error)")
        }
    }
    
    func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] event in
            self?.resumeAudio()
            self?.methodChannel?.invokeMethod("playPause", arguments: nil)
            return .success
        }
        commandCenter.pauseCommand.addTarget { [weak self] event in
            self?.pauseAudio()
            self?.methodChannel?.invokeMethod("playPause", arguments: nil)
            return .success
        }
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            if self?.playerNode.isPlaying == true {
                self?.pauseAudio()
            } else {
                self?.resumeAudio()
            }
            self?.methodChannel?.invokeMethod("playPause", arguments: nil)
            return .success
        }
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let posMs = Int(event.positionTime * 1000)
                self?.seekAudio(toMs: posMs)
                // Notify Flutter of the lock-screen-initiated seek
                self?.methodChannel?.invokeMethod("seek", arguments: ["position": posMs])
                return .success
            }
            return .commandFailed
        }
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            self?.methodChannel?.invokeMethod("nextTrack", arguments: nil)
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            self?.methodChannel?.invokeMethod("previousTrack", arguments: nil)
            return .success
        }
    }
    
    func extractArtwork(from path: String) -> MPMediaItemArtwork? {
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        let metadata = asset.commonMetadata
        for item in metadata {
            if item.commonKey == .commonKeyArtwork,
               let data = item.dataValue,
               let image = UIImage(data: data) {
                return MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
            }
        }
        return nil
    }
    
    func updateNowPlaying(isPause: Bool = false) {
        guard let audioFile = audioFile else { return }
        var nowPlayingInfo = [String: Any]()
        
        nowPlayingInfo[MPMediaItemPropertyTitle]  = currentTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentArtist
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = currentAlbum
        
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        
        // FIX: Use seekOffsetMs + elapsed-since-last-play for correct scrubber position.
        // playerTime.sampleTime resets to 0 after each playerNode.stop(), so we add the
        // seekOffsetMs that was recorded at the time of the last seek/play operation.
        var elapsedSeconds: Double = Double(seekOffsetMs) / 1000.0
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let elapsedSincePlay = Double(playerTime.sampleTime) / playerTime.sampleRate
            elapsedSeconds += max(0, elapsedSincePlay)
        }
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsedSeconds
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPause ? 0.0 : 1.0
        
        if let coverArtData = self.currentCoverArt, let image = UIImage(data: coverArtData) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in return image }
        } else if let artwork = extractArtwork(from: currentPath) {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    func generateSpectrogram(from path: String) -> Data? {
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else { return nil }
        let format = file.processingFormat
        let frameCount = UInt32(file.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        try? file.read(into: buffer)
        
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let fftSize = 1024
        let fftHalf = fftSize / 2
        let chunkCount = Int(frameCount) / fftSize
        
        let width = min(chunkCount, 2048) // prevent huge images
        let height = 512
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return nil }
        
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        
        for x in 0..<width {
            let chunkIndex = (x * chunkCount) / width
            let offset = chunkIndex * fftSize
            
            var real = [Float](repeating: 0, count: fftHalf)
            var imag = [Float](repeating: 0, count: fftHalf)
            
            var chunk = [Float](repeating: 0, count: fftSize)
            for i in 0..<fftSize {
                if offset + i < Int(frameCount) {
                    chunk[i] = channelData[offset + i] * window[i]
                }
            }
            
            chunk.withUnsafeBufferPointer { ptr in
                ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftHalf) { complexPtr in
                    var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)
                    vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftHalf))
                    vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    var magnitudes = [Float](repeating: 0, count: fftHalf)
                    vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftHalf))
                    
                    for y in 0..<height {
                        let bin = (y * fftHalf) / height
                        let mag = magnitudes[fftHalf - 1 - bin]
                        let db = 10 * log10f(mag + 1e-10)
                        
                        let normalized = max(0, min(1, (db + 80) / 80))
                        // Heatmap color
                        let r = UInt8(normalized * 255)
                        let g = UInt8(sin(normalized * .pi) * 255)
                        let b = UInt8(max(0, 1 - normalized * 2) * 255)
                        
                        let pixelIndex = (y * bytesPerRow) + (x * bytesPerPixel)
                        pixelData[pixelIndex] = r
                        pixelData[pixelIndex + 1] = g
                        pixelData[pixelIndex + 2] = b
                        pixelData[pixelIndex + 3] = 255
                    }
                }
            }
        }
        vDSP_destroy_fftsetup(setup)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue),
              let cgImage = context.makeImage() else { return nil }
        
        return UIImage(cgImage: cgImage).pngData()
    }

    func updateAudioPathInfo() {
        guard let audioFile = audioFile else { return }
        let srcFormat = audioFile.processingFormat
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)

        let sourceStr = "\(Int(srcFormat.sampleRate / 1000))kHz · \(srcFormat.commonFormat == .pcmFormatFloat32 ? "32-bit Float" : "Int")"
        let dspStr    = "Bit-Perfect Pass-through" // App processing

        let outputName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "Unknown"
        let outputStr = "\(outputName) (\(Int(outputFormat.sampleRate / 1000))kHz)"

        DispatchQueue.main.async {
            self.methodChannel?.invokeMethod("audioPathUpdate", arguments: [
                "source": sourceStr,
                "dsp": dspStr,
                "output": outputStr
            ])
        }
    }

    func playAudio(path: String) {
        let url = URL(fileURLWithPath: path)
        do {
            if !engine.isRunning { try engine.start() }
            audioFile = try AVAudioFile(forReading: url)
            updateAudioPathInfo()
            
            // Reset seek offset when starting a new track
            seekOffsetMs = 0
            isSeeking = true
            playerNode.stop()
            isSeeking = false
            
            playerNode.scheduleFile(audioFile!, at: nil) { [weak self] in
                guard let self = self else { return }
                if !self.isSeeking {
                    DispatchQueue.main.async {
                        self.stateSink?(["finished": true])
                    }
                }
            }
            playerNode.play()
            
            let duration = Double(audioFile!.length) / audioFile!.processingFormat.sampleRate
            positionSink?(["duration": Int(duration * 1000)])
            stateSink?(["playing": true])
            
            updateNowPlaying()
            startTimer()
        } catch {
            print("Error playing file: \(error)")
        }
    }
    
    func pauseAudio() {
        if let nodeTime = playerNode.lastRenderTime,
           let playerTime = playerNode.playerTime(forNodeTime: nodeTime) {
            let elapsedMs = Int(Double(playerTime.sampleTime) / playerTime.sampleRate * 1000)
            seekOffsetMs += elapsedMs
        }
        playerNode.pause()
        stopTimer()
        stateSink?(["playing": false])
        updateNowPlaying(isPause: true)
    }
    
    func resumeAudio() {
        guard !playerNode.isPlaying else { return }
        do {
            if !engine.isRunning {
                try engine.start()
                reScheduleCurrent()
            } else if playerNode.lastRenderTime == nil {
                reScheduleCurrent()
            }
        } catch { print(error) }
        
        playerNode.play()
        startTimer()
        stateSink?(["playing": true])
        updateNowPlaying()
    }
    
    func reScheduleCurrent() {
        guard let audioFile = audioFile else { return }
        let sampleRate = audioFile.processingFormat.sampleRate
        let newFramePosition = AVAudioFramePosition(Double(seekOffsetMs) / 1000.0 * sampleRate)
        let framesToPlay = AVAudioFrameCount(max(0, audioFile.length - newFramePosition))
        
        isSeeking = true
        playerNode.stop()
        if framesToPlay > 0 {
            playerNode.scheduleSegment(audioFile, startingFrame: newFramePosition, frameCount: framesToPlay, at: nil) { [weak self] in
                guard let self = self else { return }
                if !self.isSeeking {
                    DispatchQueue.main.async {
                        self.stateSink?(["finished": true])
                    }
                }
            }
        }
        isSeeking = false
    }
    
    func seekAudio(toMs: Int) {
        guard let audioFile = audioFile else { return }
        do { if !engine.isRunning { try engine.start() } } catch { print(error) }
        let sampleRate = audioFile.processingFormat.sampleRate
        let newFramePosition = AVAudioFramePosition(Double(toMs) / 1000.0 * sampleRate)
        
        let wasPlaying = playerNode.isPlaying
        isSeeking = true
        playerNode.stop()
        
        // FIX: Record the new seek target as the offset.
        // All subsequent playerTime.sampleTime readings start from 0 and
        // will be added ON TOP of this offset.
        seekOffsetMs = toMs
        
        let framesToPlay = AVAudioFrameCount(audioFile.length - newFramePosition)
        if framesToPlay > 0 {
            playerNode.scheduleSegment(audioFile, startingFrame: newFramePosition, frameCount: framesToPlay, at: nil) { [weak self] in
                guard let self = self else { return }
                if !self.isSeeking {
                    DispatchQueue.main.async {
                        self.stateSink?(["finished": true])
                    }
                }
            }
        }
        isSeeking = false
        
        if wasPlaying {
            playerNode.play()
        }
        // Emit exact position to Flutter
        positionSink?(["position": toMs])
        // Update lock screen scrubber immediately after seek
        updateNowPlaying(isPause: !wasPlaying)
    }
    
    func updateEQ(bands: [[String: Any]]) {
        for (i, b) in bands.enumerated() {
            if i < eqNode.bands.count {
                if let fc   = b["fc"]   as? Double { eqNode.bands[i].frequency = Float(fc) }
                if let gain = b["gain"] as? Double { eqNode.bands[i].gain      = Float(gain) }
                if let q    = b["q"]    as? Double { eqNode.bands[i].bandwidth = Float(q) }
                
                if let type = b["type"] as? String {
                    switch type {
                    case "LSC": eqNode.bands[i].filterType = .lowShelf
                    case "HSC": eqNode.bands[i].filterType = .highShelf
                    case "LP":  eqNode.bands[i].filterType = .lowPass
                    case "HP":  eqNode.bands[i].filterType = .highPass
                    default:    eqNode.bands[i].filterType = .parametric
                    }
                }
            }
        }
    }
    
    func startTimer() {
        currentTimer?.invalidate()
        currentTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self,
                  let nodeTime = self.playerNode.lastRenderTime,
                  let playerTime = self.playerNode.playerTime(forNodeTime: nodeTime) else { return }
            // FIX: Report position = seekOffset + elapsed since last play
            let elapsedMs = Int(Double(playerTime.sampleTime) / playerTime.sampleRate * 1000)
            let posMs = self.seekOffsetMs + elapsedMs
            self.positionSink?(["position": posMs])
        }
    }
    
    func stopTimer() {
        currentTimer?.invalidate()
        currentTimer = nil
    }
}

private final class ClosureStreamHandler: NSObject, FlutterStreamHandler {
    typealias ListenHandler = (_ arguments: Any?, _ events: @escaping FlutterEventSink) -> FlutterError?
    typealias CancelHandler = (_ arguments: Any?) -> FlutterError?

    private let onListenHandler: ListenHandler
    private let onCancelHandler: CancelHandler

    init(
        onListen: @escaping ListenHandler,
        onCancel: @escaping CancelHandler = { _ in nil }
    ) {
        self.onListenHandler = onListen
        self.onCancelHandler = onCancel
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        onListenHandler(arguments, events)
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        onCancelHandler(arguments)
    }
}

class PositionStreamHandler: NSObject, FlutterStreamHandler {
    weak var appDelegate: AppDelegate?
    init(appDelegate: AppDelegate) { self.appDelegate = appDelegate }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.positionSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.positionSink = nil
        return nil
    }
}

class StateStreamHandler: NSObject, FlutterStreamHandler {
    weak var appDelegate: AppDelegate?
    init(appDelegate: AppDelegate) { self.appDelegate = appDelegate }
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        appDelegate?.stateSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        appDelegate?.stateSink = nil
        return nil
    }
}
