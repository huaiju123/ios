import Foundation
import SwiftSoup

/// 把 XHTML 变成「文本块 + 图片块」的序列。
/// 只依赖 block 级元素的嵌套关系，不碰 CSS，够 EPUB 用。
enum HTMLBlocks {
    private static let blockTags: Set<String> = [
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6",
        "li", "blockquote", "section", "article", "tr", "td", "pre", "figure", "figcaption"
    ]

    /// - Parameter baseDirectory: 这个 XHTML 文件所在目录，相对书根目录
    static func parse(html: String, baseDirectory: String) -> [ContentBlock] {
        let cleaned = html
            .replacingOccurrences(of: "(?is)<script[^>]*>.*?</script>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<style[^>]*>.*?</style>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?is)<!--.*?-->", with: "", options: .regularExpression)

        guard let document = try? SwiftSoup.parse(cleaned), let body = document.body() else {
            return []
        }

        var blocks: [ContentBlock] = []
        walk(body, into: &blocks, baseDirectory: baseDirectory)
        return blocks
    }

    /// 取 <title> 或者第一个标题元素当章节名
    static func title(fromHTML html: String) -> String? {
        guard let document = try? SwiftSoup.parse(html) else { return nil }
        if let title = try? document.title(), !title.trimmed.isEmpty {
            return title.trimmed
        }
        for tag in ["h1", "h2", "h3"] {
            if let element = try? document.select(tag).first(), let text = try? element.text(), !text.trimmed.isEmpty {
                return text.trimmed
            }
        }
        return nil
    }

    private static func walk(_ element: Element, into blocks: inout [ContentBlock], baseDirectory: String) {
        for child in element.children() {
            let tag = child.tagName().lowercased()

            if tag == "img" {
                if let block = imageBlock(child, baseDirectory: baseDirectory) {
                    blocks.append(block)
                }
                continue
            }

            let grandchildren = child.children()
            let hasNestedBlock = grandchildren.contains { grandchild in
                let name = grandchild.tagName().lowercased()
                return blockTags.contains(name) || name == "img"
            }

            if hasNestedBlock {
                walk(child, into: &blocks, baseDirectory: baseDirectory)
                continue
            }

            let text = (try? child.text()) ?? ""
            if !text.trimmed.isEmpty {
                blocks.append(.text(text))
            }

            if let images = try? child.select("img") {
                for image in images {
                    if let block = imageBlock(image, baseDirectory: baseDirectory) {
                        blocks.append(block)
                    }
                }
            }
        }
    }

    private static func imageBlock(_ element: Element, baseDirectory: String) -> ContentBlock? {
        guard let raw = try? element.attr("src"), !raw.trimmed.isEmpty else { return nil }
        let src = raw.trimmed
        if src.isRemoteURL { return .image(src) }

        let decoded = src.removingPercentEncoding ?? src
        let combined = (baseDirectory as NSString).appendingPathComponent(decoded)
        let normalized = (combined as NSString).standardizingPath
        return .image(normalized)
    }
}
