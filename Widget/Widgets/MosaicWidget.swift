import WidgetKit
import SwiftUI

struct MosaicEntry: TimelineEntry {
    let date: Date
    let base: SetEntry
    let layout: MosaicLayout
}

struct MosaicProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MosaicEntry { MosaicEntry(date: .now, base: .empty(), layout: .grid) }

    func snapshot(for configuration: MosaicWidgetIntent, in context: Context) async -> MosaicEntry {
        make(configuration).entries.first ?? placeholder(in: context)
    }

    func timeline(for configuration: MosaicWidgetIntent, in context: Context) async -> Timeline<MosaicEntry> {
        make(configuration)
    }

    private func make(_ configuration: MosaicWidgetIntent) -> Timeline<MosaicEntry> {
        let base = WidgetData.timeline(for: configuration.photoSet)
        return Timeline(
            entries: base.entries.map { MosaicEntry(date: $0.date, base: $0, layout: configuration.layout) },
            policy: base.policy
        )
    }
}

struct MosaicWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MosaicEntry

    private var base: SetEntry { entry.base }

    var body: some View {
        if !base.gate.mosaic {
            LockedWidgetView(title: "Mosaic widgets")
        } else if let set = base.set, !set.photos.isEmpty {
            MosaicContent(entry: base, layout: entry.layout, family: family)
                .containerBackground(for: .widget) { background }
                .widgetURL(DeepLink.set(set.id).url)
        } else {
            EmptyWidgetView()
                .containerBackground(for: .widget) { EmptyWidgetBackground() }
                .widgetURL(DeepLink.newSet.url)
        }
    }

    @ViewBuilder
    private var background: some View {
        let style = base.style
        switch entry.layout {
        case .filmStrip:
            Color(hex: "#111111")
        case .grid, .polaroidStack:
            if style.theme == .auto {
                let color = base.photo()?.dominantColorHex.map(Color.init(hex:)) ?? Color(hex: "#8E8CF0")
                LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
            } else {
                style.theme.palette(photoColor: nil).background
            }
        }
    }
}

/// Collage layouts. Also used by the in-app widget gallery preview.
struct MosaicContent: View {
    let entry: SetEntry
    let layout: MosaicLayout
    let family: WidgetFamily

    private let gap: CGFloat = 4

    private func image(_ shift: Int, maxPixel: CGFloat = 600) -> UIImage? {
        guard let item = entry.photo(shift: shift) else { return nil }
        return ImageStore.image(for: item, maxPixel: maxPixel, filter: entry.style.filter)
    }

    private var tileRadius: CGFloat { max(4, entry.style.innerCornerRadius * 0.7) }

    var body: some View {
        switch layout {
        case .grid: grid.padding(6)
        case .filmStrip: filmStrip
        case .polaroidStack: polaroidStack
        }
    }

    // MARK: Grid

    @ViewBuilder
    private var grid: some View {
        switch family {
        case .systemMedium:
            HStack(spacing: gap) {
                tile(0, maxPixel: 800)
                VStack(spacing: gap) { tile(1); tile(2) }
                    .frame(maxWidth: .infinity)
            }
        case .systemLarge:
            VStack(spacing: gap) {
                tile(0, maxPixel: 1000).frame(maxHeight: .infinity).layoutPriority(1)
                HStack(spacing: gap) { tile(1); tile(2); tile(3) }
                    .frame(height: 110)
            }
        default:
            VStack(spacing: gap) {
                HStack(spacing: gap) { tile(0, maxPixel: 300); tile(1, maxPixel: 300) }
                HStack(spacing: gap) { tile(2, maxPixel: 300); tile(3, maxPixel: 300) }
            }
        }
    }

    private func tile(_ shift: Int, maxPixel: CGFloat = 600) -> some View {
        PhotoFill(image: image(shift, maxPixel: maxPixel))
            .clipShape(RoundedRectangle(cornerRadius: tileRadius, style: .continuous))
    }

    // MARK: Film strip

    private var filmStrip: some View {
        let count = family == .systemMedium ? 3 : (family == .systemLarge ? 3 : 2)
        let horizontal = family == .systemMedium
        return Group {
            if horizontal {
                VStack(spacing: 4) {
                    sprocketRow(horizontal: true)
                    HStack(spacing: 4) { ForEach(0..<count, id: \.self) { frameTile($0) } }
                    sprocketRow(horizontal: true)
                }
                .padding(.vertical, 5)
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 4) {
                    sprocketRow(horizontal: false)
                    VStack(spacing: 4) { ForEach(0..<count, id: \.self) { frameTile($0) } }
                    sprocketRow(horizontal: false)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
            }
        }
    }

    private func frameTile(_ shift: Int) -> some View {
        PhotoFill(image: image(shift))
            .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    @ViewBuilder
    private func sprocketRow(horizontal: Bool) -> some View {
        let hole = RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.85))
        if horizontal {
            HStack(spacing: 6) { ForEach(0..<18, id: \.self) { _ in hole.frame(height: 5) } }
        } else {
            VStack(spacing: 6) { ForEach(0..<12, id: \.self) { _ in hole.frame(width: 5) } }
        }
    }

    // MARK: Polaroid stack

    private var polaroidStack: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height) * (family == .systemMedium ? 0.78 : 0.62)
            let spread: CGFloat = family == .systemMedium ? geo.size.width * 0.26 : side * 0.12
            ZStack {
                polaroid(2, side: side).rotationEffect(.degrees(-9)).offset(x: -spread, y: 4)
                polaroid(1, side: side).rotationEffect(.degrees(8)).offset(x: spread, y: 2)
                polaroid(0, side: side).rotationEffect(.degrees(-1.5))
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func polaroid(_ shift: Int, side: CGFloat) -> some View {
        VStack(spacing: 0) {
            PhotoFill(image: image(shift, maxPixel: 500))
                .frame(width: side - 10, height: side - 10)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(width: side, height: side * 1.16)
        .background(Color(hex: "#FBF8F2"), in: RoundedRectangle(cornerRadius: 3))
        .shadow(color: .black.opacity(0.28), radius: 6, y: 3)
    }
}

struct MosaicWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.mosaic, intent: MosaicWidgetIntent.self, provider: MosaicProvider()) { entry in
            MosaicWidgetView(entry: entry)
        }
        .configurationDisplayName("Mosaic")
        .description("A grid, film strip or polaroid stack of your photos.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
