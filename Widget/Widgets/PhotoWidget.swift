import WidgetKit
import AppIntents
import SwiftUI

struct PhotoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SetEntry { .empty() }

    func snapshot(for configuration: PhotoWidgetIntent, in context: Context) async -> SetEntry {
        timeline(configuration, isPreview: context.isPreview).entries.first ?? .empty()
    }

    func timeline(for configuration: PhotoWidgetIntent, in context: Context) async -> Timeline<SetEntry> {
        timeline(configuration, isPreview: false)
    }

    private func timeline(_ configuration: PhotoWidgetIntent, isPreview: Bool) -> Timeline<SetEntry> {
        let base = WidgetData.timeline(for: configuration.photoSet, isPreview: isPreview)
        let entries = base.entries.map { entry -> SetEntry in
            var e = entry
            e.showNextButton = configuration.showNextButton
            return e
        }
        return Timeline(entries: entries, policy: base.policy)
    }
}

struct PhotoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SetEntry

    var body: some View {
        if let set = entry.set, let item = entry.photo() {
            let content = FramedPhotoContent(
                image: ImageStore.image(for: item, maxPixel: family.maxPixel, filter: entry.style.filter),
                item: item,
                style: entry.style,
                size: FrameSize(family)
            )
            FramedPhotoView(content: content)
                .id(item.id)
                .transition(.push(from: .trailing))
                .overlay(alignment: .topTrailing) {
                    if entry.showNextButton && set.photos.count > 1 {
                        Button(intent: NextPhotoIntent(setID: set.id)) { NextPhotoGlyph() }
                            .buttonStyle(.plain)
                            .padding(8)
                    }
                }
                .containerBackground(for: .widget) { FramedPhotoBackground(content: content) }
                .widgetURL(DeepLink.set(set.id).url)
        } else {
            EmptyWidgetView(message: entry.set.map { "Add photos to “\($0.name)”" } ?? "Create a photo set in Framely")
                .containerBackground(for: .widget) { EmptyWidgetBackground() }
                .widgetURL(entry.set.map { DeepLink.set($0.id).url } ?? DeepLink.newSet.url)
        }
    }
}

struct PhotoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.photo, intent: PhotoWidgetIntent.self, provider: PhotoProvider()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName("Photo")
        .description("Your photos, rotating on your schedule. Tap the arrow for the next one.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
