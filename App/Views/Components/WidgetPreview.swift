import SwiftUI
import WidgetKit

/// Renders a set exactly like the Home Screen widget, using the shared widget views.
struct WidgetPreview: View {
    let set: PhotoSet
    var size: FrameSize = .small
    var style: WidgetStyle? = nil
    /// Advances through photos to show the rotation animation.
    var photoOffset: Int = 0

    @State private var image: UIImage?

    static func dimensions(_ size: FrameSize) -> CGSize {
        switch size {
        case .small: CGSize(width: 158, height: 158)
        case .medium: CGSize(width: 338, height: 158)
        case .large: CGSize(width: 338, height: 354)
        }
    }

    private var item: PhotoItem? {
        guard !set.photos.isEmpty else { return nil }
        return set.photos[((photoOffset % set.photos.count) + set.photos.count) % set.photos.count]
    }

    private var resolvedStyle: WidgetStyle { style ?? set.style }

    var body: some View {
        let dims = Self.dimensions(size)
        let content = FramedPhotoContent(image: image, item: item, style: resolvedStyle, size: size)
        ZStack {
            if item == nil {
                EmptyWidgetBackground()
                EmptyWidgetView(message: "Add photos")
            } else {
                FramedPhotoBackground(content: content)
                FramedPhotoView(content: content)
                    .id(item?.id)
                    .transition(.asymmetric(insertion: .push(from: .trailing), removal: .push(from: .trailing)))
            }
        }
        .frame(width: dims.width, height: dims.height)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: (item?.dominantColorHex.map(Color.init(hex:)) ?? .black).opacity(0.35), radius: 18, y: 10)
        .task(id: "\(item?.id.uuidString ?? "")-\(resolvedStyle.filter.rawValue)-\(size)") {
            guard let item else { image = nil; return }
            let px: CGFloat = size == .small ? 500 : 1000
            let loaded = await ThumbnailCache.shared.image(for: item, maxPixel: px, filter: resolvedStyle.filter)
            withAnimation(Brand.spring) { image = loaded }
        }
    }
}

/// A fanned, swipeable stack of photos. Drag the top card away to send it to the back.
struct CardStack: View {
    let photos: [PhotoItem]
    var onTopChange: (PhotoItem?) -> Void = { _ in }

    @State private var order: [PhotoItem] = []
    @State private var drag: CGSize = .zero
    @State private var swipeCount = 0
    /// Locked on the first movement: horizontal flips cards, vertical is left to the ScrollView.
    @State private var isHorizontal: Bool?

    private let visible = 4

    var body: some View {
        ZStack {
            ForEach(Array(order.prefix(visible).enumerated().reversed()), id: \.element.id) { index, item in
                card(item, index: index)
            }
        }
        .onAppear { order = photos; onTopChange(order.first) }
        .onChange(of: photos) { _, new in
            order = new
            onTopChange(order.first)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: swipeCount)
    }

    private func card(_ item: PhotoItem, index: Int) -> some View {
        let isTop = index == 0
        let fan = Double(index) * (index.isMultiple(of: 2) ? 4 : -4)
        return Thumbnail(item: item, maxPixel: 900)
            .aspectRatio(0.8, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(isTop ? 0.3 : 0.15), radius: isTop ? 20 : 10, y: 10)
            .scaleEffect(1 - CGFloat(index) * 0.05)
            .offset(y: CGFloat(index) * -14)
            .rotationEffect(.degrees(isTop ? Double(drag.width / 18) : fan))
            .offset(isTop ? drag : .zero)
            .zIndex(Double(visible - index))
            .simultaneousGesture(dragGesture, including: isTop ? .all : .subviews)
            .animation(Brand.bouncy, value: order)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if isHorizontal == nil {
                    isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontal == true else { return }
                drag = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                defer { isHorizontal = nil }
                guard isHorizontal == true else { return }
                if abs(value.translation.width) > 110 || abs(value.predictedEndTranslation.width) > 260 {
                    withAnimation(.easeIn(duration: 0.18)) {
                        drag = CGSize(width: value.translation.width > 0 ? 500 : -500, height: 0)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                        guard !order.isEmpty else { return }
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { drag = .zero }
                        withAnimation(Brand.bouncy) {
                            order.append(order.removeFirst())
                        }
                        swipeCount += 1
                        onTopChange(order.first)
                    }
                } else {
                    withAnimation(Brand.bouncy) { drag = .zero }
                }
            }
    }
}
