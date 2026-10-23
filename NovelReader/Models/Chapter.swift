import Foundation

/// 章节内容由若干块组成：正文段落、插图。这样漫画式排版和带插图的 EPUB 能用同一套分页逻辑。
enum ContentBlock: Codable, Hashable {
    case text(String)
    /// 本地相对路径（相对书目录）或 http(s) 地址
    case image(String)

    var plainText: String? {
        if case .text(let value) = self { return value }
        return nil
    }

    var imagePath: String? {
        if case .image(let value) = self { return value }
        return nil
    }
}

struct Chapter: Identifiable, Codable, Hashable {
    var id: Int
    var title: String
    var blocks: [ContentBlock] = []
    /// 在线书的章节地址，本地书为 nil
    var remoteURL: String? = nil

    var plainText: String {
        blocks.compactMap { $0.plainText }.joined(separator: "\n")
    }

    var isEmpty: Bool { blocks.isEmpty }
}

/// 把纯文本切成章节。
/// 支持：第一章 / 第 12 回 / 第三卷 / Chapter 3 / 序章 / 楔子 / 引子 / 尾声 / 后记 / 番外
/// 找不到任何章节标题时，整本书当成一章「正文」。
enum ChapterParser {
    private static let titleRegex = try! NSRegularExpression(
        pattern: #"^[ \t　]*(?:第[ \t　]*[0-9０-９零〇一二三四五六七八九十百千万两]{1,10}[ \t　]*[章节回卷部篇集][^\n]{0,40}|Chapter[ \t]+\d+[^\n]{0,40}|序章[^\n]{0,40}|楔子[^\n]{0,30}|引子[^\n]{0,30}|尾声[^\n]{0,30}|后记[^\n]{0,30}|番外[^\n]{0,40})[ \t　]*$"#,
        options: [.anchorsMatchLines]
    )

    static func parse(_ text: String) -> [Chapter] {
        let ns = text as NSString
        let fullRange = NSRange(location: 0, length: ns.length)

        var heads: [(title: String, range: NSRange)] = []
        titleRegex.enumerateMatches(in: text, options: [], range: fullRange) { result, _, _ in
            guard let result = result else { return }
            let title = ns.substring(with: result.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            heads.append((title, result.range))
        }

        guard let first = heads.first else {
            return [Chapter(id: 0, title: "正文", blocks: [.text(text)])]
        }

        var chapters: [Chapter] = []

        if first.range.location > 0 {
            let preamble = ns.substring(to: first.range.location)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !preamble.isEmpty {
                chapters.append(Chapter(id: 0, title: "前言", blocks: [.text(preamble)]))
            }
        }

        for (index, head) in heads.enumerated() {
            let contentStart = head.range.location + head.range.length
            let contentEnd = index + 1 < heads.count ? heads[index + 1].range.location : ns.length
            let length = max(0, contentEnd - contentStart)
            let body = ns.substring(with: NSRange(location: contentStart, length: length))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            chapters.append(Chapter(id: chapters.count, title: head.title, blocks: [.text(body)]))
        }

        return chapters
    }
}
