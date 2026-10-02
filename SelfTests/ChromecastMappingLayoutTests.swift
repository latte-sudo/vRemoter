import Foundation

@main
struct ChromecastMappingLayoutTests {
    static func main() {
        let placements = ChromecastMappingLayout.placements
        precondition(placements.filter { !$0.right }.map(\.id) == ["03", "05", "04", "0B", "0A", "0E", "01"])
        precondition(placements.filter(\.right).map(\.id) == ["07", "06", "0C", "0D", "voice", "08", "0F", "11"])
        precondition(Set(placements.map(\.id)).count == 15)
        precondition(placements.first { $0.id == "voice" }?.row == 4)
        for width in [CGFloat(760), 800, 924, 1020, 1400] {
            let m = ChromecastMappingLayout.Metrics(width: width)
            precondition(m.photoRect.minX > m.cardWidth)
            precondition(m.photoRect.maxX < width - m.cardWidth)
            precondition(abs(m.photoRect.height / m.photoRect.width - 1.5) < 0.001)
            for p in placements {
                let center = m.center(p)
                precondition(center.y - ChromecastMappingLayout.cardHeight / 2 >= 0)
                precondition(center.y + ChromecastMappingLayout.cardHeight / 2 <= ChromecastMappingLayout.height)
                precondition(m.photoRect.contains(m.anchor(p)))
                precondition(m.tip(p).y == center.y)
                precondition(p.right ? m.tip(p).x > m.photoRect.maxX : m.tip(p).x < m.photoRect.minX)
            }
        }
        print("Chromecast mapping layout geometry passed")
    }
}
