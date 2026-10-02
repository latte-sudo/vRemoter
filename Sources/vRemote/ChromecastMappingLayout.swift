import Foundation

/// Independent layout for our front-and-side photo. Coordinates refer to the
/// entire 1024 × 1536 image, not the reference application's different asset.
enum ChromecastMappingLayout {
    struct Placement {
        let id: String
        let right: Bool
        let row: Int
        let x: CGFloat
        let y: CGFloat
    }

    static let height: CGFloat = 624
    static let cardHeight: CGFloat = 72
    static let rowStride: CGFloat = 78
    static let placements: [Placement] = [
        .init(id: "03", right: false, row: 0, x: 0.37, y: 0.085),
        .init(id: "05", right: false, row: 1, x: 0.205, y: 0.17),
        .init(id: "04", right: false, row: 2, x: 0.37, y: 0.265),
        .init(id: "0B", right: false, row: 3, x: 0.255, y: 0.36),
        .init(id: "0A", right: false, row: 4, x: 0.255, y: 0.48),
        .init(id: "0E", right: false, row: 5, x: 0.255, y: 0.60),
        .init(id: "01", right: false, row: 6, x: 0.255, y: 0.71),
        .init(id: "07", right: true, row: 0, x: 0.37, y: 0.17),
        .init(id: "06", right: true, row: 1, x: 0.535, y: 0.17),
        .init(id: "0C", right: true, row: 2, x: 0.84, y: 0.18),
        .init(id: "0D", right: true, row: 3, x: 0.84, y: 0.30),
        .init(id: "voice", right: true, row: 4, x: 0.475, y: 0.36),
        .init(id: "08", right: true, row: 5, x: 0.475, y: 0.48),
        .init(id: "0F", right: true, row: 6, x: 0.475, y: 0.60),
        .init(id: "11", right: true, row: 7, x: 0.475, y: 0.71)
    ]

    struct Metrics {
        let width: CGFloat
        var cardWidth: CGFloat { min(300, max(210, (width - 324) / 2)) }
        var photoWidth: CGFloat { max(120, min(300, width - 2 * cardWidth - 24)) }
        var photoRect: CGRect {
            let h = photoWidth * 1.5
            return CGRect(x: (width - photoWidth) / 2, y: (height - h) / 2, width: photoWidth, height: h)
        }
        func center(_ p: Placement) -> CGPoint {
            CGPoint(x: p.right ? width - cardWidth / 2 : cardWidth / 2,
                    y: cardHeight / 2 + CGFloat(p.row) * rowStride)
        }
        func anchor(_ p: Placement) -> CGPoint {
            CGPoint(x: photoRect.minX + p.x * photoRect.width, y: photoRect.minY + p.y * photoRect.height)
        }
        func tip(_ p: Placement) -> CGPoint {
            CGPoint(x: p.right ? width - cardWidth - 7 : cardWidth + 7, y: center(p).y)
        }
    }
}
