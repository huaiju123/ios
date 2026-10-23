import Foundation

enum HTTPError: LocalizedError {
    case badURL(String)
    case status(Int)
    case empty

    var errorDescription: String? {
        switch self {
        case .badURL(let value):
            return "地址不合法：\(value)"
        case .status(let code):
            return "服务器返回 \(code)"
        case .empty:
            return "响应是空的"
        }
    }
}

struct HTTPResult {
    var text: String
    var finalURL: URL
}

enum HTTPService {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    static func get(_ urlString: String, referer: String? = nil, charset: String? = nil) async throws -> HTTPResult {
        guard let url = URL.lenient(urlString) else { throw HTTPError.badURL(urlString) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        if let referer = referer {
            request.setValue(referer, forHTTPHeaderField: "Referer")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...399).contains(http.statusCode) {
            throw HTTPError.status(http.statusCode)
        }

        let headerCharset = charset ?? charset(from: response)
        let text = TextDecoder.decode(data, charset: headerCharset ?? TextDecoder.sniffCharset(in: data))
        guard !text.isEmpty else { throw HTTPError.empty }

        return HTTPResult(text: text, finalURL: response.url ?? url)
    }

    private static func charset(from response: URLResponse) -> String? {
        guard let http = response as? HTTPURLResponse,
              let contentType = http.value(forHTTPHeaderField: "Content-Type") else { return nil }
        return contentType.firstMatch(#"charset\s*=\s*"?([A-Za-z0-9_\-]+)"#)
    }
}
