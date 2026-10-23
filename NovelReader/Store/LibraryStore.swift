import Foundation
import Combine

/// 书架（小说：TXT / EPUB / 在线）
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [BookMeta] = []

    private let fm = FileManager.default
    private var chapterCache: [UUID: [Chapter]] = [:]

    private var libraryURL: URL { AppPaths.root.appendingPathComponent("library.json") }

    init() {
        load()
        let firstRun = !fm.fileExists(atPath: libraryURL.path)
        if firstRun {
            seed()
        }
    }

    // MARK: - 读

    func chapters(for id: UUID) -> [Chapter] {
        if let cached = chapterCache[id] { return cached }
        let url = chaptersURL(id)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Chapter].self, from: data) else {
            return []
        }
        chapterCache[id] = decoded
        return decoded
    }

    func coverFile(for book: BookMeta) -> URL? {
        let url = AppPaths.bookDir(book.id).appendingPathComponent("cover.jpg")
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    func book(id: UUID) -> BookMeta? {
        books.first { $0.id == id }
    }

    // MARK: - 写

    @discardableResult
    func add(
        title: String,
        author: String,
        format: BookFormat,
        chapters: [Chapter],
        intro: String = "",
        sourceID: UUID? = nil,
        sourceName: String = "",
        bookURL: String? = nil,
        coverURL: String? = nil,
        id: UUID = UUID()
    ) -> BookMeta? {
        var meta = BookMeta(title: title.trimmed.isEmpty ? "未命名" : title.trimmed, author: author)
        meta.id = id
        meta.format = format
        meta.intro = intro
        meta.sourceID = sourceID
        meta.sourceName = sourceName
        meta.bookURL = bookURL
        meta.coverURL = coverURL
        meta.charCount = chapters.reduce(0) { $0 + $1.plainText.count }

        do {
            try AppPaths.fm.createDirectory(at: AppPaths.bookDir(meta.id), withIntermediateDirectories: true)
            try writeChapters(chapters, to: meta.id)
        } catch {
            return nil
        }

        chapterCache[meta.id] = chapters
        books.insert(meta, at: 0)
        save()
        return meta
    }

    func saveChapters(_ chapters: [Chapter], for id: UUID) {
        try? writeChapters(chapters, to: id)
        chapterCache[id] = chapters
    }

    /// 只替换某一章的块内容（在线书按需下载后调用）
    func updateChapter(_ chapter: Chapter, for id: UUID) {
        var list = chapters(for: id)
        guard list.indices.contains(chapter.id) else { return }
        list[chapter.id] = chapter
        try? writeChapters(list, to: id)
        chapterCache[id] = list
    }

    func delete(_ id: UUID) {
        books.removeAll { $0.id == id }
        chapterCache[id] = nil
        AppPaths.remove(AppPaths.bookDir(id))
        save()
    }

    func updateProgress(id: UUID, chapterIndex: Int, offset: Int, overall: Double) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].chapterIndex = max(0, chapterIndex)
        books[index].offset = max(0, offset)
        books[index].progress = min(max(overall, 0), 1)
        books[index].lastReadAt = Date()
        save()
    }

    func markOpened(id: UUID) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        books[index].lastReadAt = Date()
        save()
    }

    // MARK: - 落盘

    private func chaptersURL(_ id: UUID) -> URL {
        AppPaths.bookDir(id).appendingPathComponent("chapters.json")
    }

    private func writeChapters(_ chapters: [Chapter], to id: UUID) throws {
        try AppPaths.fm.createDirectory(at: AppPaths.bookDir(id), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(chapters)
        try data.write(to: chaptersURL(id), options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: libraryURL) else { return }
        guard let decoded = try? JSONDecoder().decode([BookMeta].self, from: data) else {
            try? fm.removeItem(at: libraryURL)
            return
        }
        books = decoded.sorted { ($0.lastReadAt ?? $0.addedAt) > ($1.lastReadAt ?? $1.addedAt) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(books) else { return }
        try? data.write(to: libraryURL, options: .atomic)
    }

    private func seed() {
        let chapters = ChapterParser.parse(TextUtil.normalize(SampleBook.text))
        _ = add(title: "长夜拾光", author: "示例小说", format: .txt, chapters: chapters,
                intro: "一个守灯人的故事。这本书是内置示例，可以直接删掉。")
    }
}
