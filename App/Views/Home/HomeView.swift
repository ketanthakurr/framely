import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(Router.self) private var router
    @Namespace private var zoom

    @State private var focusedSetID: UUID?

    private var focusedSet: PhotoSet? {
        model.sets.first { $0.id == focusedSetID } ?? model.sets.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if model.sets.isEmpty {
                    EmptyHomeHero { router.showNewSet = true }
                        .padding(.horizontal, 20)
                } else {
                    setsCarousel
                    if let set = focusedSet { widgetGallery(for: set) }
                    customizeCards
                }
            }
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .background(AnimatedBackground(tint: focusedSet?.cover?.dominantColorHex.map(Color.init(hex:))))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if !store.isPro {
                    Button { router.showPaywall = true } label: { ProBadge().scaleEffect(1.3) }
                        .accessibilityLabel("Get Framely Pro")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape.fill")
                }
                .accessibilityLabel("Settings")
            }
        }
        .navigationDestination(for: Route.self) { route in
            switch route {
            case .set(let id): SetDetailView(setID: id).zoomDestination(id: id, in: zoom)
            case .settings: SettingsView()
            case .wallpaperGuide: WallpaperGuideView()
            case .widgetGuide: WidgetGuideView()
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Wordmark(size: 38)
            Text("Your photos, on every screen.")
                .font(Brand.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.7))
                .padding(.leading, 2)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: Sets carousel

    private var setsCarousel: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Photo Sets", subtitle: "Swipe · Tap to edit")
                .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 18) {
                    ForEach(model.sets) { set in
                        NavigationLink(value: Route.set(set.id)) {
                            SetCard(set: set)
                                .zoomSource(id: set.id, in: zoom)
                        }
                        .buttonStyle(PressableStyle())
                    }

                    Button {
                        if store.gate.canAddSet(existing: model.sets.count) {
                            router.showNewSet = true
                        } else {
                            router.showPaywall = true
                        }
                    } label: {
                        NewSetCard(locked: !store.gate.canAddSet(existing: model.sets.count))
                    }
                    .buttonStyle(PressableStyle())
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollPosition(id: $focusedSetID)
            .frame(height: 360)
        }
    }

    // MARK: Widget gallery

    private func widgetGallery(for set: PhotoSet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Widget Preview",
                subtitle: "“\(set.name)” · \(set.intervalTitle.lowercased())",
                trailing: AnyView(
                    NavigationLink(value: Route.widgetGuide) {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    }
                )
            )
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                HStack(spacing: 16) {
                    WidgetPreview(set: set, size: .small)
                    WidgetPreview(set: set, size: .medium, photoOffset: 1)
                }
                .padding(.vertical, 20)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Customize

    private var customizeCards: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Customize your iPhone")
                .padding(.horizontal, 20)

            VStack(spacing: 12) {
                NavigationLink(value: Route.wallpaperGuide) {
                    FeatureRow(symbol: "iphone.gen3", colors: [Brand.coral, Brand.lavender],
                               title: "Rotating wallpaper", subtitle: "Change your wallpaper automatically with Shortcuts",
                               pro: !store.gate.wallpaperShortcut)
                }
                NavigationLink(value: Route.widgetGuide) {
                    FeatureRow(symbol: "square.grid.2x2.fill", colors: [Brand.lavender, Brand.mint],
                               title: "Home, Lock Screen & StandBy", subtitle: "Where Framely widgets can live",
                               pro: false)
                }
            }
            .buttonStyle(PressableStyle())
            .padding(.horizontal, 20)
        }
    }
}

struct FeatureRow: View {
    let symbol: String
    let colors: [Color]
    let title: String
    let subtitle: String
    var pro = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).font(Brand.headline)
                    if pro { ProBadge() }
                }
                Text(subtitle).font(Brand.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(.tertiary)
        }
        .foregroundStyle(.primary)
        .padding(14)
        .glass(cornerRadius: 22)
    }
}

// MARK: - Zoom transition helpers (iOS 18+, no-op on 17)

extension View {
    @ViewBuilder
    func zoomSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func zoomDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}
