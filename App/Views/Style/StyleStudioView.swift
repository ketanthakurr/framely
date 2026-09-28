import SwiftUI

/// Live widget designer: frames, filters, themes, overlays.
struct StyleStudioView: View {
    let setID: UUID

    @Environment(AppModel.self) private var model
    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var style: WidgetStyle = .default
    @State private var size: FrameSize = .small
    @State private var tick = 0
    @State private var loaded = false
    @State private var showPaywall = false
    @State private var screen: StudioScreen = .home
    @State private var lock: LockScreenStyle = .default

    enum StudioScreen: String, CaseIterable { case home = "Home Screen", lock = "Lock Screen" }

    private var set: PhotoSet? { model.photoSet(id: setID) }
    private var gate: FeatureGate { store.gate }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Picker("Screen", selection: $screen.animation(Brand.spring)) {
                        ForEach(StudioScreen.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)

                    if screen == .home {
                        Group {
                            preview
                            sizePicker
                            frameSection
                            filterSection
                            themeSection
                            detailsSection
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                    } else if let set {
                        LockStudio(set: set, lock: $lock, gate: gate, tick: tick, choose: choose)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AnimatedBackground(tint: set?.cover?.dominantColorHex.map(Color.init(hex:))))
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { apply() }.fontWeight(.semibold)
                }
            }
            .sensoryFeedback(.selection, trigger: style)
            .sensoryFeedback(.selection, trigger: lock)
        }
        .presentationCornerRadius(32)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .onAppear {
            guard !loaded, let set else { return }
            style = set.style
            lock = set.lockStyle
            loaded = true
        }
    }

    private func apply() {
        guard var set else { return dismiss() }
        set.style = gate.sanitize(style)
        set.lockStyle = gate.sanitize(lock)
        model.update(set)
        dismiss()
    }

    /// Selects an option, or opens the paywall if it's Pro-only.
    private func choose(_ allowed: Bool, _ change: () -> Void) -> Void {
        guard allowed else {
            showPaywall = true
            return
        }
        withAnimation(Brand.spring) { change() }
    }

    // MARK: Preview

    private var preview: some View {
        ZStack {
            if let set {
                WidgetPreview(set: set, size: size, style: style, photoOffset: tick)
                    .scaleEffect(size == .large ? 0.92 : 1)
            }
        }
        .frame(height: 370)
        .animation(Brand.bouncy, value: size)
    }

    private var sizePicker: some View {
        HStack(spacing: 8) {
            ForEach([FrameSize.small, .medium, .large], id: \.self) { s in
                Button { withAnimation(Brand.bouncy) { size = s } } label: {
                    ChoiceChip(title: s.title, selected: size == s)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Sections

    private var frameSection: some View {
        StudioSection(title: "Frame") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(FrameStyle.allCases) { frame in
                        let allowed = gate.allows(frame)
                        Button { choose(allowed) { style.frame = frame } } label: {
                            OptionTile(title: frame.title, selected: style.frame == frame, locked: !allowed) {
                                Image(systemName: frame.symbol).font(.system(size: 24, weight: .medium))
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var filterSection: some View {
        StudioSection(title: "Filter") {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(PhotoFilter.allCases) { filter in
                        let allowed = gate.allows(filter)
                        Button { choose(allowed) { style.filter = filter } } label: {
                            OptionTile(title: filter.title, selected: style.filter == filter, locked: !allowed) {
                                Thumbnail(item: set?.cover, maxPixel: 200, filter: filter)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var themeSection: some View {
        StudioSection(title: "Theme", subtitle: style.theme == .auto ? "Auto matches each photo’s colors" : nil) {
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(ThemeID.allCases) { theme in
                        let allowed = gate.allows(theme)
                        Button { choose(allowed) { style.theme = theme } } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle().fill(AngularGradient(colors: theme.swatch + [theme.swatch[0]], center: .center))
                                    if theme == .auto {
                                        Image(systemName: "wand.and.stars").font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                                    }
                                    if !allowed {
                                        Image(systemName: "lock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                                            .padding(5).background(.black.opacity(0.35), in: Circle())
                                    }
                                }
                                .frame(width: 50, height: 50)
                                .overlay(Circle().strokeBorder(.white, lineWidth: style.theme == theme ? 3 : 0))
                                .shadow(color: theme.swatch[0].opacity(0.5), radius: style.theme == theme ? 10 : 0)
                                .scaleEffect(style.theme == theme ? 1.08 : 1)
                                Text(theme.title).font(Brand.caption)
                                    .foregroundStyle(style.theme == theme ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var detailsSection: some View {
        StudioSection(title: "Details") {
            VStack(spacing: 14) {
                HStack {
                    Label("Corners", systemImage: "square.dashed")
                    Slider(value: $style.innerCornerRadius, in: 0...34, step: 1)
                        .tint(Brand.lavender)
                }
                Toggle(isOn: $style.glow) { Label("Color glow", systemImage: "sun.haze.fill") }
                Toggle(isOn: overlayBinding(\.showDate)) {
                    Label { HStack { Text("Show date"); if !gate.overlays { ProBadge() } } } icon: { Image(systemName: "calendar") }
                }
                Toggle(isOn: overlayBinding(\.showCaption)) {
                    Label { HStack { Text("Show caption"); if !gate.overlays { ProBadge() } } } icon: { Image(systemName: "text.bubble") }
                }
                if style.showDate || style.showCaption {
                    Picker("Position", selection: $style.overlayPosition) {
                        ForEach(OverlayPosition.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .font(Brand.body)
            .tint(Brand.lavender)
            .animation(Brand.spring, value: style.showDate || style.showCaption)
        }
    }

    private func overlayBinding(_ keyPath: WritableKeyPath<WidgetStyle, Bool>) -> Binding<Bool> {
        Binding(
            get: { style[keyPath: keyPath] },
            set: { newValue in choose(gate.overlays) { style[keyPath: keyPath] = newValue } }
        )
    }
}

extension FrameSize {
    var title: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        }
    }
}

struct StudioSection<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(Brand.headline)
                if let subtitle { Text(subtitle).font(Brand.caption).foregroundStyle(.secondary) }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(cornerRadius: 24)
    }
}

struct OptionTile<Icon: View>: View {
    let title: String
    let selected: Bool
    let locked: Bool
    @ViewBuilder var icon: Icon

    var body: some View {
        VStack(spacing: 8) {
            icon
                .frame(width: 64, height: 64)
                .foregroundStyle(selected ? Brand.lavender : .primary)
                .overlay(alignment: .topTrailing) {
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.45), in: Circle())
                            .offset(x: 4, y: -4)
                    }
                }
            Text(title).font(Brand.caption).lineLimit(1)
        }
        .padding(10)
        .frame(width: 92)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.clear), lineWidth: 2.5)
        }
        .glass(cornerRadius: 18, interactive: true)
        .scaleEffect(selected ? 1.04 : 1)
        .animation(Brand.bouncy, value: selected)
    }
}
