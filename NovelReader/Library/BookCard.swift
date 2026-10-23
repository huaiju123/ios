import SwiftUI

/// 书架上的单本书：有封面图就用封面，没有就用渐变
struct BookCard: View {
    let book: BookMeta
    var coverURL: URL? = nil

    private static let palettes: [(Color, Color)] = [
        (Color(red: 0.36, green: 0.47, blue: 0.62), Color(red: 0.14, green: 0.21, blue: 0.32)),
        (Color(red: 0.72, green: 0.45, blue: 0.36), Color(red: 0.40, green: 0.20, blue: 0.16)),
        (Color(red: 0.40, green: 0.58, blue: 0.48), Color(red: 0.15, green: 0.28, blue: 0.22)),
        (Color(red: 0.56, green: 0.44, blue: 0.62), Color(red: 0.26, green: 0.17, blue: 0.34)),
        (Color(red: 0.64, green: 0.56, blue: 0.40), Color(red: 0.29, green: 0.24, blue: 0.15)),
        (Color(red: 0.38, green: 0.40, blue: 0.42), Color(red: 0.13, green: 0.14, blue: 0.16))
    ]

    private var palette: (Color, Color) {
        let index = (book.coverSeed & 0x7FFF_FFFF) % Self.palettes.count
        return Self.palettes[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            cover
            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text(book.progressText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var cover: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.0, palette.1],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let coverURL = coverURL,
               let image = ImageTools.cachedImage(path: coverURL, maxPixel: 400) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.14))
                    .frame(width: 5)
                    .padding(.leading, 7)
                    .blur(radius: 1.2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    Text(book.authorText)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

                if book.format != .txt {
                    Text(book.format.label)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.35), in: Capsule())
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                }
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 3)
    }
}
