import Foundation
import Combine

/// 书源管理
final class SourceStore: ObservableObject {
    @Published private(set) var sources: [BookSource] = []

    private let fm = FileManager.default
    private var jsonURL: URL { AppPaths.root.appendingPathComponent("sources.json") }

    init() {
        load()
    }

    func source(id: UUID?) -> BookSource? {
        guard let id = id else { return nil }
        return sources.first { $0.id == id }
    }

    var enabledSources: [BookSource] {
        sources.filter { $0.enabled }
    }

    func add(_ source: BookSource) {
        sources.append(source)
        save()
    }

    func remove(_ id: UUID) {
        sources.removeAll { $0.id == id }
        save()
    }

    func toggle(_ id: UUID) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].enabled.toggle()
        save()
    }

    /// 支持单个对象或数组
    func importJSON(_ text: String) throws -> Int {
        let data = Data(text.utf8)
        if let list = try? JSONDecoder().decode([BookSource].self, from: data) {
            sources.append(contentsOf: list)
            save()
            return list.count
        }
        let single = try JSONDecoder().decode(BookSource.self, from: data)
        sources.append(single)
        save()
        return 1
    }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL) else { return }
        guard let decoded = try? JSONDecoder().decode([BookSource].self, from: data) else {
            try? fm.removeItem(at: jsonURL)
            return
        }
        sources = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: jsonURL, options: .atomic)
    }
}
