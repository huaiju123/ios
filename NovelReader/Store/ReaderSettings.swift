import SwiftUI
import UIKit

/// 阅读配色
enum ReaderTheme: String, CaseIterable, Identifiable {
    case paper
    case cream
    case white
    case night
    case green

    var id: String { rawValue }

    var name: String {
        switch self {
        case .paper: return "纸白"
        case .cream: return "米黄"
        case .white: return "纯白"
        case .night: return "夜间"
        case .green: return "护眼"
        }
    }

    var background: Color {
        switch self {
        case .paper: return Color(red: 0.96, green: 0.95, blue: 0.92)
        case .cream: return Color(red: 0.95, green: 0.90, blue: 0.80)
        case .white: return Color(red: 0.995, green: 0.995, blue: 0.995)
        case .night: return Color(red: 0.09, green: 0.09, blue: 0.10)
        case .green: return Color(red: 0.86, green: 0.91, blue: 0.85)
        }
    }

    var text: Color {
        switch self {
        case .paper: return Color(red: 0.17, green: 0.16, blue: 0.14)
        case .cream: return Color(red: 0.28, green: 0.22, blue: 0.14)
        case .white: return Color(red: 0.12, green: 0.12, blue: 0.13)
        case .night: return Color(red: 0.70, green: 0.71, blue: 0.70)
        case .green: return Color(red: 0.15, green: 0.24, blue: 0.17)
        }
    }

    var isDark: Bool { self == .night }
}

/// 排版参数：分页和绘制共用同一份，保证量出来和画出来一致。
struct PageStyle {
    let fontSize: CGFloat
    let lineSpacing: CGFloat
    let textColor: UIColor
}

final class ReaderSettings: ObservableObject {
    @Published var fontSize: Double { didSet { touch() } }
    @Published var lineSpacing: Double { didSet { touch() } }
    @Published var theme: ReaderTheme { didSet { touch() } }
    @Published var animated: Bool { didSet { touch() } }
    @Published var speechRate: Double { didSet { touch() } }
    @Published var voiceIdentifier: String { didSet { touch() } }

    /// 排版版本号，阅读器监听它重新分页
    @Published private(set) var revision: Int = 0

    private enum Keys {
        static let fontSize = "reader.fontSize"
        static let lineSpacing = "reader.lineSpacing"
        static let theme = "reader.theme"
        static let animated = "reader.animated"
        static let speechRate = "reader.speechRate"
        static let voice = "reader.voice"
    }

    private let defaults = UserDefaults.standard

    init() {
        let store = UserDefaults.standard
        fontSize = (store.object(forKey: Keys.fontSize) as? Double) ?? 19
        lineSpacing = (store.object(forKey: Keys.lineSpacing) as? Double) ?? 8
        theme = ReaderTheme(rawValue: store.string(forKey: Keys.theme) ?? "") ?? .paper
        animated = (store.object(forKey: Keys.animated) as? Bool) ?? true
        speechRate = (store.object(forKey: Keys.speechRate) as? Double) ?? 0.5
        voiceIdentifier = store.string(forKey: Keys.voice) ?? ""
    }

    var pageStyle: PageStyle {
        PageStyle(
            fontSize: CGFloat(fontSize),
            lineSpacing: CGFloat(lineSpacing),
            textColor: UIColor(theme.text)
        )
    }

    private func touch() {
        revision += 1
        defaults.set(fontSize, forKey: Keys.fontSize)
        defaults.set(lineSpacing, forKey: Keys.lineSpacing)
        defaults.set(theme.rawValue, forKey: Keys.theme)
        defaults.set(animated, forKey: Keys.animated)
        defaults.set(speechRate, forKey: Keys.speechRate)
        defaults.set(voiceIdentifier, forKey: Keys.voice)
    }
}
