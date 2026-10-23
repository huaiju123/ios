import Foundation

/// 书源规则。所有 `xxx` 字段都是 CSS 选择器；以 `@` 开头表示取属性，例如 `@href`、`@src`。
struct SearchRule: Codable, Hashable {
    /// 搜索地址，支持 {{key}} {{page}}
    var url: String
    /// 结果列表容器
    var list: String
    var name: String
    var author: String? = nil
    var bookURL: String
    var cover: String? = nil
    var intro: String? = nil
}

struct DetailRule: Codable, Hashable {
    /// 目录列表容器
    var toc: String
    var chapterName: String
    var chapterURL: String
}

struct ContentRule: Codable, Hashable {
    /// 正文容器
    var text: String
    /// 「下一页」链接，可选
    var nextPage: String? = nil
    /// 需要删掉的节点（广告之类）
    var remove: [String]? = nil
}

struct BookSource: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var baseURL: String
    var charset: String? = nil
    var enabled: Bool = true
    var search: SearchRule
    var detail: DetailRule
    var content: ContentRule
}

extension BookSource {
    enum CodingKeys: String, CodingKey {
        case id, name, baseURL, charset, enabled, search, detail, content
    }

    /// 手写 JSON 时允许省略 id / charset / enabled
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        baseURL = try container.decode(String.self, forKey: .baseURL)
        charset = try container.decodeIfPresent(String.self, forKey: .charset)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        search = try container.decode(SearchRule.self, forKey: .search)
        detail = try container.decode(DetailRule.self, forKey: .detail)
        content = try container.decode(ContentRule.self, forKey: .content)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encodeIfPresent(charset, forKey: .charset)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(search, forKey: .search)
        try container.encode(detail, forKey: .detail)
        try container.encode(content, forKey: .content)
    }
}

/// 搜索结果
struct RemoteBook: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var author: String
    var coverURL: String?
    var intro: String
    var bookURL: String
    var sourceID: UUID
    var sourceName: String

    init(
        name: String,
        author: String = "",
        coverURL: String? = nil,
        intro: String = "",
        bookURL: String,
        sourceID: UUID,
        sourceName: String
    ) {
        self.name = name
        self.author = author
        self.coverURL = coverURL
        self.intro = intro
        self.bookURL = bookURL
        self.sourceID = sourceID
        self.sourceName = sourceName
    }
}

/// 目录里的一章
struct RemoteChapter {
    var title: String
    var url: String
}

/// 内置的书源模板，方便用户照着改
enum SourceTemplate {
    static let json = """
{
  "name": "示例书源",
  "baseURL": "https://www.example.com",
  "charset": "utf-8",
  "enabled": true,
  "search": {
    "url": "https://www.example.com/search?q={{key}}&page={{page}}",
    "list": "div.result-item",
    "name": "h3 a",
    "author": "span.author",
    "bookURL": "h3 a@href",
    "cover": "img@src",
    "intro": "p.intro"
  },
  "detail": {
    "toc": "#chapter-list dd",
    "chapterName": "a",
    "chapterURL": "a@href"
  },
  "content": {
    "text": "#content",
    "nextPage": "a.next@href",
    "remove": ["div.ad", "script"]
  }
}
"""
}
