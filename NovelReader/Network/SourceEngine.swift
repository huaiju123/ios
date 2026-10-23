import Foundation
import SwiftSoup

enum SourceError: LocalizedError {
    case parseFailed(String)
    case noResult

    var errorDescription: String? {
        switch self {
        case .parseFailed(let message):
            return message
        case .noResult:
            return "没有结果"
        }
    }
}

/// 按书源规则抓页面。规则全部是 CSS 选择器，`@href` 这种表示取属性。
final class SourceEngine {
    static let shared = SourceEngine()
    private init() {}

    // MARK: - 搜索

    func search(source: BookSource, keyword: String, page: Int = 1) async throws -> [RemoteBook] {
        let encodedKey = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let urlString = source.search.url
            .replacingOccurrences(of: "{{key}}", with: encodedKey)
            .replacingOccurrences(of: "{{page}}", with: String(page))

        let result = try await HTTPService.get(urlString, charset: source.charset)
        let document: Document
        do {
            document = try SwiftSoup.parse(result.text)
        } catch {
            throw SourceError.parseFailed("搜索页解析失败")
        }

        let items: Elements
        do {
            items = try document.select(source.search.list)
        } catch {
            throw SourceError.parseFailed("搜索列表选择器写错了：\(source.search.list)")
        }

        let base = result.finalURL.absoluteString
        var books: [RemoteBook] = []

        for item in items {
            let name = text(item, rule: source.search.name)
            guard !name.isEmpty else { continue }

            let href = attribute(item, rule: source.search.bookURL)
            guard let bookURL = URL.resolve(href, base: base) else { continue }

            let coverHref = source.search.cover.map { attribute(item, rule: $0) } ?? ""
            let author = source.search.author.map { text(item, rule: $0) } ?? ""
            let intro = source.search.intro.map { text(item, rule: $0) } ?? ""

            books.append(RemoteBook(
                name: name,
                author: author,
                coverURL: URL.resolve(coverHref, base: base)?.absoluteString,
                intro: intro,
                bookURL: bookURL.absoluteString,
                sourceID: source.id,
                sourceName: source.name
            ))
        }

        guard !books.isEmpty else { throw SourceError.noResult }
        return books
    }

    // MARK: - 目录

    func chapters(source: BookSource, bookURL: String) async throws -> [RemoteChapter] {
        let result = try await HTTPService.get(bookURL, charset: source.charset)
        let document: Document
        do {
            document = try SwiftSoup.parse(result.text)
        } catch {
            throw SourceError.parseFailed("书籍页解析失败")
        }

        let items: Elements
        do {
            items = try document.select(source.detail.toc)
        } catch {
            throw SourceError.parseFailed("目录选择器写错了：\(source.detail.toc)")
        }

        let base = result.finalURL.absoluteString
        var list: [RemoteChapter] = []

        for item in items {
            let title = text(item, rule: source.detail.chapterName)
            let href = attribute(item, rule: source.detail.chapterURL)
            guard !title.isEmpty, let url = URL.resolve(href, base: base) else { continue }
            list.append(RemoteChapter(title: title, url: url.absoluteString))
        }

        guard !list.isEmpty else {
            throw SourceError.parseFailed("目录是空的，书源规则可能过期了")
        }
        return list
    }

    // MARK: - 正文

    func chapterContent(source: BookSource, url: String) async throws -> String {
        var pieces: [String] = []
        var current = url
        var referer = url

        for _ in 0..<6 {
            let result = try await HTTPService.get(current, referer: referer, charset: source.charset)
            pieces.append(contentText(result.text, rule: source.content))

            guard let nextRule = source.content.nextPage, !nextRule.isEmpty else { break }
            let nextHref = linkText(result.text, rule: nextRule)
            guard !nextHref.isEmpty,
                  let next = URL.resolve(nextHref, base: result.finalURL.absoluteString),
                  next.absoluteString != current else { break }

            referer = current
            current = next.absoluteString
        }

        let joined = pieces.filter { !$0.trimmed.isEmpty }.joined(separator: "\n")
        guard !joined.trimmed.isEmpty else {
            throw SourceError.parseFailed("正文是空的，书源规则可能过期了")
        }
        return joined
    }

    // MARK: - 选择器求值

    private func text(_ element: Element, rule: String) -> String {
        let path = rule.trimmed
        guard !path.isEmpty else { return "" }
        if path.hasPrefix("@") {
            return attribute(element, rule: path)
        }
        guard let found = try? element.select(path).first() else { return "" }
        return ((try? found.text()) ?? "").trimmed
    }

    /// 支持 `a@href`（取属性）和单纯的 `a`（取文本）
    private func attribute(_ element: Element, rule: String) -> String {
        var selector = rule.trimmed
        var key = "href"

        if selector.hasPrefix("@") {
            key = String(selector.dropFirst())
            selector = ""
        } else if let at = selector.range(of: "@", options: .backwards) {
            key = String(selector[at.upperBound...])
            selector = String(selector[..<at.lowerBound])
        }

        let target: Element?
        if selector.trimmed.isEmpty {
            target = element
        } else {
            target = try? element.select(selector).first()
        }
        guard let target = target else { return "" }
        return ((try? target.attr(key)) ?? "").trimmed
    }

    private func contentText(_ html: String, rule: ContentRule) -> String {
        guard let document = try? SwiftSoup.parse(html) else { return "" }

        if let removeRules = rule.remove {
            for selector in removeRules {
                if let nodes = try? document.select(selector) {
                    for node in nodes {
                        try? node.remove()
                    }
                }
            }
        }

        guard let container = try? document.select(rule.text).first() else { return "" }
        let inner = (try? container.html()) ?? ""

        let withBreaks = inner
            .replacingOccurrences(of: "(?i)<br\\s*/?>", with: "\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</p>", with: "\n\n", options: .regularExpression)
            .replacingOccurrences(of: "(?i)</div>", with: "\n", options: .regularExpression)

        return TextUtil.normalizeParagraphs(withBreaks.strippedHTML)
    }

    private func linkText(_ html: String, rule: String) -> String {
        guard let document = try? SwiftSoup.parse(html) else { return "" }
        var selector = rule.trimmed
        var key = "href"

        if let at = selector.range(of: "@", options: .backwards) {
            key = String(selector[at.upperBound...])
            selector = String(selector[..<at.lowerBound])
        }

        guard !selector.trimmed.isEmpty, let element = try? document.select(selector).first() else {
            return ""
        }
        return ((try? element.attr(key)) ?? "").trimmed
    }
}
