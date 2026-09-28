import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var page = 0
    @State private var styleIndex = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let pages: [(title: String, body: String)] = [
        ("Your photos,\nalive on your iPhone", "Pick the moments you love. Framely turns them into widgets that change on your schedule."),
        ("Make it yours", "Polaroid, film, glass or arch frames. Filters, color-matched themes, dates and captions."),
        ("Every screen", "Home Screen, Lock Screen and StandBy. Rotate your wallpaper too, with one Shortcut."),
    ]

    var body: some View {
        ZStack {
            AnimatedBackground(tint: [Brand.coral, Brand.lavender, Brand.mint][page])

            VStack(spacing: 0) {
                TabView(selection: $page.animation(Brand.spring)) {
                    ForEach(pages.indices, id: \.self) { i in
                        VStack(spacing: 28) {
                            Spacer(minLength: 20)
                            illustration(for: i)
                                .frame(height: 300)
                            VStack(spacing: 12) {
                                Text(pages[i].title)
                                    .font(Brand.title(32))
                                    .multilineTextAlignment(.center)
                                Text(pages[i].body)
                                    .font(Brand.body)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            Spacer()
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.secondary.opacity(0.4)))
                            .frame(width: i == page ? 26 : 8, height: 8)
                    }
                }
                .padding(.bottom, 24)

                Button(page == pages.count - 1 ? "Get Started" : "Continue") {
                    if page < pages.count - 1 {
                        withAnimation(Brand.spring) { page += 1 }
                    } else {
                        onFinish()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .sensoryFeedback(.impact(weight: .light), trigger: page)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if reduceMotion { continue }
                withAnimation(.easeInOut(duration: 0.3)) { styleIndex += 1 }
            }
        }
    }

    @ViewBuilder
    private func illustration(for index: Int) -> some View {
        switch index {
        case 0:
            FloatingPolaroids()
        case 1:
            StyleCycleDemo(index: styleIndex)
        default:
            HStack(spacing: 20) {
                PhoneMockup(accent: Brand.lavender, mode: 0)
                PhoneMockup(accent: Brand.coral, mode: 1)
            }
            .scaleEffect(0.95)
        }
    }
}

/// Cycles a sample widget through different frame styles.
private struct StyleCycleDemo: View {
    let index: Int
    private let frames: [FrameStyle] = [.polaroid, .film, .glass, .arch, .inset]
    private let themes: [ThemeID] = [.paper, .noir, .auto, .blush, .sage]

    var body: some View {
        let i = index % frames.count
        var style = WidgetStyle()
        style.frame = frames[i]
        style.theme = themes[i]
        style.showDate = true
        let content = FramedPhotoContent(image: nil, item: nil, style: style, size: .large)
        return ZStack {
            FramedPhotoBackground(content: content)
            FramedPhotoView(content: content)
        }
        .frame(width: 230, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .shadow(color: Brand.lavender.opacity(0.5), radius: 24, y: 12)
        .id(i)
        .transition(.opacity)
        .overlay(alignment: .bottom) {
            Text(frames[i].title)
                .font(Brand.headline)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .glassCapsule()
                .offset(y: 22)
        }
    }
}
