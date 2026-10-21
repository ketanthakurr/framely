import WidgetKit
import SwiftUI

struct InfoEntry: TimelineEntry {
    let date: Date
    let base: SetEntry
    let mode: InfoMode
    let countdownTitle: String
    let countdownDate: Date?
}

struct InfoProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> InfoEntry {
        InfoEntry(date: .now, base: .empty(), mode: .date, countdownTitle: "Weekend trip", countdownDate: nil)
    }

    func snapshot(for configuration: InfoWidgetIntent, in context: Context) async -> InfoEntry {
        make(configuration).entries.first ?? placeholder(in: context)
    }

    func timeline(for configuration: InfoWidgetIntent, in context: Context) async -> Timeline<InfoEntry> {
        make(configuration)
    }

    private func make(_ c: InfoWidgetIntent) -> Timeline<InfoEntry> {
        let base = WidgetData.timeline(for: c.photoSet, endAtMidnight: true)
        return Timeline(
            entries: base.entries.map {
                InfoEntry(date: $0.date, base: $0, mode: c.mode, countdownTitle: c.countdownTitle, countdownDate: c.countdownDate)
            },
            policy: base.policy
        )
    }
}

struct InfoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: InfoEntry

    var body: some View {
        if !entry.base.gate.infoWidget {
            LockedWidgetView(title: "Photo + Info widgets")
        } else {
            let item = chosenPhoto
            let image = item.flatMap { ImageStore.image(for: $0, maxPixel: family.maxPixel, filter: entry.base.style.filter, persist: true) }
            let accent = item?.dominantColorHex.map(Color.init(hex:)) ?? Color(hex: "#8E8CF0")

            layout(image: image, item: item, accent: accent)
                .containerBackground(for: .widget) {
                    ZStack {
                        PhotoFill(image: image).blur(radius: 26).scaleEffect(1.3)
                        accent.opacity(0.25)
                    }
                }
                .widgetURL(entry.base.set.map { DeepLink.set($0.id).url } ?? DeepLink.newSet.url)
        }
    }

    // MARK: Layouts

    @ViewBuilder
    private func layout(image: UIImage?, item: PhotoItem?, accent: Color) -> some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 12) {
                PhotoFill(image: image)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: accent.opacity(0.5), radius: 8, y: 3)
                    .frame(maxWidth: .infinity)
                info(item: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
        case .systemLarge:
            VStack(spacing: 12) {
                PhotoFill(image: image)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: accent.opacity(0.5), radius: 10, y: 4)
                info(item: item)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            }
            .padding(14)
        default:
            ZStack(alignment: .bottomLeading) {
                PhotoFill(image: image)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                info(item: item).padding(12)
            }
        }
    }

    // MARK: Info blocks

    @ViewBuilder
    private func info(item: PhotoItem?) -> some View {
        switch entry.mode {
        case .date: dateBlock
        case .countdown: countdownBlock
        case .onThisDay: onThisDayBlock(item: item)
        }
    }

    private var bigSize: CGFloat { family == .systemSmall ? 34 : 44 }

    private var dateBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.date, format: .dateTime.weekday(.wide))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .textCase(.uppercase)
                .opacity(0.85)
            Text(entry.date, format: .dateTime.day())
                .font(.system(size: bigSize, weight: .bold, design: .rounded))
            Text(entry.date, format: .dateTime.month(.wide))
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .opacity(0.9)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
    }

    private var countdownBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let target = entry.countdownDate {
                let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date),
                                                           to: Calendar.current.startOfDay(for: target)).day ?? 0
                if days > 0 {
                    Text("\(days)")
                        .font(.system(size: bigSize, weight: .bold, design: .rounded))
                        .contentTransition(.numericText(countsDown: true))
                    Text(days == 1 ? "day to go" : "days to go")
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).opacity(0.85)
                } else if days == 0 {
                    Text("Today ✨").font(.system(size: bigSize * 0.7, weight: .bold, design: .rounded))
                } else {
                    Text("\(-days)d ago").font(.system(size: bigSize * 0.7, weight: .bold, design: .rounded))
                }
            } else {
                Text("Set a date").font(.system(size: 18, weight: .bold, design: .rounded))
                Text("Touch and hold › Edit Widget").font(.system(size: 11, weight: .medium, design: .rounded)).opacity(0.8)
            }
            Text(entry.countdownTitle)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .lineLimit(2)
                .padding(.top, 2)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
    }

    private func onThisDayBlock(item: PhotoItem?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("On this day", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .opacity(0.9)
            if let years = yearsAgo(item) {
                Text(years == 1 ? "1 year ago" : "\(years) years ago")
                    .font(.system(size: family == .systemSmall ? 20 : 26, weight: .bold, design: .rounded))
            } else {
                Text("No memories today")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Here’s one from your set")
                    .font(.system(size: 11, weight: .medium, design: .rounded)).opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
    }

    // MARK: Data

    private var chosenPhoto: PhotoItem? {
        if entry.mode == .onThisDay, let set = entry.base.set {
            let memories = PhotoScheduler.onThisDay(in: [set], date: entry.date)
            if !memories.isEmpty { return memories[abs(entry.base.slot) % memories.count] }
        }
        return entry.base.photo()
    }

    private func yearsAgo(_ item: PhotoItem?) -> Int? {
        guard entry.mode == .onThisDay, let captured = item?.capturedAt else { return nil }
        let cal = Calendar.current
        let a = cal.dateComponents([.month, .day], from: captured)
        let b = cal.dateComponents([.month, .day], from: entry.date)
        guard a.month == b.month, a.day == b.day else { return nil }
        let years = cal.dateComponents([.year], from: captured, to: entry.date).year ?? 0
        return years > 0 ? years : nil
    }
}

struct InfoWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKind.info, intent: InfoWidgetIntent.self, provider: InfoProvider()) { entry in
            InfoWidgetView(entry: entry)
        }
        .configurationDisplayName("Photo + Info")
        .description("A photo with today’s date, a countdown, or a memory from this day.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
