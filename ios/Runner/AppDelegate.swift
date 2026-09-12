import Flutter
import UIKit
import Network
import Speech
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// iOS has no API to request Local Network permission on demand — the
  /// dialog appears once, triggered by the first local-network access.
  /// Browsing any Bonjour service deterministically triggers that evaluation,
  /// so we fire it as soon as the app is active instead of mid-flow (e.g.
  /// while the user is already tapping an FTP "Test" button). The probe finds
  /// nothing by design; it exists only to make iOS show the prompt early.
  private var lnProbeBrowser: NWBrowser?

  private func triggerLocalNetworkPrompt() {
    guard lnProbeBrowser == nil else { return }
    let params = NWParameters()
    params.includePeerToPeer = true
    let browser = NWBrowser(
      for: .bonjour(type: "_elnemr-probe._tcp.", domain: "local."),
      using: params)
    browser.stateUpdateHandler = { [weak self] state in
      switch state {
      case .ready, .failed, .cancelled:
        self?.lnProbeBrowser?.cancel()
        self?.lnProbeBrowser = nil
      default:
        break
      }
    }
    browser.start(queue: .main)
    lnProbeBrowser = browser
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    triggerLocalNetworkPrompt()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      IntentBridge.shared.setInitialURL(url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    IntentBridge.shared.handleOpenURL(url)
    return true
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ElNemrLanguage") else {
      return
    }
    let messenger = registrar.messenger()
    registrar.register(
      AvPlayerViewFactory(messenger: messenger),
      withId: "elnemr/exo_player"
    )
    FileBrowser.register(with: messenger)
    SpeechCoach.shared.configure(with: messenger)
    AudioExtractor.shared.configure(with: messenger)
    IntentBridge.shared.configure(with: messenger)
    WebDAVClient.register(with: messenger)
    FtpClient.register(with: messenger)
    JellyfinDiscovery.register(with: messenger)
    CacheCleaner.register(with: messenger)
    UpnpClient.register(with: messenger)
    MediaProbe.register(with: messenger)
    DownloadClient.register(with: messenger)
  }
}


// MARK: - Learning speech coach

final class SpeechCoach: NSObject {
  static let shared = SpeechCoach()
  private let channelName = "elnemr/speech_coach"
  private var pending: FlutterResult?
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private var tapInstalled = false

  func configure(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "listen":
        let args = call.arguments as? [String: Any]
        let locale = args?["locale"] as? String ?? Locale.current.identifier
        self.start(locale: locale, result: result)
      case "stop":
        self.finish(error: FlutterError(code: "cancelled", message: "Speech recognition cancelled", details: nil))
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func start(locale: String, result: @escaping FlutterResult) {
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "Speech recognition is already active", details: nil))
      return
    }
    pending = result
    SFSpeechRecognizer.requestAuthorization { [weak self] status in
      DispatchQueue.main.async {
        guard let self else { return }
        guard status == .authorized else {
          self.finish(error: FlutterError(code: "speech_denied", message: "Speech recognition permission was denied", details: nil))
          return
        }
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
          DispatchQueue.main.async {
            guard let self else { return }
            guard granted else {
              self.finish(error: FlutterError(code: "microphone_denied", message: "Microphone permission was denied", details: nil))
              return
            }
            self.startAuthorized(locale: locale)
          }
        }
      }
    }
  }

  private func startAuthorized(locale: String) {
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: locale)) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    guard let speechRecognizer, speechRecognizer.isAvailable else {
      finish(error: FlutterError(code: "unavailable", message: "Speech recognition is unavailable", details: nil))
      return
    }
    guard speechRecognizer.supportsOnDeviceRecognition else {
      finish(error: FlutterError(code: "offline_unavailable", message: "Offline speech recognition is not available for this language/device. No cloud fallback was used.", details: nil))
      return
    }
    recognizer = speechRecognizer

    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.record, mode: .measurement, options: [])
      try session.setActive(true, options: .notifyOthersOnDeactivation)
    } catch {
      finish(error: FlutterError(code: "audio_session", message: error.localizedDescription, details: nil))
      return
    }

    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = false
    req.requiresOnDeviceRecognition = true
    request = req
    let input = audioEngine.inputNode
    let format = input.outputFormat(forBus: 0)
    input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      req.append(buffer)
    }
    tapInstalled = true

    task = speechRecognizer.recognitionTask(with: req) { [weak self] result, error in
      guard let self else { return }
      if let result, result.isFinal {
        let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
          self.finish(error: FlutterError(code: "no_speech", message: "No speech was recognized", details: nil))
        } else {
          self.finish(text: text)
        }
      } else if let error {
        self.finish(error: FlutterError(code: "recognition_error", message: error.localizedDescription, details: nil))
      }
    }

    do {
      audioEngine.prepare()
      try audioEngine.start()
    } catch {
      finish(error: FlutterError(code: "audio_start", message: error.localizedDescription, details: nil))
    }
  }

  private func cleanup() {
    if audioEngine.isRunning { audioEngine.stop() }
    if tapInstalled {
      audioEngine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    request?.endAudio()
    task?.cancel()
    request = nil
    task = nil
    recognizer = nil
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func finish(text: String? = nil, error: FlutterError? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let pending = self.pending else { return }
      self.pending = nil
      self.cleanup()
      if let error { pending(error) }
      else { pending(text) }
    }
  }
}


// MARK: - Offline learning audio extraction

final class AudioExtractor: NSObject {
  static let shared = AudioExtractor()
  private let channelName = "elnemr/audio_extractor"

  func configure(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      guard call.method == "extractToWav" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any],
            let source = args["source"] as? String,
            !source.isEmpty else {
        result(FlutterError(code: "NO_SOURCE", message: "No media source provided", details: nil))
        return
      }
      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let path = try self.extract(source: source, preferredLanguage: args["preferredLanguage"] as? String)
          DispatchQueue.main.async { result(path) }
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(code: "EXTRACT_FAILED", message: error.localizedDescription, details: nil))
          }
        }
      }
    }
  }

  private func extract(source: String, preferredLanguage: String?) throws -> String {
    let url: URL
    if source.hasPrefix("file://") || source.hasPrefix("http://") || source.hasPrefix("https://") {
      guard let parsed = URL(string: source) else { throw NSError(domain: channelName, code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid media URL"]) }
      url = parsed
    } else {
      url = URL(fileURLWithPath: source)
    }

    let scoped = url.isFileURL ? url.startAccessingSecurityScopedResource() : false
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }

    let asset = AVURLAsset(url: url)
    let tracks = asset.tracks(withMediaType: .audio)
    guard !tracks.isEmpty else {
      throw NSError(domain: channelName, code: 2, userInfo: [NSLocalizedDescriptionKey: "No audio track found in this media"])
    }
    let preferred = preferredLanguage?.lowercased().split(separator: "-").first.map(String.init)
    let track = tracks.first(where: { candidate in
      guard let preferred else { return false }
      let code = candidate.languageCode?.lowercased().split(separator: "-").first.map(String.init)
      return code == preferred
    }) ?? tracks[0]

    let reader = try AVAssetReader(asset: asset)
    let outputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatLinearPCM,
      AVSampleRateKey: 16000,
      AVNumberOfChannelsKey: 1,
      AVLinearPCMBitDepthKey: 16,
      AVLinearPCMIsFloatKey: false,
      AVLinearPCMIsBigEndianKey: false,
      AVLinearPCMIsNonInterleaved: false,
    ]
    let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
    output.alwaysCopiesSampleData = false
    guard reader.canAdd(output) else {
      throw NSError(domain: channelName, code: 3, userInfo: [NSLocalizedDescriptionKey: "Audio track cannot be decoded to PCM"])
    }
    reader.add(output)

    let destination = FileManager.default.temporaryDirectory
      .appendingPathComponent("elnemr_audio_\(Int(Date().timeIntervalSince1970 * 1000)).wav")
    FileManager.default.createFile(atPath: destination.path, contents: nil)
    let handle = try FileHandle(forWritingTo: destination)
    defer { try? handle.close() }
    try handle.write(contentsOf: wavHeader(dataSize: 0))

    guard reader.startReading() else {
      throw reader.error ?? NSError(domain: channelName, code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not start audio decoding"])
    }

    var bytesWritten: UInt32 = 0
    while reader.status == .reading {
      guard let sample = output.copyNextSampleBuffer() else { break }
      guard let block = CMSampleBufferGetDataBuffer(sample) else { continue }
      let length = CMBlockBufferGetDataLength(block)
      if length == 0 { continue }
      var data = Data(count: length)
      let status = data.withUnsafeMutableBytes { raw -> OSStatus in
        guard let base = raw.baseAddress else { return -1 }
        return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: base)
      }
      guard status == kCMBlockBufferNoErr else { continue }
      try handle.write(contentsOf: data)
      bytesWritten &+= UInt32(length)
    }

    if reader.status == .failed {
      throw reader.error ?? NSError(domain: channelName, code: 5, userInfo: [NSLocalizedDescriptionKey: "Audio decoding failed"])
    }
    guard bytesWritten > 0 else {
      throw NSError(domain: channelName, code: 6, userInfo: [NSLocalizedDescriptionKey: "Audio decoder produced no PCM samples"])
    }

    try handle.seek(toOffset: 0)
    try handle.write(contentsOf: wavHeader(dataSize: bytesWritten))
    return destination.path
  }

  private func wavHeader(dataSize: UInt32) -> Data {
    var data = Data()
    func text(_ value: String) { data.append(value.data(using: .ascii)!) }
    func u16(_ value: UInt16) {
      var v = value.littleEndian
      withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }
    func u32(_ value: UInt32) {
      var v = value.littleEndian
      withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }
    text("RIFF"); u32(36 &+ dataSize); text("WAVE")
    text("fmt "); u32(16); u16(1); u16(1); u32(16000); u32(32000); u16(2); u16(16)
    text("data"); u32(dataSize)
    return data
  }
}
