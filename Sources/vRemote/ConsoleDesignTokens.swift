import AppKit
import SwiftUI

/// Native semantic counterpart of the approved HTML v6 token sheet.
/// Keep the HTML reference developer-only; these are shared by all app pages.
enum ConsoleDesignTokens {
    static let sidebarWidth: CGFloat = 219
    static let headerHeight: CGFloat = 65
    static let pagePadding: CGFloat = 32
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let transitionDuration: Double = 0.2

    static let window = color(0xf9f9f8, 0x25272e)
    static let sidebar = color(0xf1f1ef, 0x21232a)
    static let surface = color(0xffffff, 0x2e3038)
    static let secondarySurface = color(0xf4f4f2, 0x292b33)
    static let text = color(0x292b31, 0xedeef3)
    static let secondaryText = color(0x757780, 0xaaaeba)
    static let line = color(0xe6e6e6, 0x3d3f48)
    static let accent = color(0x6865de, 0x9892ff)
    static let selection = color(0xeeedff, 0x3c395a)
    static let accentText = color(0x5957c2, 0xbebaff)
    static let success = color(0x358366, 0x85c4a4)
    static let successBackground = color(0xe8f4ed, 0x293e37)
    static let error = color(0xbc5158, 0xf0989d)
    static let errorBackground = color(0xfff0f1, 0x4b3038)
    static let hero = color(0xecebf6, 0x333440)

    private static func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                           green: CGFloat((value >> 8) & 255) / 255,
                           blue: CGFloat(value & 255) / 255, alpha: 1)
        })
    }
}

struct ConsoleCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(ConsoleDesignTokens.surface)
            .cornerRadius(ConsoleDesignTokens.cardRadius)
            .overlay(RoundedRectangle(cornerRadius: ConsoleDesignTokens.cardRadius)
                .stroke(ConsoleDesignTokens.line, lineWidth: 1))
    }
}

struct ConsoleNotice: View {
    let text: String
    var isError = false
    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.circle" : "info.circle")
            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
            .foregroundColor(isError ? ConsoleDesignTokens.error : ConsoleDesignTokens.secondaryText)
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(isError ? ConsoleDesignTokens.errorBackground : ConsoleDesignTokens.secondarySurface)
            .cornerRadius(10)
    }
}

struct ConsolePrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).frame(minHeight: 36)
            .foregroundColor(Color.white)
            .background(ConsoleDesignTokens.accent.opacity(configuration.isPressed ? 0.8 : 1))
            .cornerRadius(ConsoleDesignTokens.controlRadius).opacity(enabled ? 1 : 0.4)
    }
}

struct ConsoleAppearancePicker: View {
    @Binding var selection: AppAppearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var slider
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppAppearance.allCases, id: \.self) { appearance in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: ConsoleDesignTokens.transitionDuration)) {
                        selection = appearance
                    }
                } label: {
                    Text(title(appearance)).font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(Group {
                            if selection == appearance {
                                RoundedRectangle(cornerRadius: 7).fill(ConsoleDesignTokens.surface)
                                    .matchedGeometryEffect(id: "appearance", in: slider)
                            }
                        })
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("外观：" + title(appearance))
                    .accessibilityValue(selection == appearance ? "已选择" : "未选择")
            }
        }.padding(3).frame(width: 252).background(ConsoleDesignTokens.secondarySurface)
            .cornerRadius(9).accessibilityElement(children: .contain)
    }
    private func title(_ appearance: AppAppearance) -> String {
        switch appearance { case .system: return "跟随系统"; case .light: return "浅色"; case .dark: return "深色" }
    }
}
