import SwiftUI
import CoreText
import UIKit

/// 直接用 CoreText 画一页正文，避免 UILabel / SwiftUI Text 自己再排版一次导致和分页结果不一致。
struct PageTextView: UIViewRepresentable {
    let attributed: NSAttributedString

    func makeUIView(context: Context) -> CoreTextPageView {
        let view = CoreTextPageView()
        view.attributed = attributed
        return view
    }

    func updateUIView(_ uiView: CoreTextPageView, context: Context) {
        uiView.attributed = attributed
    }
}

final class CoreTextPageView: UIView {
    var attributed: NSAttributedString = NSAttributedString(string: "") {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
        // 让点击穿透到上层的翻页手势层
        isUserInteractionEnabled = false
    }

    override func draw(_ rect: CGRect) {
        guard attributed.length > 0, let context = UIGraphicsGetCurrentContext() else { return }

        context.textMatrix = .identity
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)

        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(origin: .zero, size: bounds.size), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)
    }
}
