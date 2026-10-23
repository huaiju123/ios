import Foundation
import ZIPFoundation

enum ImportError: LocalizedError {
    case emptyContent
    case unzipFailed(String)
    case invalidEPUB(String)

    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "文件里没有可读的正文。"
        case .unzipFailed(let message):
            return "解压失败：\(message)"
        case .invalidEPUB(let message):
            return "这个 EPUB 解析不了：\(message)"
        }
    }
}

struct EPUBImportResult {
    var title: String
    var author: String
    var chapters: [Chapter]
    var hasCover: Bool
}

enum BookImporter {

    // MARK: - TXT

    static func loadTXT(from url: URL) throws -> (title: String, chapters: [Chapter]) {
        let data = try Data(contentsOf: url)
        let text = TextDecoder.decode(data)
        let normalized = TextUtil.normalize(text)
        guard !normalized.isEmpty else { throw ImportError.emptyContent }

        let chapters = ChapterParser.parse(normalized)
        let title = url.deletingPathExtension().lastPathComponent
        return (title, chapters)
    }

    // MARK: - EPUB

    static func importEPUB(from url: URL, id: UUID) throws -> EPUBImportResult {
        let root = AppPaths.bookDir(id)
        try AppPaths.fm.createDirectory(at: root, withIntermediateDirectories: true)

        do {
            try AppPaths.fm.unzipItem(at: url, to: root)
        } catch {
            AppPaths.remove(root)
            throw ImportError.unzipFailed(error.localizedDescription)
        }

        let containerURL = root.appendingPathComponent("META-INF/container.xml")
        guard AppPaths.fm.fileExists(atPath: containerURL.path) else {
            AppPaths.remove(root)
            throw ImportError.invalidEPUB("缺少 META-INF/container.xml，可能不是 EPUB 文件")
        }

        let opfRelative = try EPUBParser.opfPath(in: containerURL)
        let opfURL = root.appendingPathComponent(opfRelative)
        guard AppPaths.fm.fileExists(atPath: opfURL.path) else {
            throw ImportError.invalidEPUB("找不到 OPF：\(opfRelative)")
        }

        let package = try EPUBParser.package(at: opfURL)
        let opfDir = (opfRelative as NSString).deletingLastPathComponent

        var chapters: [Chapter] = []
        for idref in package.spine {
            guard let item = package.items[idref], item.mediaType.contains("html") else { continue }
            guard let fileURL = resolveFile(item.href, relativeTo: opfDir, in: root) else { continue }
            guard let data = try? Data(contentsOf: fileURL) else { continue }

            let html = TextDecoder.decode(data)
            let hrefPath = item.href.removingPercentEncoding ?? item.href
            let itemRelative = opfDir.isEmpty ? hrefPath : (opfDir as NSString).appendingPathComponent(hrefPath)
            let imageBase = (itemRelative as NSString).deletingLastPathComponent

            let blocks = HTMLBlocks.parse(html: html, baseDirectory: imageBase)
            guard !blocks.isEmpty else { continue }

            let fallback = "第 \(chapters.count + 1) 节"
            let title = HTMLBlocks.title(fromHTML: html) ?? fallback
            chapters.append(Chapter(id: chapters.count, title: title, blocks: blocks))
        }

        guard !chapters.isEmpty else {
            throw ImportError.invalidEPUB("书里没有可显示的内容")
        }

        var hasCover = false
        let coverHref = package.coverHref ?? package.coverID.flatMap { package.items[$0]?.href }
        if let coverHref = coverHref, let source = resolveFile(coverHref, relativeTo: opfDir, in: root) {
            let destination = root.appendingPathComponent("cover.jpg")
            AppPaths.remove(destination)
            if (try? AppPaths.fm.copyItem(at: source, to: destination)) != nil {
                hasCover = true
            }
        }

        let title = package.title.trimmed.isEmpty
            ? url.deletingPathExtension().lastPathComponent
            : package.title.trimmed

        return EPUBImportResult(
            title: title,
            author: package.author.trimmed,
            chapters: chapters,
            hasCover: hasCover
        )
    }

    private static func resolveFile(_ href: String, relativeTo directory: String, in root: URL) -> URL? {
        let candidates = [href, href.removingPercentEncoding ?? href]
        for candidate in candidates {
            let relative = directory.isEmpty ? candidate : (directory as NSString).appendingPathComponent(candidate)
            let url = root.appendingPathComponent(relative)
            if AppPaths.fm.fileExists(atPath: url.path) { return url }
        }
        return nil
    }
}

// MARK: - EPUB 元数据解析

struct EPUBPackage {
    var title = ""
    var author = ""
    var coverID: String?
    var coverHref: String?
    var items: [String: (href: String, mediaType: String)] = [:]
    var spine: [String] = []
}

enum EPUBParser {
    static func opfPath(in containerURL: URL) throws -> String {
        let data = try Data(contentsOf: containerURL)
        let delegate = ContainerXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse(), let rootfile = delegate.rootfile else {
            throw ImportError.invalidEPUB("container.xml 读不出来")
        }
        return rootfile
    }

    static func package(at url: URL) throws -> EPUBPackage {
        let data = try Data(contentsOf: url)
        let delegate = PackageXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw ImportError.invalidEPUB("OPF 读不出来")
        }
        return delegate.package
    }
}

private final class ContainerXMLDelegate: NSObject, XMLParserDelegate {
    var rootfile: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        if elementName == "rootfile", let path = attributeDict["full-path"] {
            rootfile = path
        }
    }
}

private final class PackageXMLDelegate: NSObject, XMLParserDelegate {
    var package = EPUBPackage()
    private var buffer = ""

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = localName(elementName)
        buffer = ""

        switch name {
        case "item":
            if let id = attributeDict["id"], let href = attributeDict["href"] {
                package.items[id] = (href: href, mediaType: attributeDict["media-type"] ?? "")
                if attributeDict["properties"]?.contains("cover-image") == true {
                    package.coverHref = href
                }
            }
        case "meta":
            if attributeDict["name"] == "cover", let content = attributeDict["content"] {
                package.coverID = content
            }
        case "itemref":
            if let idref = attributeDict["idref"] {
                package.spine.append(idref)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = localName(elementName)
        let text = buffer.trimmed

        switch name {
        case "title":
            if package.title.isEmpty, !text.isEmpty { package.title = text }
        case "creator":
            if package.author.isEmpty, !text.isEmpty { package.author = text }
        default:
            break
        }
        buffer = ""
    }

    private func localName(_ name: String) -> String {
        String(name.split(separator: ":").last ?? Substring(name))
    }
}
