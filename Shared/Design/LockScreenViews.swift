import SwiftUI
import WidgetKit

/// Everything a Lock Screen widget needs to draw. Shared by the widget and the in-app preview.
struct LockContent {
    var images: [UIImage?]          // [0] = current photo, [1…2] = next photos (strip layout)
    var item: PhotoItem?
    var set: PhotoSet?
    var style: LockScreenStyle
    var date: Date
    /// True inside the real widget (uses the system's AccessoryWidgetBackground).
    var systemBackground: Bool = true

    var primary: String? { LockScreenStyle.text(style.primaryText, set: set, item: item, date: date, custom: style.customText) }
    var secondary: String? { LockScreenStyle.text(style.secondaryText, set: set, item: item, date: date, custom: style.customText) }
    var image: UIImage? { images.first ?? nil }
}

// MARK: - Shapes

struct HeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.06))
        p.addCurve(to: CGPoint(x: rect.minX + w * 0.02, y: rect.minY + h * 0.34),
                   control1: CGPoint(x: rect.midX - w * 0.30, y: rect.maxY - h * 0.28),
                   control2: CGPoint(x: rect.minX - w * 0.04, y: rect.minY + h * 0.58))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.22),
                   control1: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.02),
                   control2: CGPoint(x: rect.midX - w * 0.06, y: rect.minY + h * 0.04))
        p.addCurve(to: CGPoint(x: rect.maxX - w * 0.02, y: rect.minY + h * 0.34),
                   control1: CGPoint(x: rect.midX + w * 0.06, y: rect.minY + h * 0.04),
                   control2: CGPoint(x: rect.maxX - w * 0.08, y: rect.minY + h * 0.02))
        p.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.06),
                   control1: CGPoint(x: rect.maxX + w * 0.04, y: rect.minY + h * 0.58),
                   control2: CGPoint(x: rect.midX + w * 0.30, y: rect.maxY - h * 0.28))
        p.closeSubpath()
        return p
    }
}

struct StarShape: Shape {
    var points = 5
    var innerRatio: CGFloat = 0.5

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        var p = Path()
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outer : inner
            let angle = Double(i) * .pi / Double(points) - .pi / 2
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

extension LockShape {
    var shape: AnyShape {
        switch self {
        case .circle, .ring: AnyShape(Circle())
        case .squircle: AnyShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        case .heart: AnyShape(HeartShape())
        case .star: AnyShape(StarShape(innerRatio: 0.58))
        }
    }
}

// MARK: - Photo helper

private struct LockPhoto: View {
    let image: UIImage?

    var body: some View {
        GeometryReader { geo in
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
}

// MARK: - Circular

struct LockCircularView: View {
    let content: LockContent

    private var style: LockScreenStyle { content.style }

    var body: some View {
        ZStack {
            if style.shape == .ring || style.shape == .circle {
                background
            }
            photo
                .padding(style.shape == .ring ? 6 : (style.shape == .circle ? 0 : 3))
            if style.shape == .ring {
                Circle().strokeBorder(lineWidth: 2.5).widgetAccentable()
            }
        }
    }

    private var photo: some View {
        LockPhoto(image: content.image)
            .opacity(style.intensity)
            .clipShape(style.shape.shape)
            .overlay {
                if style.border {
                    style.shape.shape.stroke(lineWidth: 1.5).widgetAccentable()
                }
            }
    }

    @ViewBuilder
    private var background: some View {
        if content.systemBackground {
            AccessoryWidgetBackground()
        } else {
            Circle().fill(.white.opacity(0.18))
        }
    }
}

// MARK: - Rectangular

struct LockRectangularView: View {
    let content: LockContent

    private var style: LockScreenStyle { content.style }

    var body: some View {
        switch style.rectLayout {
        case .photoAndText:
            HStack(spacing: 8) {
                framed(content.image)
                    .aspectRatio(1, contentMode: .fit)
                texts(alignment: .leading)
                Spacer(minLength: 0)
            }
        case .photoOnly:
            framed(content.image)
        case .strip:
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    framed(i < content.images.count ? content.images[i] : nil, radius: 8)
                }
            }
        case .textOverPhoto:
            ZStack(alignment: .bottomLeading) {
                framed(content.image)
                texts(alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .shadow(color: .black, radius: 3)
            }
        }
    }

    private func framed(_ image: UIImage?, radius: CGFloat = 12) -> some View {
        LockPhoto(image: image)
            .opacity(style.intensity)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if style.border {
                    RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(lineWidth: 1.5).widgetAccentable()
                }
            }
    }

    @ViewBuilder
    private func texts(alignment: HorizontalAlignment) -> some View {
        if content.primary != nil || content.secondary != nil {
            VStack(alignment: alignment, spacing: 1) {
                if let primary = content.primary {
                    Text(primary)
                        .font(.system(.headline, design: .rounded))
                        .widgetAccentable()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                if let secondary = content.secondary {
                    Text(secondary)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(2)
                }
            }
        }
    }
}

// MARK: - Inline

struct LockInlineView: View {
    let content: LockContent

    var body: some View {
        Label(content.primary ?? content.set?.name ?? "Framely", systemImage: content.set?.symbol ?? "photo")
    }
}
