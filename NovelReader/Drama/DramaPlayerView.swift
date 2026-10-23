import SwiftUI
import AVFoundation
import AVKit

struct PlayableEpisode {
    let number: Int
    let title: String
    let url: URL
}

final class DramaPlayerModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var index = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var speed: Double = 1.0
    @Published private(set) var failure: String?

    private(set) var queue: [PlayableEpisode] = []
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    var currentEpisodeNumber: Int {
        queue.indices.contains(index) ? queue[index].number : index + 1
    }

    init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)

        let interval = CMTime(seconds: 0.35, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let seconds = time.seconds
            if seconds.isFinite {
                self.position = max(0, seconds)
            }
            self.isPlaying = self.player.timeControlStatus == .playing
            if let item = self.player.currentItem {
                let total = item.duration.seconds
                if total.isFinite, total > 0 {
                    self.duration = total
                }
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.advance()
        }
    }

    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
        if let observer = endObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func configure(queue: [PlayableEpisode], startAt: Int) {
        self.queue = queue
        guard !queue.isEmpty else {
            failure = "这一部里没有可播放的文件"
            return
        }
        play(index: startAt.clamped(to: 0...(queue.count - 1)))
    }

    func play(index: Int) {
        guard queue.indices.contains(index) else { return }
        self.index = index
        let item = AVPlayerItem(url: queue[index].url)
        player.replaceCurrentItem(with: item)
        player.play()
        player.rate = Float(speed)
    }

    func toggle() {
        if player.timeControlStatus == .playing {
            player.pause()
        } else {
            player.play()
            player.rate = Float(speed)
        }
    }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration > 0 ? duration : seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        position = target
    }

    func skip(_ delta: Double) {
        seek(to: position + delta)
    }

    func advance() {
        if index + 1 < queue.count {
            play(index: index + 1)
        } else {
            player.pause()
        }
    }

    func setSpeed(_ value: Double) {
        speed = value
        if player.timeControlStatus == .playing {
            player.rate = Float(value)
        }
    }

    func stop() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

struct DramaPlayerView: View {
    let drama: DramaMeta

    @EnvironmentObject private var store: DramaStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = DramaPlayerModel()

    @State private var showControls = true
    @State private var showEpisodes = false
    @State private var scrubbing: Double?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerView(player: model.player)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.18)) { showControls.toggle() }
                }

            if let failure = model.failure {
                Text(failure)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }

            if showControls {
                controls
            }
        }
        .onAppear { start() }
        .onDisappear {
            store.updateEpisode(model.index, for: drama.id)
            model.stop()
        }
        .sheet(isPresented: $showEpisodes) {
            episodeSheet
        }
    }

    // MARK: - 控件

    private var controls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(drama.title)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Text("第 \(model.currentEpisodeNumber) 集 / \(drama.episodes.count)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                }

                Spacer()

                Button {
                    showEpisodes = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.top, 10)

            Spacer()

            HStack(spacing: 40) {
                Button {
                    model.skip(-15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.system(size: 26))
                }
                Button {
                    model.toggle()
                } label: {
                    Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 42))
                }
                Button {
                    model.skip(15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.system(size: 26))
                }
            }
            .foregroundStyle(.white)

            Spacer()

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Text(timeText(scrubbing ?? model.position))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))

                    Slider(
                        value: Binding(
                            get: { scrubbing ?? model.position },
                            set: { scrubbing = $0 }
                        ),
                        in: 0...max(model.duration, 1),
                        onEditingChanged: { editing in
                            guard !editing, let value = scrubbing else { return }
                            scrubbing = nil
                            model.seek(to: value)
                        }
                    )
                    .tint(.white)

                    Text(timeText(model.duration))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.85))
                }

                HStack {
                    Menu {
                        ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                            Button(String(format: "%.2fx", rate)) {
                                model.setSpeed(rate)
                            }
                        }
                    } label: {
                        Text(String(format: "%.2fx", model.speed))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Button {
                        model.advance()
                    } label: {
                        Text("下一集")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .background(
            LinearGradient(
                colors: [.black.opacity(0.6), .clear, .clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .transition(.opacity)
    }

    private var episodeSheet: some View {
        NavigationStack {
            List(drama.episodes.indices, id: \.self) { offset in
                Button {
                    if let target = model.queue.firstIndex(where: { $0.number == offset + 1 }) {
                        model.play(index: target)
                    }
                    showEpisodes = false
                } label: {
                    HStack {
                        Text("\(offset + 1). \(drama.episodes[offset].title)")
                            .lineLimit(1)
                        Spacer()
                        if model.currentEpisodeNumber == offset + 1 {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.currentEpisodeNumber == offset + 1 ? Color.accentColor : Color.primary)
            }
            .navigationTitle("剧集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { showEpisodes = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func start() {
        var list: [PlayableEpisode] = []
        for (offset, episode) in drama.episodes.enumerated() {
            if let url = store.url(for: episode, in: drama) {
                list.append(PlayableEpisode(number: offset + 1, title: episode.title, url: url))
            }
        }
        model.configure(queue: list, startAt: drama.lastEpisode)
    }

    private func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.player = player
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
