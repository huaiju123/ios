import SwiftUI
import UIKit
import Combine

/// 阅读器状态机：目录、分页、进度、朗读
final class ReaderViewModel: ObservableObject {
    let book: BookMeta

    private let library: LibraryStore
    private let sources: SourceStore
    private let settings: ReaderSettings

    @Published private(set) var chapters: [Chapter] = []
    @Published private(set) var pages: [ReaderPage] = []
    @Published private(set) var pageText: NSAttributedString = NSAttributedString(string: "")
    @Published private(set) var pageImageURL: URL?

    @Published var chapterIndex = 0
    @Published var pageIndex = 0
    @Published var chapterTitle = ""
    @Published var overallProgress: Double = 0
    @Published var isLoading = false
    @Published var isSpeaking = false
    @Published var errorMessage: String?
    @Published var direction = 1

    @Published var showBars = false
    @Published var showTOC = false
    @Published var showSettings = false
    @Published var showSpeech = false

    private(set) var speech: SpeechReader?
    private var highlight: NSRange?
    private var viewport: CGSize = .zero
    private var anchor = 0
    private var started = false

    init(book: BookMeta, library: LibraryStore, sources: SourceStore, settings: ReaderSettings) {
        self.book = book
        self.library = library
        self.sources = sources
        self.settings = settings

        let reader = SpeechReader()
        speech = reader

        reader.onSentence = { [weak self] range in
            DispatchQueue.main.async { self?.handleSentence(range) }
        }
        reader.onChapterEnd = { [weak self] in
            DispatchQueue.main.async { self?.advanceAfterSpeech() }
        }
        reader.onStateChange = { [weak self] playing in
            DispatchQueue.main.async { self?.isSpeaking = playing }
        }
    }

    // MARK: - 启动

    func start() {
        guard !started else { return }
        started = true

        if book.format == .online {
            let cached = library.chapters(for: book.id)
            if cached.isEmpty {
                loadRemoteCatalog()
                return
            }
            chapters = cached
        } else {
            chapters = library.chapters(for: book.id)
        }

        finishStart()
    }

    private func finishStart() {
        guard !chapters.isEmpty else {
            errorMessage = "这本书没有可显示的内容"
            return
        }
        chapterIndex = book.chapterIndex.clamped(to: 0...(chapters.count - 1))
        anchor = max(book.offset, 0)
        layoutIfPossible()
    }

    private func loadRemoteCatalog() {
        guard let source = sources.source(id: book.sourceID), let bookURL = book.bookURL else {
            errorMessage = "书源不存在，或者书源地址缺失"
            return
        }

        isLoading = true
        Task { @MainActor in
            do {
                let list = try await SourceEngine.shared.chapters(source: source, bookURL: bookURL)
                var result: [Chapter] = []
                for (index, item) in list.enumerated() {
                    result.append(Chapter(id: index, title: item.title, blocks: [], remoteURL: item.url))
                }
                chapters = result
                library.saveChapters(result, for: book.id)
                isLoading = false
                finishStart()
            } catch {
                isLoading = false
                errorMessage = "目录加载失败：\(error.localizedDescription)"
            }
        }
    }

    // MARK: - 分页

    func relayout(size: CGSize? = nil) {
        if let size = size {
            guard size.width > 1, size.height > 1 else { return }
            viewport = size
        }
        layoutIfPossible()
    }

    private func layoutIfPossible() {
        guard viewport.width > 1, viewport.height > 1, !chapters.isEmpty else { return }
        layout(anchor: anchor)
    }

    private func layout(anchor target: Int) {
        guard chapters.indices.contains(chapterIndex) else { return }

        pages = ReaderPaginator.layout(
            chapter: chapters[chapterIndex],
            style: settings.pageStyle,
            size: viewport,
            bookDir: AppPaths.bookDir(book.id)
        )

        let index = pages.firstIndex { page in
            let length = max(page.attributed?.length ?? 0, 1)
            return target < page.anchor + length
        } ?? (pages.count - 1)

        pageIndex = index.clamped(to: 0...max(pages.count - 1, 0))
        refresh()
        ensureChapterContent()
    }

    private func refresh() {
        guard pages.indices.contains(pageIndex) else { return }

        let page = pages[pageIndex]
        pageImageURL = page.imageURL
        pageText = highlighted(page)
        chapterTitle = chapters.indices.contains(chapterIndex) ? chapters[chapterIndex].title : ""
        anchor = page.anchor
        overallProgress = computeProgress()
    }

    private func highlighted(_ page: ReaderPage) -> NSAttributedString {
        guard let attributed = page.attributed else { return NSAttributedString(string: "") }
        guard let highlight = highlight, highlight.length > 0 else { return attributed }

        let pageRange = NSRange(location: page.anchor, length: attributed.length)
        let overlap = NSIntersectionRange(highlight, pageRange)
        guard overlap.length > 0 else { return attributed }

        let local = NSRange(location: overlap.location - page.anchor, length: overlap.length)
        guard local.location >= 0, local.location + local.length <= attributed.length else { return attributed }

        let mutable = NSMutableAttributedString(attributedString: attributed)
        mutable.addAttribute(
            .backgroundColor,
            value: UIColor.systemYellow.withAlphaComponent(0.30),
            range: local
        )
        return mutable
    }

    private func computeProgress() -> Double {
        guard !chapters.isEmpty else { return 0 }
        let base = Double(chapterIndex) / Double(chapters.count)
        let within = pages.isEmpty ? 0 : Double(pageIndex) / Double(pages.count)
        return min(1, max(0, base + within / Double(chapters.count)))
    }

    // MARK: - 在线章节按需下载

    private func ensureChapterContent() {
        guard chapters.indices.contains(chapterIndex) else { return }
        let chapter = chapters[chapterIndex]
        guard chapter.blocks.isEmpty, let remoteURL = chapter.remoteURL else { return }
        guard let source = sources.source(id: book.sourceID) else { return }

        let index = chapter.id
        let bookID = book.id

        isLoading = true
        Task { @MainActor in
            do {
                let text = try await SourceEngine.shared.chapterContent(source: source, url: remoteURL)
                guard index < chapters.count else { return }
                chapters[index].blocks = [.text(TextUtil.normalizeParagraphs(text))]
                library.updateChapter(chapters[index], for: bookID)
                if index == chapterIndex {
                    layout(anchor: anchor)
                }
            } catch {
                errorMessage = "章节加载失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - 翻页

    func nextPage() {
        if pageIndex + 1 < pages.count {
            pageIndex += 1
            direction = 1
            refresh()
            save()
        } else if chapterIndex + 1 < chapters.count {
            goToChapter(chapterIndex + 1)
        }
    }

    func previousPage() {
        if pageIndex > 0 {
            pageIndex -= 1
            direction = -1
            refresh()
            save()
        } else if chapterIndex > 0 {
            goToChapter(chapterIndex - 1, lastPage: true)
        }
    }

    func goToChapter(_ index: Int, lastPage: Bool = false) {
        guard chapters.indices.contains(index) else { return }
        direction = index >= chapterIndex ? 1 : -1
        chapterIndex = index
        pageIndex = 0
        anchor = lastPage ? Int.max : 0
        layout(anchor: anchor)
        save()
    }

    func seek(to fraction: Double) {
        guard !chapters.isEmpty else { return }
        let value = min(max(fraction, 0), 1)
        let index = Int(Double(chapters.count) * value)
        goToChapter(index.clamped(to: 0...(chapters.count - 1)))
    }

    func toggleBars() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showBars.toggle()
        }
    }

    func save() {
        let offset = pages.indices.contains(pageIndex) ? pages[pageIndex].anchor : 0
        library.updateProgress(
            id: book.id,
            chapterIndex: chapterIndex,
            offset: offset,
            overall: overallProgress
        )
    }

    // MARK: - 听书

    func toggleSpeech() {
        guard let speech = speech else { return }
        if speech.isPlaying {
            speech.pause()
        } else if speech.isPaused {
            speech.resume()
        } else {
            startSpeech()
        }
    }

    func startSpeech() {
        guard let speech = speech, chapters.indices.contains(chapterIndex) else { return }
        let text = chapters[chapterIndex].plainText
        guard !text.trimmed.isEmpty else {
            errorMessage = "这一章的内容还没加载出来"
            return
        }

        let offset = pages.indices.contains(pageIndex) ? pages[pageIndex].anchor : 0
        speech.start(
            text: text,
            from: offset,
            rate: Float(settings.speechRate),
            voiceID: settings.voiceIdentifier,
            title: chapters[chapterIndex].title,
            artist: book.title
        )
    }

    func stopSpeech() {
        speech?.stop()
        highlight = nil
        isSpeaking = false
        if !pages.isEmpty { refresh() }
    }

    private func handleSentence(_ range: NSRange) {
        highlight = range
        guard let index = pages.firstIndex(where: { page in
            let length = max(page.attributed?.length ?? 0, 1)
            return range.location >= page.anchor && range.location < page.anchor + length
        }) else { return }

        pageIndex = index
        refresh()
    }

    private func advanceAfterSpeech() {
        guard chapterIndex + 1 < chapters.count else {
            stopSpeech()
            return
        }
        goToChapter(chapterIndex + 1)

        Task { @MainActor in
            for _ in 0..<4 {
                if chapters.indices.contains(chapterIndex), !chapters[chapterIndex].blocks.isEmpty {
                    startSpeech()
                    return
                }
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            startSpeech()
        }
    }
}
