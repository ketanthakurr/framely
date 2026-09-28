import SwiftUI

/// Step-by-step guide for rotating the real wallpaper via Shortcuts.
struct WallpaperGuideView: View {
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL

    private let steps: [GuideStep] = [
        GuideStep(symbol: "clock.fill", title: "Create an automation",
                  detail: "Open Shortcuts › Automation › + › Time of Day. Pick a time and Daily, then choose “Run Immediately”."),
        GuideStep(symbol: "photo.on.rectangle.angled", title: "Add “Get Framely Photo”",
                  detail: "Tap New Blank Automation, search for Framely and add “Get Framely Photo”. Choose your set."),
        GuideStep(symbol: "iphone.gen3", title: "Add “Set Wallpaper Photo”",
                  detail: "Search for Wallpaper and add “Set Wallpaper Photo” (some iOS versions call it “Set Wallpaper”). Choose Lock Screen, Home Screen or both, and turn off “Show Preview”."),
        GuideStep(symbol: "repeat", title: "Want it more often?",
                  detail: "Duplicate the automation for other times (e.g. 8 AM, 1 PM, 7 PM). Shortcuts runs automations at fixed times, not every few minutes."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                hero

                if !store.gate.wallpaperShortcut {
                    Button { router.showPaywall = true } label: {
                        HStack { Image(systemName: "crown.fill"); Text("Unlock with Framely Pro") }
                    }
                    .buttonStyle(PrimaryButtonStyle(gradient: Brand.proGradient))
                }

                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    GuideStepCard(number: i + 1, step: step)
                }

                Button { openURL(AppLinks.shortcutsApp) } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app.fill")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)

                Text("Apple doesn’t let apps change your wallpaper directly. Shortcuts can, with your permission, so this is the supported way to do it.")
                    .font(Brand.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
        }
        .background(AnimatedBackground(tint: Brand.coral))
        .navigationTitle("Rotating Wallpaper")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        PhoneMockup(accent: Brand.coral)
            .frame(height: 220)
            .padding(.vertical, 10)
    }
}

/// Where Framely widgets can go.
struct WidgetGuideView: View {
    @State private var tab = 0

    private let sections: [(String, String, [GuideStep])] = [
        ("Home Screen", "square.grid.2x2.fill", [
            GuideStep(symbol: "hand.tap.fill", title: "Enter edit mode", detail: "Touch and hold an empty area of your Home Screen until the apps jiggle, then tap Edit › Add Widget."),
            GuideStep(symbol: "magnifyingglass", title: "Find Framely", detail: "Search for Framely and swipe to choose Photo, Mosaic or Photo + Info, in small, medium or large."),
            GuideStep(symbol: "slider.horizontal.3", title: "Pick a set", detail: "Touch and hold the widget › Edit Widget to choose the set, layout or countdown."),
        ]),
        ("Lock Screen", "lock.fill", [
            GuideStep(symbol: "hand.tap.fill", title: "Customize", detail: "Touch and hold the Lock Screen › Customize › Lock Screen."),
            GuideStep(symbol: "plus.circle.fill", title: "Add widget", detail: "Tap the widget area under the clock and choose Framely’s Lock Screen Photo."),
            GuideStep(symbol: "circle.lefthalf.filled", title: "About the look", detail: "iOS shows Lock Screen widgets in a tinted, monochrome style, so photos look like luminous silhouettes."),
        ]),
        ("StandBy", "platter.filled.bottom.iphone", [
            GuideStep(symbol: "bolt.fill", title: "Charge sideways", detail: "Put your iPhone on a charger in landscape while it’s locked to start StandBy."),
            GuideStep(symbol: "hand.draw.fill", title: "Add Framely", detail: "Swipe to the widgets view, touch and hold a stack, then tap + and add a small Framely widget."),
            GuideStep(symbol: "moon.fill", title: "Night mode", detail: "In the dark, StandBy tints everything red to protect your sleep. That’s normal."),
        ]),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Picker("Place", selection: $tab.animation(Brand.spring)) {
                    ForEach(sections.indices, id: \.self) { i in
                        Label(sections[i].0, systemImage: sections[i].1).tag(i)
                    }
                }
                .pickerStyle(.segmented)

                PhoneMockup(accent: [Brand.lavender, Brand.coral, Color.red][tab], mode: tab)
                    .frame(height: 220)
                    .id(tab)
                    .transition(.blurReplace)

                ForEach(Array(sections[tab].2.enumerated()), id: \.element.title) { i, step in
                    GuideStepCard(number: i + 1, step: step)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(20)
        }
        .background(AnimatedBackground())
        .navigationTitle("Add Widgets")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Shared guide pieces

struct GuideStep: Hashable {
    let symbol: String
    let title: String
    let detail: String
}

struct GuideStepCard: View {
    let number: Int
    let step: GuideStep

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(Brand.gradient)
                Text("\(number)").font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 4) {
                Label(step.title, systemImage: step.symbol).font(Brand.headline)
                Text(step.detail).font(Brand.body).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .glass(cornerRadius: 22)
    }
}

/// Stylized iPhone illustration. mode: 0 home grid, 1 lock screen, 2 StandBy.
struct PhoneMockup: View {
    var accent: Color
    var mode: Int = 0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if mode == 2 {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.black)
                    .frame(width: 300, height: 150)
                    .overlay {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 20).fill(accent.gradient).frame(width: 120, height: 120)
                                .overlay(Image(systemName: "photo.fill").font(.largeTitle).foregroundStyle(.white.opacity(0.8)))
                            RoundedRectangle(cornerRadius: 20).fill(Color.white.opacity(0.12)).frame(width: 120, height: 120)
                                .overlay(Text("9:41").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(.white))
                        }
                    }
            } else {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(LinearGradient(colors: [accent.opacity(0.7), Brand.ink.opacity(0.85)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 120, height: 220)
                    .overlay {
                        VStack(spacing: 8) {
                            if mode == 1 {
                                Text("9:41").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    .padding(.top, 26)
                                HStack(spacing: 6) {
                                    Circle().fill(.white.opacity(0.7)).frame(width: 22, height: 22)
                                    RoundedRectangle(cornerRadius: 6).fill(.white.opacity(0.7)).frame(width: 52, height: 22)
                                }
                                .scaleEffect(pulse ? 1.08 : 1)
                                Spacer()
                            } else {
                                RoundedRectangle(cornerRadius: 12).fill(Brand.gradient)
                                    .frame(width: 92, height: 44)
                                    .padding(.top, 22)
                                    .scaleEffect(pulse ? 1.06 : 1)
                                    .shadow(color: accent.opacity(0.8), radius: pulse ? 10 : 2)
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(16), spacing: 8), count: 4), spacing: 8) {
                                    ForEach(0..<12, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.35)).frame(width: 16, height: 16)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                    .overlay(RoundedRectangle(cornerRadius: 34, style: .continuous).strokeBorder(.white.opacity(0.4), lineWidth: 3))
            }
        }
        .shadow(color: accent.opacity(0.4), radius: 24, y: 12)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}
