import Foundation
import Combine

/// 漫画库
final class ComicStore: ObservableObject {
    @Published private(set) var comics: [ComicMeta] = []

    private let fm = FileManager.default
    private var jsonURL: URL { AppPaths.root.appendingPathComponent("comics.json") }

    init() {
        load()
    }

    // MARK: - 读

    func pages(of id: UUID) -> [String] {
        let url = AppPaths.comicDir(id).appendingPathComponent("pages.json")
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return list
    }

    func pageURL(_ id: UUID, index: Int) -> URL? {
        let list = pages(of: id)
        guard list.indices.contains(index) else { return nil }
        return AppPaths.comicDir(id).appendingPathComponent(list[index])
    }

    func coverFile(for comic: ComicMeta) -> URL? {
        let url = AppPaths.comicDir(comic.id).appendingPathComponent("cover.jpg")
        return fm.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - 写

    @discardableResult
    func add(title: String, files: [String], id: UUID = UUID()) -> ComicMeta? {
        guard !files.isEmpty else { return nil }
        do {
            try AppPaths.fm.createDirectory(at: AppPaths.comicDir(id), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(files)
            try data.write(to: AppPaths.comicDir(id).appendingPathComponent("pages.json"), options: .atomic)
        } catch {
            return nil
        }

        var meta = ComicMeta(title: title.trimmed.isEmpty ? "未命名" : title.trimmed)
        meta.id = id
        meta.pageCount = files.count
        comics.insert(meta, at: 0)
        save()
        return meta
    }

    func updatePage(_ page: Int, for id: UUID) {
        guard let index = comics.firstIndex(where: { $0.id == id }) else { return }
        comics[index].lastPage = min(max(page, 0), max(comics[index].pageCount - 1, 0))
        comics[index].lastReadAt = Date()
        save()
    }

    func delete(_ id: UUID) {
        comics.removeAll { $0.id == id }
        AppPaths.remove(AppPaths.comicDir(id))
        save()
    }

    // MARK: - 落盘

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        guard let decoded = try? JSONDecoder().decode([ComicMeta].self, from: data) else {
            try? fm.removeItem(at: jsonURL)
            return
        }
        comics = decoded.sorted { ($0.lastReadAt ?? $0.addedAt) > ($1.lastReadAt ?? $1.addedAt) }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(comics) else { return }
        try? data.write(to: jsonURL, options: .atomic)
    }
}
