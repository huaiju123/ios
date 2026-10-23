import Foundation
import CoreText
import UIKit

/// 一页：要么一段文本，要么一张图
struct ReaderPage {
    var attributed: NSAttributedString?
    var imageURL: URL?
    /// 这一页在本章正文里的字符起点，用来还原阅读位置
    var anchor: Int
}

/// 用 CoreText 做真实分页：量出来的范围和画出来的内容严格对应。
enum ReaderPaginator {

    static func layout(chapter: Chapter, style: PageStyle, size: CGSize, bookDir: URL) -> [ReaderPage] {
        var pages: [ReaderPage] = []
        var cursor = 0

        for block in chapter.blocks {
            switch block {
            case .text(let text):
                let attributed = body(text, style: style)
                let ranges = paginate(attributed, size: size)
                for range in ranges {
                    pages.append(ReaderPage(
                        attributed: attributed.attributedSubstring(from: range),
                        imageURL: nil,
                        anchor: cursor + range.location
                    ))
                }
                cursor += (text as NSString).length

            case .image(let path):
                if let url = imageURL(path, bookDir: bookDir) {
                    pages.append(ReaderPage(attributed: nil, imageURL: url, anchor: cursor))
                }
            }
        }

        if pages.isEmpty {
            pages.append(ReaderPage(attributed: NSAttributedString(string: ""), imageURL: nil, anchor: 0))
        }
        return pages
    }

    static func body(_ text: String, style: PageStyle) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.firstLineHeadIndent = style.fontSize * 2
        paragraph.headIndent = 0
        paragraph.tailIndent = 0
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.paragraphSpacing = style.fontSize * 0.4

        return NSAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: style.fontSize),
                .foregroundColor: style.textColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    static func paginate(_ text: NSAttributedString, size: CGSize) -> [NSRange] {
        let width = max(size.width, 40)
        let height = max(size.height, 40)

        guard text.length > 0 else {
            return [NSRange(location: 0, length: 0)]
        }

        let framesetter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: CGRect(x: 0, y: 0, width: width, height: height), transform: nil)

        var ranges: [NSRange] = []
        var location = 0
        while location < text.length {
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(location, 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)

            if visible.length <= 0 {
                ranges.append(NSRange(location: location, length: text.length - location))
                break
            }

            ranges.append(NSRange(location: location, length: visible.length))
            location = visible.location + visible.length
        }

        return ranges.isEmpty ? [NSRange(location: 0, length: text.length)] : ranges
    }

    private static func imageURL(_ path: String, bookDir: URL) -> URL? {
        if path.isRemoteURL {
            return URL.lenient(path)
        }
        let url = bookDir.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
