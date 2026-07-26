#if canImport(Speech)
import Foundation
import AVFoundation
import Speech

/// Live microphone dictation for the assistant's input bar.
///
/// Wraps `SFSpeechRecognizer` + `AVAudioEngine`, transcribing in French with
/// partial results so the text field fills in as the user speaks. Everything is
/// driven on the main actor; the audio tap appends buffers to the request from
/// the audio thread, which is safe because the request object is thread-safe.
@MainActor
final class SpeechRecognizer: ObservableObject {

    /// The best transcription so far (updates live while recording).
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording = false
    /// A short, user-facing status when something needs attention (permissions…).
    @Published var statusMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "fr_FR"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Whether dictation can be offered at all on this device.
    var isSupported: Bool { recognizer != nil }

    func toggle() {
        isRecording ? stop() : start()
    }

    func start() {
        guard !isRecording else { return }
        statusMessage = nil
        transcript = ""
        Task {
            guard await requestPermissions() else {
                statusMessage = "Autorisez le micro et la reconnaissance vocale dans Réglages."
                return
            }
            do {
                try beginRecording()
            } catch {
                statusMessage = "Micro indisponible pour le moment."
                stop()
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Clears the transcript once the caller has consumed it.
    func reset() { transcript = "" }

    // MARK: - Private

    private func beginRecording() throws {
        task?.cancel()
        task = nil

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stop() }
                }
                if error != nil { self.stop() }
            }
        }
    }

    private func requestPermissions() async -> Bool {
        let speechOK = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechOK else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}
#endif
