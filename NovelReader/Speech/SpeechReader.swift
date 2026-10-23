import Foundation
import AVFoundation
import MediaPlayer
import Combine

/// 听书：把章节切成句子逐句朗读，支持后台播放和锁屏控制。
final class SpeechReader: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    var onSentence: ((NSRange) -> Void)?
    var onChapterEnd: (() -> Void)?
    var onStateChange: ((Bool) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var ranges: [NSRange] = []
    private var text = ""
    private var cursor = 0
    private var rate: Float = 0.5
    private var voiceID = ""

    private(set) var isPlaying = false
    private(set) var isPaused = false
    private var nowPlayingTitle = ""
    private var nowPlayingArtist = ""

    override init() {
        super.init()
        synthesizer.delegate = self
        configureSession()
        registerRemoteCommands()
    }

    // MARK: - 控制

    func start(text: String, from offset: Int, rate: Float, voiceID: String, title: String, artist: String) {
        stop()

        self.text = text
        self.rate = min(max(rate, 0.3), 0.7)
        self.voiceID = voiceID
        self.ranges = SpeechReader.sentenceRanges(in: text)
        self.nowPlayingTitle = title
        self.nowPlayingArtist = artist
        guard !ranges.isEmpty else { return }

        cursor = ranges.firstIndex { offset < $0.location + $0.length } ?? 0
        activateSession()
        speakCurrent()
        setPlaying(true)
        updateNowPlaying()
    }

    func pause() {
        guard isPlaying else { return }
        synthesizer.pauseSpeaking(at: .word)
        isPlaying = false
        isPaused = true
        onStateChange?(false)
        updateNowPlaying()
    }

    func resume() {
        guard isPaused else { return }
        activateSession()
        synthesizer.continueSpeaking()
        isPlaying = true
        isPaused = false
        onStateChange?(true)
        updateNowPlaying()
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isPlaying = false
        isPaused = false
        ranges = []
        text = ""
        cursor = 0
        onStateChange?(false)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        deactivateSession()
    }

    var isActive: Bool { isPlaying || isPaused }

    // MARK: - 内部

    private func speakCurrent() {
        guard cursor < ranges.count else {
            finishChapter()
            return
        }

        let range = ranges[cursor]
        let sentence = (text as NSString).substring(with: range)
        guard !sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cursor += 1
            speakCurrent()
            return
        }

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.postUtteranceDelay = 0.04

        if !voiceID.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: voiceID) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        }

        onSentence?(range)
        synthesizer.speak(utterance)
    }

    private func finishChapter() {
        isPlaying = false
        isPaused = false
        synthesizer.stopSpeaking(at: .immediate)
        onStateChange?(false)
        onChapterEnd?()
    }

    private func setPlaying(_ playing: Bool) {
        isPlaying = playing
        if playing { isPaused = false }
        onStateChange?(playing)
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - 锁屏

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: nowPlayingTitle,
            MPMediaItemPropertyArtist: nowPlayingArtist,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let progress = progressInfo() {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = progress.elapsed
            info[MPMediaItemPropertyPlaybackDuration] = progress.duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func progressInfo() -> (elapsed: Double, duration: Double)? {
        guard !ranges.isEmpty, cursor < ranges.count else { return nil }
        let total = Double(max((text as NSString).length, 1))
        return (Double(ranges[cursor].location), total)
    }

    private func registerRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)

        center.playCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async { self?.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.isPlaying {
                    self.pause()
                } else {
                    self.resume()
                }
            }
            return .success
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard isActive else { return }
        cursor += 1
        if cursor < ranges.count {
            speakCurrent()
        } else {
            finishChapter()
        }
    }

    // MARK: - 断句

    static func sentenceRanges(in text: String) -> [NSRange] {
        let ns = text as NSString
        guard ns.length > 0 else { return [] }

        var ranges: [NSRange] = []
        var start = 0

        for index in 0..<ns.length {
            let character = ns.character(at: index)
            let isBreak = character == 10
                || character == 0x3002   // 。
                || character == 0xFF01   // ！
                || character == 0xFF1F   // ？
                || character == 0xFF1B   // ；
                || character == 33       // !
                || character == 63       // ?
                || character == 0x2026   // …

            if isBreak {
                ranges.append(NSRange(location: start, length: index - start + 1))
                start = index + 1
            }
        }

        if start < ns.length {
            ranges.append(NSRange(location: start, length: ns.length - start))
        }

        return ranges.filter { range in
            !ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
