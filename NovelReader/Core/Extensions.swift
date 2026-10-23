import Foundation
import UIKit
import CoreFoundation

// MARK: - 文本编码

extension String.Encoding {
    /// GB18030（GBK / GB2312 的超集），中文 txt 和网页最常见
    static let gb18030: String.Encoding = {
        let cf = CFStringEncoding(0x0632)
        return String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(cf)))
    }()

    static let big5: String.Encoding = {
        let cf = CFStringEncoding(0x0A03)
        return String.Encoding(rawValue: UInt(CFStringConvertEncodingToNSStringEncoding(cf)))
    }()
}

enum TextDecoder {
    /// 依次尝试：服务器声明的 charset → UTF-8 → GB18030 → Big5 → UTF-16
    static func decode(_ data: Data, charset: String? = nil) -> String {
        if let charset = charset?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
           let enc = encoding(named: charset),
           let text = String(data: data, encoding: enc) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .gb18030) { return text }
        if let text = String(data: data, encoding: .big5) { return text }
        if let text = String(data: data, encoding: .utf16) { return text }
        return String(decoding: data, as: UTF8.self)
    }

    static func encoding(named name: String) -> String.Encoding? {
        if name.contains("utf-8") || name.contains("utf8") { return .utf8 }
        if name.contains("utf-16") || name.contains("utf16") { return .utf16 }
        if name.contains("gb") { return .gb18030 }
        if name.contains("big5") { return .big5 }
        return nil
    }

    /// 从 HTML 的 meta charset 里嗅探编码
    static func sniffCharset(in data: Data) -> String? {
        let head = data.prefix(2048)
        guard let text = String(data: head, encoding: .isoLatin1) else { return nil }
        if let charset = text.firstMatch(#"charset\s*=\s*["']?\s*([A-Za-z0-9_\-]+)"#) {
            return charset
        }
        return nil
    }
}

// MARK: - 字符串

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 把连续空白压成一个空格
    var collapsedWhitespace: String {
        let parts = split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\n" || $0 == "\r" || $0 == "\u{3000}" })
        return parts.joined(separator: " ")
    }

    var isRemoteURL: Bool {
        hasPrefix("http://") || hasPrefix("https://")
    }

    /// 第一个捕获组
    func firstMatch(_ pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return nil
        }
        let range = NSRange(location: 0, length: (self as NSString).length)
        guard let match = regex.firstMatch(in: self, options: [], range: range), match.numberOfRanges > 1 else {
            return nil
        }
        let group = match.range(at: 1)
        guard group.location != NSNotFound else { return nil }
        return (self as NSString).substring(with: group)
    }

    /// 所有匹配的所有捕获组
    func allMatches(_ pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }
        let ns = self as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.matches(in: self, options: [], range: range).map { match in
            (0..<match.numberOfRanges).map { index in
                let r = match.range(at: index)
                return r.location == NSNotFound ? "" : ns.substring(with: r)
            }
        }
    }

    /// 去掉所有 HTML 标签
    var strippedHTML: String {
        replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .trimmed
    }

    func substring(_ range: NSRange) -> String {
        guard let r = Range(range, in: self) else { return "" }
        return String(self[r])
    }
}

// MARK: - URL

extension URL {
    /// 相对地址补全，处理中文路径
    static func resolve(_ href: String, base: String?) -> URL? {
        let raw = href.trimmed
        guard !raw.isEmpty, !raw.hasPrefix("javascript:"), !raw.hasPrefix("#") else { return nil }

        if raw.isRemoteURL {
            return URL.lenient(raw)
        }
        guard let baseString = base, let baseURL = URL.lenient(baseString) else { return nil }
        if let url = URL(string: raw, relativeTo: baseURL) { return url.absoluteURL }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: encoded, relativeTo: baseURL) {
            return url.absoluteURL
        }
        return nil
    }

    /// 容错构造 URL：中文、空格、未编码的百分号都能处理
    static func lenient(_ string: String) -> URL? {
        let raw = string.trimmed
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw), url.scheme != nil { return url }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {
            return url
        }
        return nil
    }
}

// MARK: - 其他小工具

extension NSRange {
    func clamped(to length: Int) -> NSRange {
        let start = max(0, min(location, length))
        let end = max(start, min(location + self.length, length))
        return NSRange(location: start, length: end - start)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

enum TextUtil {
    /// 统一换行、去掉 BOM、压缩多余空行
    static func normalize(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 把一段带空格的网页正文整理成段落
    static func normalizeParagraphs(_ raw: String) -> String {
        let lines = normalize(raw).components(separatedBy: "\n")
        let cleaned = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return "" }
            return "\u{3000}\u{3000}" + trimmed
        }
        var result: [String] = []
        for line in cleaned {
            if line.isEmpty && result.last?.isEmpty == true { continue }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }
}
