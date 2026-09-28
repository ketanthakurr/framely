import SwiftUI
import WidgetKit

/// Size class a framed photo is being drawn at (affects paddings and type sizes).
enum FrameSize: Sendable {
    case small, medium, large

    init(_ family: WidgetFamily) {
        switch family {
        case .systemSmall: self = .small
        case .systemMedium: self = .medium
        default: self = .large
        }
    }

    var padding: CGFloat { self == .small ? 8 : 11 }
    var captionFont: Font {
        switch self {
        case .small: .system(size: 11, weight: .semibold, design: .rounded)
        case .medium: .system(size: 13, weight: .semibold, design: .rounded)
        case .large: .system(size: 15, weight: .semibold, design: .rounded)
        }
    }
}

/// Everything needed to draw one photo in a frame. Shared by widgets and in-app previews.
struct FramedPhotoContent {
    var image: UIImage?
    var item: PhotoItem?
    var style: WidgetStyle
    var size: FrameSize

    var photoColor: Color? { item?.dominantColorHex.map(Color.init(hex:)) }
    var palette: ThemePalette { style.theme.palette(photoColor: photoColor) }
}

// MARK: - Background (goes into .containerBackground in widgets)

struct FramedPhotoBackground: View {
    let content: FramedPhotoContent

    var body: some View {
        switch content.style.frame {
        case .edgeToEdge:
            PhotoFill(image: content.image)
        case .glass:
            ZStack {
                PhotoFill(image: content.image).blur(radius: 18).scaleEffect(1.25)
                content.palette.background.opacity(content.style.theme == .auto ? 0.15 : 0.45)
            }
        case .film:
            Color(hex: "#111111")
        case .polaroid:
            content.style.theme == .auto ? Color(hex: "#FBF8F2") : content.palette.frame
        case .inset, .arch:
            if content.style.theme == .auto {
                ZStack {
                    PhotoFill(image: content.image).blur(radius: 24).scaleEffect(1.3)
                    Color.black.opacity(0.08)
                }
            } else {
                content.palette.background
            }
        }
    }
}

// MARK: - Foreground

struct FramedPhotoView: View {
    let content: FramedPhotoContent

    private var style: WidgetStyle { content.style }
    private var p: CGFloat { content.size.padding }

    var body: some View {
        switch style.frame {
        case .edgeToEdge:
            PhotoFill(image: content.image)
                .overlay(alignment: style.overlayPosition.alignment) { overlayText(light: true).padding(p + 4) }
                .background(scrim)

        case .inset:
            insetPhoto(shape: RoundedRectangle(cornerRadius: style.innerCornerRadius, style: .continuous))
                .padding(p)

        case .arch:
            insetPhoto(shape: UnevenRoundedRectangle(
                topLeadingRadius: 400, bottomLeadingRadius: style.innerCornerRadius,
                bottomTrailingRadius: style.innerCornerRadius, topTrailingRadius: 400, style: .continuous))
                .padding(p)

        case .glass:
            insetPhoto(shape: RoundedRectangle(cornerRadius: style.innerCornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: style.innerCornerRadius, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.8), .white.opacity(0.1)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2)
                }
                .overlay {
                    // Glossy sheen
                    LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                        .clipShape(RoundedRectangle(cornerRadius: style.innerCornerRadius, style: .continuous))
                        .allowsHitTesting(false)
                }
                .padding(p + 2)

        case .polaroid:
            polaroid

        case .film:
            film
        }
    }

    // MARK: Pieces

    private func insetPhoto<S: Shape>(shape: S) -> some View {
        PhotoFill(image: content.image)
            .clipShape(shape)
            .overlay(alignment: style.overlayPosition.alignment) { overlayText(light: true).padding(p) }
            .shadow(color: style.glow ? (content.photoColor ?? .black).opacity(0.55) : .black.opacity(0.18),
                    radius: style.glow ? 12 : 4, y: 3)
    }

    private var polaroid: some View {
        let textColor = style.theme == .auto ? Color(hex: "#3B3530") : content.palette.text
        return VStack(spacing: 0) {
            PhotoFill(image: content.image)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            HStack {
                if style.showCaption, let caption = content.item?.caption, !caption.isEmpty {
                    Text(caption).lineLimit(1)
                } else if style.showDate, let date = content.item?.capturedAt {
                    Text(date, format: .dateTime.day().month(.abbreviated).year())
                }
                Spacer(minLength: 0)
            }
            .font(.system(size: content.size == .small ? 11 : 14, weight: .medium, design: .serif).italic())
            .foregroundStyle(textColor)
            .frame(height: content.size == .small ? 22 : 30)
        }
        .padding([.top, .horizontal], p)
        .padding(.bottom, 2)
    }

    private var film: some View {
        VStack(spacing: 4) {
            sprockets
            PhotoFill(image: content.image)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .bottomTrailing) {
                    if style.showDate, let date = content.item?.capturedAt {
                        Text(Self.filmStamp.string(from: date))
                            .font(.system(size: content.size == .small ? 10 : 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(hex: "#FF8A3D"))
                            .shadow(color: Color(hex: "#FF5A00").opacity(0.9), radius: 3)
                            .padding(6)
                    }
                }
            sprockets
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
    }

    private var sprockets: some View {
        HStack(spacing: 5) {
            ForEach(0..<(content.size == .medium ? 16 : 9), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5).fill(Color.white.opacity(0.85)).frame(height: 5)
            }
        }
    }

    @ViewBuilder
    private func overlayText(light: Bool) -> some View {
        let lines = overlayLines
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(lines, id: \.self) { Text($0) }
            }
            .font(content.size.captionFont)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.45), radius: 4, y: 1)
            .lineLimit(1)
        }
    }

    private var overlayLines: [String] {
        var lines: [String] = []
        if style.showCaption, let c = content.item?.caption, !c.isEmpty { lines.append(c) }
        if style.showDate, let d = content.item?.capturedAt {
            lines.append(d.formatted(.dateTime.day().month(.abbreviated).year()))
        }
        return lines
    }

    @ViewBuilder
    private var scrim: some View {
        if !overlayLines.isEmpty {
            LinearGradient(colors: [.clear, .black.opacity(0.35)],
                           startPoint: style.overlayPosition == .topLeading ? .bottom : .center,
                           endPoint: style.overlayPosition == .topLeading ? .top : .bottom)
        }
    }

    private static let filmStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "''yy M d"
        return f
    }()
}

/// Image that fills its frame without distorting (or a soft gradient placeholder).
struct PhotoFill: View {
    let image: UIImage?

    var body: some View {
        GeometryReader { geo in
            if let image {
                Self.tintable(image)
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            } else {
                LinearGradient(colors: [Color(hex: "#FF9A8B"), Color(hex: "#8E8CF0")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }

    /// On iOS 18+ tinted Home Screens, keep the photo's detail but tint it to match.
    @ViewBuilder
    static func tintable(_ image: UIImage) -> some View {
        let base = Image(uiImage: image).resizable()
        if #available(iOS 18.0, *) {
            base.widgetAccentedRenderingMode(.accentedDesaturated)
        } else {
            base
        }
    }
}

/// Shown when a widget has no set chosen or the set is empty.
struct EmptyWidgetView: View {
    var message = "Add photos in Framely"

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.stack")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.white)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EmptyWidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(hex: "#FF9A8B"), Color(hex: "#A18CD1"), Color(hex: "#6FD6C5")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
