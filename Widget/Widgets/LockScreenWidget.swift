import WidgetKit
import SwiftUI

struct LockScreenProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SetEntry { .empty() }

    func snapshot(for configuration: LockScreenWidgetIntent, in context: Context) async -> SetEntry {
        WidgetData.timeline(for: configuration.photoSet, endAtMidnight: true).entries.first ?? .empty()
    }

    func timeline(for configuration: LockScreenWidgetIntent, in context: Context) async -> Timeline<SetEntry> {
        WidgetData.timeline(for: configuration.photoSet, endAtMidnight: true)
    }
}

/// Lock Screen widgets are drawn by iOS in a tinted "vibrant" style, so photos appear
/// as luminous monochrome cut-outs. Each set's Lock Screen style (shape, look, layout,
/// text) is edited in Framely › Style › Lock Screen.
struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SetEntry

    private var content: LockContent {
        let style = entry.lockStyle
        let count = family == .accessoryRectangular && style.rectLayout == .strip ? 3 : 1
        let images: [UIImage?] = (0..<count).map { shift in
            entry.photo(shift: shift).flatMap {
                ImageStore.image(for: $0, maxPixel: family.maxPixel, lockLook: style.look, persist: true)
            }
        }
        return LockContent(images: images, item: entry.photo(), set: entry.set, style: style, date: entry.date)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                LockCircularView(content: content)
            case .accessoryRectangular:
                LockRectangularView(content: content)
            default: // .accessoryInline — iOS only allows text + a symbol here
                LockInlineView(content: content)
            }
        }
        .containerBackground(for: .widget) { Color.clear }
        .widgetURL(entry.set.map { DeepLink.set($0.id).url } ?? DeepLink.newSet.url)
    }
}

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.lockScreen, intent: LockScreenWidgetIntent.self, provider: LockScreenProvider()) { entry in
            LockScreenWidgetView(entry: entry)
        }
        .configurationDisplayName("Lock Screen Photo")
        .description("A tiny rotating photo for your Lock Screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
