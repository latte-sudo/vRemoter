import AppKit
import SwiftUI

/// Photo, callouts and cards share one coordinate system, so resizing cannot
/// separate a connector from its physical button or its destination card.
struct ChromecastMappingCanvas: View {
    @ObservedObject private var language = LanguageStore.shared
    let selectedButton: String
    let selectedGesture: RemoteButtonGesture?
    let observedButton: String?
    let voiceActive: Bool
    let voiceModeTitle: String
    let onSelect: (String) -> Void
    let onEdit: (String, RemoteButtonGesture) -> Void
    let onVoiceSettings: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = max(760, proxy.size.width)
            let metrics = ChromecastMappingLayout.Metrics(width: width)
            ScrollView(.horizontal, showsIndicators: proxy.size.width < 760) {
            ZStack(alignment: .topLeading) {
                photo.frame(width: metrics.photoRect.width, height: metrics.photoRect.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .position(x: metrics.photoRect.midX, y: metrics.photoRect.midY)
                connections(metrics).allowsHitTesting(false)
                ForEach(ChromecastMappingLayout.placements, id: \.id) { placement in
                    card(placement)
                        .frame(width: metrics.cardWidth, height: ChromecastMappingLayout.cardHeight)
                        .position(metrics.center(placement))
                    hotspot(placement).position(metrics.anchor(placement))
                }
            }.frame(width: width, height: ChromecastMappingLayout.height)
            }
        }.frame(height: ChromecastMappingLayout.height)
    }

    @ViewBuilder private var photo: some View {
        if let image = ChromecastMappingPhoto.image {
            Image(nsImage: image).resizable().scaledToFit()
        } else {
            RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1))
                .overlay(Text(L10n.tr("support.canvas.photoMissing")).font(.caption))
        }
    }

    @ViewBuilder private func card(_ placement: ChromecastMappingLayout.Placement) -> some View {
        if placement.id == "voice" {
            ChromecastVoiceMappingCard(active: voiceActive, modeTitle: voiceModeTitle, onSettings: onVoiceSettings)
        } else if let button = RemoteProfiles.chromecastButtons.first(where: { $0.id == placement.id }) {
            ChromecastMappingCard(button: button, selected: selectedButton == button.id,
                observed: observedButton == button.id,
                selectedGesture: selectedButton == button.id ? selectedGesture : nil,
                onSelect: { onSelect(button.id) }, onEdit: { onEdit(button.id, $0) })
        }
    }

    private func hotspot(_ placement: ChromecastMappingLayout.Placement) -> some View {
        let title = RemoteProfiles.chromecastButtons.first(where: { $0.id == placement.id })?.title ?? L10n.tr("support.button.voice")
        return Button {
            if placement.id == "voice" { onVoiceSettings() } else { onSelect(placement.id) }
        } label: {
            Circle().fill(Color.clear)
                .overlay(Circle().stroke(observedButton == placement.id ? Color.green : Color.clear, lineWidth: 2))
                .frame(width: 28, height: 28).contentShape(Circle())
        }.buttonStyle(.plain).help(title).accessibilityLabel(L10n.tr("support.canvas.locate", title))
    }

    private func connections(_ metrics: ChromecastMappingLayout.Metrics) -> some View {
        Canvas { context, _ in
            for placement in ChromecastMappingLayout.placements {
                let start = metrics.anchor(placement)
                let end = metrics.tip(placement)
                let active = placement.id == "voice" ? voiceActive : observedButton == placement.id
                let selected = placement.id == selectedButton
                let color: Color = active ? .green : selected ? .accentColor : Color.secondary.opacity(0.32)
                let direction: CGFloat = placement.right ? 1 : -1
                let bend = max(24, abs(end.x - start.x) * 0.45)
                var path = Path()
                path.move(to: start)
                path.addCurve(to: end,
                    control1: CGPoint(x: start.x + direction * bend, y: start.y),
                    control2: CGPoint(x: end.x - direction * bend, y: end.y))
                context.stroke(path, with: .color(color), lineWidth: selected || active ? 1.8 : 1)
                var arrow = Path()
                arrow.move(to: end)
                arrow.addLine(to: CGPoint(x: end.x - direction * 6, y: end.y - 3))
                arrow.addLine(to: CGPoint(x: end.x - direction * 6, y: end.y + 3))
                arrow.closeSubpath()
                context.fill(arrow, with: .color(color))
            }
        }
    }
}

private struct ChromecastMappingCard: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let button: RemoteButtonDefinition
    let selected: Bool
    let observed: Bool
    let selectedGesture: RemoteButtonGesture?
    let onSelect: () -> Void
    let onEdit: (RemoteButtonGesture) -> Void
    @ObservedObject private var store = RemoteMappingStore.shared

    private var tint: Color { observed ? .green : .accentColor }
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Image(systemName: button.symbol).frame(width: 14)
                    Text(button.title).fontWeight(.semibold).lineLimit(1)
                    Spacer(minLength: 0)
                    if observed { Text(L10n.tr("support.canvas.received")).font(.caption2).foregroundColor(.green) }
                }.font(.system(size: 13)).contentShape(Rectangle())
            }.buttonStyle(.plain)
            HStack(spacing: 4) {
                ForEach(RemoteButtonGesture.allCases, id: \.self) { gesture in
                    ChromecastMappingGestureCell(buttonTitle: button.title, gesture: gesture,
                        actionTitle: store.targetTitle(for: button, remote: .chromecast, gesture: gesture),
                        selected: selectedGesture == gesture, onEdit: { onEdit(gesture) })
                }
            }
        }.padding(.horizontal, 9).padding(.vertical, 6)
            .background((selected || observed ? tint.opacity(0.10) : Color.primary.opacity(0.035)))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected || observed ? tint.opacity(0.5) : Color.secondary.opacity(0.15)))
            .accessibilityElement(children: .contain)
    }
}

private struct ChromecastMappingGestureCell: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let buttonTitle: String
    let gesture: RemoteButtonGesture
    let actionTitle: String
    let selected: Bool
    let onEdit: () -> Void

    private var label: some View {
        VStack(spacing: 1) {
            Text(gesture.title).foregroundColor(.secondary).fontWeight(.medium).lineLimit(1).minimumScaleFactor(0.8)
            Text(actionTitle).fontWeight(gesture == .click ? .semibold : .regular)
                .lineLimit(1).truncationMode(.tail)
        }.font(.system(size: 12))
            .frame(maxWidth: .infinity).padding(.vertical, 5)
            .background(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
            .cornerRadius(5)
            .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
    }
    var body: some View {
        Button(action: onEdit) { label }.buttonStyle(.plain)
            .help(L10n.tr("support.canvas.actionHelp", buttonTitle, gesture.title, actionTitle))
            .accessibilityLabel(L10n.tr("support.canvas.editAction", buttonTitle, gesture.title, actionTitle))
    }
}

private struct ChromecastVoiceMappingCard: View {
    @ObservedObject private var languageStore = LanguageStore.shared
    let active: Bool
    let modeTitle: String
    let onSettings: () -> Void
    var body: some View {
        Button(action: onSettings) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Label(L10n.tr("support.canvas.voiceButton"), systemImage: "mic.fill").font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 0)
                    Text(L10n.tr("support.canvas.voiceOnly")).font(.system(size: 10)).foregroundColor(.secondary)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12)).clipShape(Capsule())
                }.font(.system(size: 13))
                Text(modeTitle).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(2)
                Text(L10n.tr("support.canvas.editVoice")).font(.system(size: 10)).foregroundColor(.accentColor).lineLimit(1)
            }.padding(.horizontal, 9).padding(.vertical, 6)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(active ? Color.green.opacity(0.1) : Color.primary.opacity(0.035))
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
        }.buttonStyle(.plain).help(L10n.tr("support.canvas.voiceHelp"))
    }
}

enum ChromecastMappingPhoto {
    static let image: NSImage? = {
        let filename = "chromecast-front-and-volume-enhanced.png"
        let paths = [Bundle.main.resourceURL?.appendingPathComponent("RemoteImages/" + filename),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Resources/RemoteImages/" + filename)]
        for path in paths.compactMap({ $0 }) {
            if let image = NSImage(contentsOf: path) { return image }
        }
        return nil
    }()
}
